import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisReport } from '../../model/DiagnosisModels';
import {
  AppError,
  createErrorOperationState,
  OperationState,
  OperationStatus
} from '../../model/ResultModels';
import { AppRouter } from '../../router/AppRouter';
import { ReportRouteParams } from '../../router/RouteModels';
import { DiagnosisSessionStore } from '../../store/DiagnosisSessionStore';

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

function copyOperation(state: OperationState): OperationState {
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

function copyReport(report: DiagnosisReport): DiagnosisReport {
  const copied: DiagnosisReport = {
    id: report.id,
    errorType: report.errorType,
    summary: report.summary,
    evidence: report.evidence.slice(),
    possibleCauses: report.possibleCauses.slice(),
    steps: report.steps.slice(),
    rawText: report.rawText,
    sourceType: report.sourceType,
    createdAt: report.createdAt,
    isFavorite: report.isFavorite,
    engineVersion: report.engineVersion
  };
  if (report.secondaryTags !== undefined) {
    copied.secondaryTags = report.secondaryTags.slice();
  }
  if (report.suggestions !== undefined) {
    copied.suggestions = report.suggestions.slice();
  }
  if (report.riskNotice !== undefined) {
    copied.riskNotice = report.riskNotice;
  }
  if (report.savedAt !== undefined) {
    copied.savedAt = report.savedAt;
  }
  return copied;
}

function routeError(): AppError {
  return {
    code: ErrorCode.ROUTE_PARAM_INVALID,
    message: '当前诊断会话已失效，请返回后重新诊断。',
    retryable: false,
    causeType: 'REPORT_SESSION_INVALID'
  };
}

function missingReportError(): AppError {
  return {
    code: ErrorCode.REPORT_NOT_FOUND,
    message: '当前会话还没有可展示的诊断报告。',
    retryable: false,
    causeType: 'PENDING_REPORT_MISSING'
  };
}

function historicalReportError(): AppError {
  return {
    code: ErrorCode.REPORT_NOT_FOUND,
    message: '历史报告详情将在后续版本接入，请从首页返回。',
    retryable: false,
    causeType: 'HISTORICAL_REPORT_NOT_CONNECTED'
  };
}

/** Displays only the unsaved report owned by the exact current memory session. */
@Observed
export class ReportViewModel {
  private store: DiagnosisSessionStore;
  private router: AppRouter;
  private sessionId?: string;
  private currentReport?: DiagnosisReport;
  private operationState: OperationState;
  private disposed: boolean = false;

  constructor(store: DiagnosisSessionStore, router: AppRouter, routeParams: ReportRouteParams) {
    this.store = store;
    this.router = router;
    this.operationState = {
      status: OperationStatus.IDLE
    };
    if (routeParams.reportId !== undefined) {
      this.operationState = createErrorOperationState(historicalReportError());
      return;
    }
    if (routeParams.sessionId === undefined) {
      this.operationState = createErrorOperationState(routeError());
      return;
    }
    const session = store.findCurrentSession(routeParams.sessionId);
    if (session === undefined) {
      this.operationState = createErrorOperationState(routeError());
      return;
    }
    this.sessionId = session.sessionId;
    if (session.pendingReport === undefined) {
      this.operationState = createErrorOperationState(missingReportError());
      return;
    }
    this.currentReport = copyReport(session.pendingReport);
    this.operationState = {
      status: OperationStatus.SUCCESS
    };
  }

  get reportOperation(): OperationState {
    return copyOperation(this.operationState);
  }

  get reportError(): AppError | undefined {
    return copyError(this.operationState.error);
  }

  get report(): DiagnosisReport | undefined {
    return this.currentReport === undefined ? undefined : copyReport(this.currentReport);
  }

  editInput(): boolean {
    if (!this.hasActiveSession()) {
      return false;
    }
    this.router.back();
    return true;
  }

  rediagnose(): boolean {
    return this.editInput();
  }

  backToOrigin(): void {
    if (!this.disposed) {
      this.router.back();
    }
  }

  dispose(): void {
    this.disposed = true;
  }

  private hasActiveSession(): boolean {
    return !this.disposed && this.sessionId !== undefined &&
      this.store.findCurrentSession(this.sessionId) !== undefined;
  }
}
