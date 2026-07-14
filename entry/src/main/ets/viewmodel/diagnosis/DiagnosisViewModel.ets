import { DIAGNOSIS_INPUT_MAX_CHARACTERS } from '../../constants/AppLimits';
import { DIAGNOSIS_EXAMPLE_TEXT } from '../../constants/DiagnosisExamples';
import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisService } from '../../domain/diagnosis/DiagnosisService';
import {
  InputValidationService,
  ValidatedDiagnosisText
} from '../../domain/validation/InputValidationService';
import { DiagnosisInput, SourceType } from '../../model/DiagnosisModels';
import {
  AppError,
  AppResult,
  createErrorOperationState,
  createFailureResult,
  createInitialOperationState,
  createSuccessResult,
  OperationState,
  OperationStatus
} from '../../model/ResultModels';
import { StaticContentRepository } from '../../repository/static/StaticContentRepository';
import { AppRouter } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import { DiagnosisRouteParams } from '../../router/RouteModels';
import {
  HiLogService,
  LogLevel,
  LogMetadataKey
} from '../../service/platform/HiLogService';
import {
  copyDiagnosisSessionState,
  DiagnosisSessionState,
  DiagnosisSessionStore
} from '../../store/DiagnosisSessionStore';

function safeSourceType(sourceType: SourceType): SourceType {
  return sourceType === SourceType.IMAGE || sourceType === SourceType.TEXT ? sourceType : SourceType.TEXT;
}

function inactiveError(): AppError {
  return {
    code: ErrorCode.ROUTE_PARAM_INVALID,
    message: '当前诊断会话已失效，请开始新的诊断。',
    retryable: false,
    causeType: 'DIAGNOSIS_SESSION_INACTIVE'
  };
}

function copyError(error: AppError | undefined): AppError | undefined {
  if (error === undefined) {
    return undefined;
  }
  const copied: AppError = {
    code: error.code,
    message: error.message,
    retryable: error.retryable
  };
  if (error.causeType !== undefined) {
    copied.causeType = error.causeType;
  }
  if (error.correlationId !== undefined) {
    copied.correlationId = error.correlationId;
  }
  return copied;
}

function copyOperationState(state: OperationState): OperationState {
  const copied: OperationState = {
    status: state.status
  };
  if (state.error !== undefined) {
    copied.error = copyError(state.error);
  }
  if (state.correlationId !== undefined) {
    copied.correlationId = state.correlationId;
  }
  return copied;
}

function diagnosisUnavailableError(): AppError {
  return {
    code: ErrorCode.DIAGNOSIS_FAILED,
    message: '本地诊断暂时不可用，请稍后重试。',
    retryable: true,
    causeType: 'DIAGNOSIS_RUNTIME_UNAVAILABLE'
  };
}

export interface DiagnosisFlowDependencies {
  staticContentRepository: StaticContentRepository;
  diagnosisService: DiagnosisService;
  router: AppRouter;
  logger: HiLogService;
}

/** Synchronous T15 input/session orchestration. Diagnosis and navigation belong to T16/T17. */
@Observed
export class DiagnosisViewModel {
  private store: DiagnosisSessionStore;
  private validationService: InputValidationService;
  private activeSessionId: string;
  private snapshot: DiagnosisSessionState;
  private disposed: boolean = false;
  private flowDependencies?: DiagnosisFlowDependencies;
  private operationState: OperationState = createInitialOperationState();
  private operationGeneration: number = 0;

  constructor(
    store: DiagnosisSessionStore,
    validationService: InputValidationService,
    routeParams: DiagnosisRouteParams,
    flowDependencies?: DiagnosisFlowDependencies
  ) {
    this.store = store;
    this.validationService = validationService;
    const restored = routeParams.sessionId === undefined ? undefined :
      store.findCurrentSession(routeParams.sessionId);
    this.snapshot = restored === undefined ? store.startNewSession(safeSourceType(routeParams.sourceType)) : restored;
    this.activeSessionId = this.snapshot.sessionId;
    this.flowDependencies = flowDependencies;
  }

  get session(): DiagnosisSessionState {
    return copyDiagnosisSessionState(this.snapshot);
  }

  get rawText(): string {
    return this.snapshot.rawText;
  }

  get characterCount(): number {
    return this.snapshot.rawText.length;
  }

  get remainingCharacters(): number {
    return Math.max(0, DIAGNOSIS_INPUT_MAX_CHARACTERS - this.characterCount);
  }

  get inputError(): AppError | undefined {
    return copyError(this.snapshot.validationError);
  }

  get diagnosisOperation(): OperationState {
    return copyOperationState(this.operationState);
  }

  get diagnosisError(): AppError | undefined {
    return copyError(this.operationState.error);
  }

  updateText(rawText: string): boolean {
    if (!this.isActive() || !this.store.updateRawText(rawText)) {
      return false;
    }
    this.resetOperationForEdit();
    this.refreshSnapshot();
    return true;
  }

  useExample(): boolean {
    if (!this.isActive() || !this.store.updateRawText(DIAGNOSIS_EXAMPLE_TEXT) || !this.store.markExampleUsed()) {
      return false;
    }
    this.resetOperationForEdit();
    this.refreshSnapshot();
    return true;
  }

