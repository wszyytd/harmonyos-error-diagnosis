import { HISTORY_RECORD_LIMIT } from '../../constants/AppLimits';
import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisReport } from '../../model/DiagnosisModels';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';
import {
  HiLogService,
  LogLevel,
  LogMetadataItem,
  LogMetadataKey
} from '../../service/platform/HiLogService';
import {
  ReportDataStore,
  ReportRepository,
  TimeSource
} from './ReportRepository';

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

function copyReports(reports: Array<DiagnosisReport>): Array<DiagnosisReport> {
  return reports.map((report: DiagnosisReport) => copyReport(report));
}

function validReportId(reportId: string): boolean {
  return reportId.trim().length > 0;
}

function validOffset(offset: number): boolean {
  return Number.isInteger(offset) && offset >= 0;
}

function validQueryLimit(limit: number): boolean {
  return Number.isInteger(limit) && limit > 0 && limit <= HISTORY_RECORD_LIMIT;
}

function validHistoryLimit(limit: number): boolean {
  return Number.isInteger(limit) && limit > 0;
}

/** relationalStore-backed P0 policy layer above ReportStore. */
export class LocalReportRepository implements ReportRepository {
  private store: ReportDataStore;
  private timeSource: TimeSource;
  private logger: HiLogService;

  constructor(store: ReportDataStore, timeSource: TimeSource, logger: HiLogService) {
    this.store = store;
    this.timeSource = timeSource;
    this.logger = logger;
  }

  async save(report: DiagnosisReport): Promise<AppResult<DiagnosisReport>> {
    if (!validReportId(report.id)) {
      return this.failure<DiagnosisReport>(ErrorCode.VAL_FORMAT_INVALID, 'save_id', false);
    }

    const existing = await this.store.getById(report.id);
    if (existing.success && existing.data !== undefined) {
      this.log(LogLevel.WARN, 'report_save_duplicate', 'duplicate', undefined, 1);
      return createSuccessResult<DiagnosisReport>(copyReport(existing.data));
    }
    if (existing.error?.code !== ErrorCode.REPORT_NOT_FOUND) {
      return this.forwardFailure<DiagnosisReport, DiagnosisReport>(
        existing,
        ErrorCode.STORAGE_READ_FAILED,
        'save_lookup'
      );
    }

    const saved = copyReport(report);
    saved.savedAt = this.timeSource.now();
    const inserted = await this.store.insert(saved);
    if (!inserted.success) {
      return this.forwardFailure<DiagnosisReport, number>(
        inserted,
        ErrorCode.STORAGE_WRITE_FAILED,
        'save_insert'
      );
    }

    const enforced = await this.enforceHistoryLimitInternal(HISTORY_RECORD_LIMIT, saved.id);
    if (!enforced.success) {
      return this.forwardFailure<DiagnosisReport, number>(
        enforced,
        ErrorCode.STORAGE_WRITE_FAILED,
        'save_limit'
      );
    }
    this.log(LogLevel.INFO, 'report_save_completed', 'success', undefined, 1);
    return createSuccessResult<DiagnosisReport>(copyReport(saved));
  }

