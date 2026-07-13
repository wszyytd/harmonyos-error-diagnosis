import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { DiagnosisReport } from '../../main/ets/model/DiagnosisModels';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../main/ets/model/ResultModels';
import {
  ReportDataStore,
  TimeSource
} from '../../main/ets/repository/report/ReportRepository';

export enum ReportStoreFailureStage {
  NONE = 'NONE',
  GET = 'GET',
  INSERT = 'INSERT',
  LIST = 'LIST',
  DELETE = 'DELETE',
  CLEAR = 'CLEAR'
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

function failure<T>(code: ErrorCode): AppResult<T> {
  return createFailureResult<T>({
    code: code,
    message: 'Synthetic report store failure',
    retryable: true,
    causeType: 'SYNTHETIC_REPORT_STORE'
  });
}

export class FakeReportStore implements ReportDataStore {
  reports: Array<DiagnosisReport> = [];
  failureStage: ReportStoreFailureStage = ReportStoreFailureStage.NONE;
  insertCount: number = 0;
  deleteCount: number = 0;

  seed(report: DiagnosisReport): void {
    this.reports.push(copyReport(report));
  }

  async insert(report: DiagnosisReport): Promise<AppResult<number>> {
    if (this.failureStage === ReportStoreFailureStage.INSERT) {
      return failure<number>(ErrorCode.STORAGE_WRITE_FAILED);
    }
    this.reports.push(copyReport(report));
    this.insertCount++;
    return createSuccessResult<number>(this.reports.length);
  }

  async getById(reportId: string): Promise<AppResult<DiagnosisReport>> {
    if (this.failureStage === ReportStoreFailureStage.GET) {
      return failure<DiagnosisReport>(ErrorCode.STORAGE_READ_FAILED);
    }
    const found = this.reports.find((item: DiagnosisReport) => item.id === reportId);
    if (found === undefined) {
      return failure<DiagnosisReport>(ErrorCode.REPORT_NOT_FOUND);
    }
    return createSuccessResult<DiagnosisReport>(copyReport(found));
  }

  async list(offset: number, limit: number): Promise<AppResult<Array<DiagnosisReport>>> {
    if (this.failureStage === ReportStoreFailureStage.LIST) {
      return failure<Array<DiagnosisReport>>(ErrorCode.STORAGE_READ_FAILED);
    }
    const sorted = this.reports.slice().sort((left: DiagnosisReport, right: DiagnosisReport): number =>
      (right.savedAt as number) - (left.savedAt as number));
    return createSuccessResult<Array<DiagnosisReport>>(
      sorted.slice(offset, offset + limit).map((item: DiagnosisReport) => copyReport(item))
    );
  }

  async deleteById(reportId: string): Promise<AppResult<boolean>> {
    if (this.failureStage === ReportStoreFailureStage.DELETE) {
      return failure<boolean>(ErrorCode.STORAGE_DELETE_FAILED);
    }
    const before = this.reports.length;
    this.reports = this.reports.filter((item: DiagnosisReport) => item.id !== reportId);
    const deleted = before !== this.reports.length;
    if (deleted) {
      this.deleteCount++;
    }
    return createSuccessResult<boolean>(deleted);
  }

  async clearAll(): Promise<AppResult<number>> {
    if (this.failureStage === ReportStoreFailureStage.CLEAR) {
      return failure<number>(ErrorCode.STORAGE_DELETE_FAILED);
    }
    const count = this.reports.length;
    this.reports = [];
    return createSuccessResult<number>(count);
  }
}

export class FixedTimeSource implements TimeSource {
  private timestamp: number;

  constructor(timestamp: number) {
    this.timestamp = timestamp;
  }

  now(): number {
    return this.timestamp;
  }
}