  clearInput(): boolean {
    if (!this.isActive() || !this.store.clearInput()) {
      return false;
    }
    this.resetOperationForEdit();
    this.refreshSnapshot();
    return true;
  }

  updateImageUri(imageUri?: string): boolean {
    if (!this.isActive() || !this.store.setImageUri(imageUri)) {
      return false;
    }
    this.resetOperationForEdit();
    this.refreshSnapshot();
    return true;
  }

  startNewSession(sourceType?: SourceType): boolean {
    if (!this.isActive()) {
      return false;
    }
    this.operationGeneration++;
    this.operationState = createInitialOperationState();
    this.snapshot = this.store.startNewSession(safeSourceType(sourceType ?? this.snapshot.sourceType));
    this.activeSessionId = this.snapshot.sessionId;
    return true;
  }

  validateCurrentInput(): AppResult<DiagnosisInput> {
    if (!this.isActive()) {
      return createFailureResult<DiagnosisInput>(inactiveError());
    }
    const result: AppResult<ValidatedDiagnosisText> =
      this.validationService.validateDiagnosisText(this.snapshot.rawText);
    if (!result.success || result.data === undefined) {
      const error = result.error ?? inactiveError();
      this.store.setValidationFailure(error);
      this.refreshSnapshot();
      return createFailureResult<DiagnosisInput>(error);
    }
    this.store.setValidationSuccess(result.data.normalizedText);
    this.refreshSnapshot();
    const input: DiagnosisInput = {
      sessionId: this.snapshot.sessionId,
      sourceType: this.snapshot.sourceType,
      rawText: result.data.normalizedText,
      createdAt: this.snapshot.createdAt
    };
    if (this.snapshot.imageUri !== undefined) {
      input.imageUri = this.snapshot.imageUri;
    }
    return createSuccessResult<DiagnosisInput>(input);
  }

  async diagnose(): Promise<boolean> {
    if (!this.isActive() || this.operationState.status === OperationStatus.LOADING) {
      return false;
    }
    const generation = ++this.operationGeneration;
    const sessionId = this.activeSessionId;
    this.operationState = {
      status: OperationStatus.LOADING,
      correlationId: `diagnosis-${generation}`
    };

    const inputResult = this.validateCurrentInput();
    if (!inputResult.success || inputResult.data === undefined) {
      this.failOperation(inputResult.error ?? inactiveError());
      return false;
    }
    if (this.flowDependencies === undefined) {
      this.failOperation(diagnosisUnavailableError());
      return false;
    }

    const rulesResult = await this.flowDependencies.staticContentRepository.loadDiagnosisRules();
    if (!this.isCurrentOperation(generation, sessionId)) {
      return false;
    }
    if (!rulesResult.success || rulesResult.data === undefined) {
      this.failOperation(rulesResult.error ?? diagnosisUnavailableError());
      return false;
    }
    const reportResult = this.flowDependencies.diagnosisService.diagnose(inputResult.data, rulesResult.data);
    if (!this.isCurrentOperation(generation, sessionId)) {
      return false;
    }
    if (!reportResult.success || reportResult.data === undefined) {
      this.failOperation(reportResult.error ?? diagnosisUnavailableError());
      return false;
    }
    if (!this.store.setPendingReport(reportResult.data)) {
      this.failOperation(inactiveError());
      return false;
    }
    this.refreshSnapshot();
    const navigationResult = this.flowDependencies.router.openReport({
      sessionId: sessionId,
      origin: RouteName.DIAGNOSIS
    });
    if (!navigationResult.success) {
      this.failOperation(navigationResult.error ?? inactiveError());
      return false;
    }
    this.operationState = {
      status: OperationStatus.SUCCESS,
      correlationId: `diagnosis-${generation}`
    };
    this.logOperation(LogLevel.INFO, 'success', rulesResult.data.length);
    return true;
  }

  dispose(): void {
    this.disposed = true;
    this.operationGeneration++;
    if (this.operationState.status === OperationStatus.LOADING) {
      this.operationState = {
        status: OperationStatus.CANCELLED
      };
    }
  }

  private failOperation(error: AppError): void {
    this.operationState = createErrorOperationState(error);
    this.logOperation(LogLevel.ERROR, 'failure', 0, error.code);
  }

  private resetOperationForEdit(): void {
    this.operationGeneration++;
    this.operationState = createInitialOperationState();
  }

  private isCurrentOperation(generation: number, sessionId: string): boolean {
    return !this.disposed && generation === this.operationGeneration &&
      sessionId === this.activeSessionId && this.store.findCurrentSession(sessionId) !== undefined;
  }

  private logOperation(level: LogLevel, result: string, ruleCount: number, errorCode?: string): void {
    this.flowDependencies?.logger.log(level, {
      domain: 'diagnosis_flow',
      event: 'diagnosis_operation',
      result: result,
      errorCode: errorCode,
      metadata: [
        { key: LogMetadataKey.STAGE, value: 'manual_diagnosis' },
        { key: LogMetadataKey.RECORD_COUNT, value: ruleCount }
      ]
    });
  }

  private isActive(): boolean {
    if (this.disposed) {
      return false;
    }
    return this.store.findCurrentSession(this.activeSessionId) !== undefined;
  }

  private refreshSnapshot(): void {
    const current = this.store.findCurrentSession(this.activeSessionId);
    if (current !== undefined) {
      this.snapshot = current;
    }
  }
}
