import { DIAGNOSIS_INPUT_MAX_CHARACTERS } from '../../constants/AppLimits';
import { DIAGNOSIS_EXAMPLE_TEXT } from '../../constants/DiagnosisExamples';
import { ErrorCode } from '../../constants/ErrorCodes';
import {
  InputValidationService,
  ValidatedDiagnosisText
} from '../../domain/validation/InputValidationService';
import { DiagnosisInput, SourceType } from '../../model/DiagnosisModels';
import {
  AppError,
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';
import { DiagnosisRouteParams } from '../../router/RouteModels';
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

/** Synchronous T15 input/session orchestration. Diagnosis and navigation belong to T16/T17. */
@Observed
export class DiagnosisViewModel {
  private store: DiagnosisSessionStore;
  private validationService: InputValidationService;
  private activeSessionId: string;
  private snapshot: DiagnosisSessionState;
  private disposed: boolean = false;

  constructor(
    store: DiagnosisSessionStore,
    validationService: InputValidationService,
    routeParams: DiagnosisRouteParams
  ) {
    this.store = store;
    this.validationService = validationService;
    const restored = routeParams.sessionId === undefined ? undefined :
      store.findCurrentSession(routeParams.sessionId);
    this.snapshot = restored === undefined ? store.startNewSession(safeSourceType(routeParams.sourceType)) : restored;
    this.activeSessionId = this.snapshot.sessionId;
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

  updateText(rawText: string): boolean {
    if (!this.isActive() || !this.store.updateRawText(rawText)) {
      return false;
    }
    this.refreshSnapshot();
    return true;
  }

  useExample(): boolean {
    if (!this.isActive() || !this.store.updateRawText(DIAGNOSIS_EXAMPLE_TEXT) || !this.store.markExampleUsed()) {
      return false;
    }
    this.refreshSnapshot();
    return true;
  }

  clearInput(): boolean {
    if (!this.isActive() || !this.store.clearInput()) {
      return false;
    }
    this.refreshSnapshot();
    return true;
  }

  updateImageUri(imageUri?: string): boolean {
    if (!this.isActive() || !this.store.setImageUri(imageUri)) {
      return false;
    }
    this.refreshSnapshot();
    return true;
  }

  startNewSession(sourceType?: SourceType): boolean {
    if (!this.isActive()) {
      return false;
    }
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

  dispose(): void {
    this.disposed = true;
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