  async getById(reportId: string): Promise<AppResult<DiagnosisReport>> {
    if (!validReportId(reportId)) {
      return this.failure<DiagnosisReport>(ErrorCode.VAL_FORMAT_INVALID, 'get_id', false);
    }
    const result = await this.store.getById(reportId);
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<DiagnosisReport, DiagnosisReport>(
        result,
        ErrorCode.STORAGE_READ_FAILED,
        'get'
      );
    }
    return createSuccessResult<DiagnosisReport>(copyReport(result.data));
  }

  async list(offset: number, limit: number): Promise<AppResult<Array<DiagnosisReport>>> {
    if (!validOffset(offset) || !validQueryLimit(limit)) {
      return this.failure<Array<DiagnosisReport>>(ErrorCode.VAL_FORMAT_INVALID, 'list_range', false);
    }
    const result = await this.store.list(offset, limit);
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<Array<DiagnosisReport>, Array<DiagnosisReport>>(
        result,
        ErrorCode.STORAGE_READ_FAILED,
        'list'
      );
    }
    return createSuccessResult<Array<DiagnosisReport>>(copyReports(result.data));
  }

  async getRecent(limit: number): Promise<AppResult<Array<DiagnosisReport>>> {
    if (!validQueryLimit(limit)) {
      return this.failure<Array<DiagnosisReport>>(ErrorCode.VAL_FORMAT_INVALID, 'recent_limit', false);
    }
    return this.list(0, limit);
  }

  async deleteById(reportId: string): Promise<AppResult<boolean>> {
    if (!validReportId(reportId)) {
      return this.failure<boolean>(ErrorCode.VAL_FORMAT_INVALID, 'delete_id', false);
    }
    const result = await this.store.deleteById(reportId);
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<boolean, boolean>(result, ErrorCode.STORAGE_DELETE_FAILED, 'delete');
    }
    this.log(LogLevel.INFO, 'report_delete_completed', 'success', undefined, result.data ? 1 : 0);
    return createSuccessResult<boolean>(result.data);
  }

  async updateFavorite(reportId: string, favorite: boolean): Promise<AppResult<boolean>> {
    if (!validReportId(reportId)) {
      return this.failure<boolean>(ErrorCode.VAL_FORMAT_INVALID, 'favorite_id', false);
    }
    const result = await this.store.updateFavorite(reportId, favorite);
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<boolean, boolean>(result, ErrorCode.STORAGE_WRITE_FAILED, 'favorite');
    }
    this.log(LogLevel.INFO, 'report_favorite_updated', 'success', undefined, result.data ? 1 : 0);
    return createSuccessResult<boolean>(result.data);
  }

  async clearAll(): Promise<AppResult<number>> {
    const result = await this.store.clearAll();
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<number, number>(result, ErrorCode.STORAGE_DELETE_FAILED, 'clear');
    }
    this.log(LogLevel.INFO, 'report_clear_completed', 'success', undefined, result.data);
    return createSuccessResult<number>(result.data);
  }

  async enforceHistoryLimit(limit: number): Promise<AppResult<number>> {
    return this.enforceHistoryLimitInternal(limit);
  }

  private async enforceHistoryLimitInternal(
    limit: number,
    protectedReportId?: string
  ): Promise<AppResult<number>> {
    if (!validHistoryLimit(limit)) {
      return this.failure<number>(ErrorCode.VAL_FORMAT_INVALID, 'history_limit', false);
    }

    const loaded = await this.loadAllReports();
    if (!loaded.success || loaded.data === undefined) {
      return this.forwardFailure<number, Array<DiagnosisReport>>(
        loaded,
        ErrorCode.STORAGE_READ_FAILED,
        'history_load'
      );
    }
    const excess = loaded.data.length - limit;
    if (excess <= 0) {
      return createSuccessResult<number>(0);
    }

    const candidates: Array<DiagnosisReport> = [];
    for (let index: number = loaded.data.length - 1; index >= 0; index--) {
      const report = loaded.data[index];
      if (!report.isFavorite && report.id !== protectedReportId) {
        candidates.push(report);
      }
    }
    if (candidates.length < excess) {
      return this.failure<number>(ErrorCode.STORAGE_WRITE_FAILED, 'history_protected', false);
    }

    let deletedCount: number = 0;
    for (let index: number = 0; index < excess; index++) {
      const deleted = await this.store.deleteById(candidates[index].id);
      if (!deleted.success || deleted.data !== true) {
        return this.forwardFailure<number, boolean>(
          deleted,
          ErrorCode.STORAGE_DELETE_FAILED,
          'history_delete'
        );
      }
      deletedCount++;
    }
    this.log(LogLevel.INFO, 'report_history_enforced', 'success', undefined, deletedCount);
    return createSuccessResult<number>(deletedCount);
  }

  private async loadAllReports(): Promise<AppResult<Array<DiagnosisReport>>> {
    const reports: Array<DiagnosisReport> = [];
    let offset: number = 0;
    while (true) {
      const page = await this.store.list(offset, HISTORY_RECORD_LIMIT);
      if (!page.success || page.data === undefined) {
        return this.forwardFailure<Array<DiagnosisReport>, Array<DiagnosisReport>>(
          page,
          ErrorCode.STORAGE_READ_FAILED,
          'history_page'
        );
      }
      reports.push(...copyReports(page.data));
      if (page.data.length < HISTORY_RECORD_LIMIT) {
        break;
      }
      offset += page.data.length;
    }
    return createSuccessResult<Array<DiagnosisReport>>(reports);
  }

  private forwardFailure<T, U>(
    source: AppResult<U>,
    fallbackCode: ErrorCode,
    stage: string
  ): AppResult<T> {
    if (source.error !== undefined) {
      this.log(LogLevel.ERROR, 'report_repository_failed', 'failure', source.error.code);
      return createFailureResult<T>(source.error);
    }
    return this.failure<T>(fallbackCode, stage, true);
  }

  private failure<T>(code: ErrorCode, stage: string, retryable: boolean): AppResult<T> {
    this.log(LogLevel.ERROR, 'report_repository_failed', 'failure', code, undefined, stage);
    let message = '报告操作失败，请重试。';
    if (code === ErrorCode.VAL_FORMAT_INVALID) {
      message = '报告参数无效。';
    } else if (stage === 'history_protected') {
      message = '历史记录已达到上限，请先手动清理收藏记录。';
    }
    return createFailureResult<T>({
      code: code,
      message: message,
      retryable: retryable,
      causeType: stage === 'history_protected' ? 'HISTORY_LIMIT_PROTECTED' : 'REPORT_REPOSITORY'
    });
  }

  private log(
    level: LogLevel,
    event: string,
    result: string,
    errorCode?: string,
    recordCount?: number,
    stage?: string
  ): void {
    const metadata: Array<LogMetadataItem> = [];
    if (recordCount !== undefined) {
      metadata.push({ key: LogMetadataKey.RECORD_COUNT, value: recordCount });
    }
    if (stage !== undefined) {
      metadata.push({ key: LogMetadataKey.STAGE, value: stage });
    }
    this.logger.log(level, {
      domain: 'report_repository',
      event: event,
      result: result,
      errorCode: errorCode,
      metadata: metadata
    });
  }
}
