import { HISTORY_RECORD_LIMIT } from '../../constants/AppLimits';
import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisReport } from '../../model/DiagnosisModels';
import { AppError, AppResult, OperationState, OperationStatus } from '../../model/ResultModels';
import { ReportRepository } from '../../repository/report/ReportRepository';
import { AppRouter } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import { copyHomeReportItems, createHomeReportItem, HomeReportItem } from '../home/HomeModels';

function safeHistoryError(error: AppError | undefined): AppError {
  return {
    code: error?.code ?? ErrorCode.STORAGE_READ_FAILED,
    message: '暂时无法读取历史记录，请稍后重试。',
    retryable: true,
    causeType: 'HISTORY_READ'
  };
}

function copyError(error: AppError | undefined): AppError | undefined {
  if (error === undefined) {
    return undefined;
  }
  return {
    code: error.code,
    message: error.message,
    retryable: error.retryable,
    causeType: error.causeType,
    correlationId: error.correlationId
  };
}

function safeMutationError(): AppError {
  return {
    code: ErrorCode.STORAGE_WRITE_FAILED,
    message: '更新失败，历史记录未更改，请重试。',
    retryable: true,
    causeType: 'HISTORY_MUTATION'
  };
}

export type HistoryRefreshAction = () => Promise<boolean>;

enum HistoryMutationKind {
  NONE = 'NONE',
  DELETE = 'DELETE',
  CLEAR = 'CLEAR',
  FAVORITE = 'FAVORITE'
}

@Observed
export class HistoryViewModel {
  private repository: ReportRepository;
  private router: AppRouter;
  private items: Array<HomeReportItem> = [];
  private operationState: OperationState = { status: OperationStatus.IDLE };
  private mutationState: OperationState = { status: OperationStatus.IDLE };
  private hasSuccessfulLoadValue: boolean = false;
  private lifecycleGeneration: number = 0;
  private refreshHome: HistoryRefreshAction;
  private pendingMutation: HistoryMutationKind = HistoryMutationKind.NONE;
  private pendingReportId?: string;
  private pendingFavorite?: boolean;

  constructor(
    repository: ReportRepository,
    router: AppRouter,
    refreshHome: HistoryRefreshAction = async (): Promise<boolean> => true
  ) {
    this.repository = repository;
    this.router = router;
    this.refreshHome = refreshHome;
  }

  get historyReports(): Array<HomeReportItem> {
    return copyHomeReportItems(this.items);
  }

  get historyStatus(): OperationStatus {
    return this.operationState.status;
  }

  get historyError(): AppError | undefined {
    return copyError(this.operationState.error);
  }

  get isHistoryEmpty(): boolean {
    return this.hasSuccessfulLoadValue && this.items.length === 0;
  }

  get mutationStatus(): OperationStatus {
    return this.mutationState.status;
  }

  get mutationError(): AppError | undefined {
    return copyError(this.mutationState.error);
  }

  async loadHistory(): Promise<boolean> {
    if (this.operationState.status === OperationStatus.LOADING) {
      return false;
    }
    const generation = this.lifecycleGeneration;
    this.operationState = { status: OperationStatus.LOADING };
    let result: AppResult<Array<DiagnosisReport>>;
    try {
      result = await this.repository.list(0, HISTORY_RECORD_LIMIT);
    } catch (_) {
      result = { success: false, error: safeHistoryError(undefined) };
    }
    if (generation !== this.lifecycleGeneration) {
      return false;
    }
    if (!result.success || result.data === undefined) {
      this.operationState = {
        status: OperationStatus.ERROR,
        error: safeHistoryError(result.error)
      };
      return false;
    }
    const sorted = result.data.slice().sort((left: DiagnosisReport, right: DiagnosisReport): number =>
      (right.savedAt ?? 0) - (left.savedAt ?? 0));
    this.items = sorted.map((report: DiagnosisReport): HomeReportItem => createHomeReportItem(report));
    this.hasSuccessfulLoadValue = true;
    this.operationState = { status: OperationStatus.SUCCESS };
    return true;
  }

  retryHistory(): Promise<boolean> {
    return this.loadHistory();
  }

  openReport(reportId: string): boolean {
    return this.router.openReport({
      reportId: reportId,
      origin: RouteName.HISTORY_SETTINGS
    }).success;
  }

  async deleteReport(reportId: string): Promise<boolean> {
    if (!this.beginMutation(HistoryMutationKind.DELETE, reportId)) {
      return false;
    }
    const generation = this.lifecycleGeneration;
    let result: AppResult<boolean>;
    try {
      result = await this.repository.deleteById(reportId);
    } catch (_) {
      result = { success: false, error: safeMutationError() };
    }
    if (!this.acceptMutationResult(generation, result.success && result.data !== undefined)) {
      return false;
    }
    this.items = this.items.filter((item: HomeReportItem): boolean => item.reportId !== reportId);
    this.finishMutation();
    await this.refreshHomeSafely();
    return true;
  }

  async clearHistory(): Promise<boolean> {
    if (!this.beginMutation(HistoryMutationKind.CLEAR)) {
      return false;
    }
    const generation = this.lifecycleGeneration;
    let result: AppResult<number>;
    try {
      result = await this.repository.clearAll();
    } catch (_) {
      result = { success: false, error: safeMutationError() };
    }
    if (!this.acceptMutationResult(generation, result.success && result.data !== undefined)) {
      return false;
    }
    this.items = [];
    this.finishMutation();
    await this.refreshHomeSafely();
    return true;
  }

  async toggleFavorite(reportId: string, favorite: boolean): Promise<boolean> {
    if (!this.beginMutation(HistoryMutationKind.FAVORITE, reportId, favorite)) {
      return false;
    }
    const generation = this.lifecycleGeneration;
    let result: AppResult<boolean>;
    try {
      result = await this.repository.updateFavorite(reportId, favorite);
    } catch (_) {
      result = { success: false, error: safeMutationError() };
    }
    if (!this.acceptMutationResult(generation, result.success && result.data === true)) {
      return false;
    }
    this.items = this.items.map((item: HomeReportItem): HomeReportItem => {
      if (item.reportId !== reportId) {
        return item;
      }
      return {
        reportId: item.reportId,
        errorType: item.errorType,
        summary: item.summary,
        savedAtText: item.savedAtText,
        sourceLabel: item.sourceLabel,
        isFavorite: favorite,
        accessibilityText: `${item.errorType}，${item.summary}，${item.savedAtText}，${item.sourceLabel}，` +
          `${favorite ? '已收藏' : '未收藏'}`
      };
    });
    this.finishMutation();
    await this.refreshHomeSafely();
    return true;
  }

  retryMutation(): Promise<boolean> {
    if (this.pendingMutation === HistoryMutationKind.DELETE && this.pendingReportId !== undefined) {
      return this.deleteReport(this.pendingReportId);
    }
    if (this.pendingMutation === HistoryMutationKind.CLEAR) {
      return this.clearHistory();
    }
    if (this.pendingMutation === HistoryMutationKind.FAVORITE &&
      this.pendingReportId !== undefined && this.pendingFavorite !== undefined) {
      return this.toggleFavorite(this.pendingReportId, this.pendingFavorite);
    }
    return Promise.resolve(false);
  }

  private beginMutation(kind: HistoryMutationKind, reportId?: string, favorite?: boolean): boolean {
    if (this.mutationState.status === OperationStatus.LOADING) {
      return false;
    }
    this.pendingMutation = kind;
    this.pendingReportId = reportId;
    this.pendingFavorite = favorite;
    this.mutationState = { status: OperationStatus.LOADING };
    return true;
  }

  private acceptMutationResult(generation: number, successful: boolean): boolean {
    if (generation !== this.lifecycleGeneration) {
      return false;
    }
    if (!successful) {
      this.mutationState = { status: OperationStatus.ERROR, error: safeMutationError() };
      return false;
    }
    return true;
  }

  private finishMutation(): void {
    this.hasSuccessfulLoadValue = true;
    this.mutationState = { status: OperationStatus.SUCCESS };
    this.pendingMutation = HistoryMutationKind.NONE;
    this.pendingReportId = undefined;
    this.pendingFavorite = undefined;
  }

  private async refreshHomeSafely(): Promise<void> {
    try {
      await this.refreshHome();
    } catch (_) {
    }
  }

  dispose(): void {
    this.lifecycleGeneration++;
    if (this.operationState.status === OperationStatus.LOADING) {
      this.operationState = { status: OperationStatus.CANCELLED };
    }
    if (this.mutationState.status === OperationStatus.LOADING) {
      this.mutationState = { status: OperationStatus.CANCELLED };
    }
  }
}
