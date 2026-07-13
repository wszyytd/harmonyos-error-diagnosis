import { DiagnosisReport } from '../../model/DiagnosisModels';
import { AppResult } from '../../model/ResultModels';

/** Bottom-layer report operations required by the P0 repository policy. */
export interface ReportDataStore {
  insert(report: DiagnosisReport): Promise<AppResult<number>>;
  getById(reportId: string): Promise<AppResult<DiagnosisReport>>;
  list(offset: number, limit: number): Promise<AppResult<Array<DiagnosisReport>>>;
  deleteById(reportId: string): Promise<AppResult<boolean>>;
  clearAll(): Promise<AppResult<number>>;
}

/** Injectable Unix-millisecond clock used by save without test delays. */
export interface TimeSource {
  now(): number;
}

export class SystemTimeSource implements TimeSource {
  now(): number {
    return Date.now();
  }
}

/** P0 report persistence contract. Search, filters and favorite updates belong to P1. */
export interface ReportRepository {
  save(report: DiagnosisReport): Promise<AppResult<DiagnosisReport>>;
  getById(reportId: string): Promise<AppResult<DiagnosisReport>>;
  list(offset: number, limit: number): Promise<AppResult<Array<DiagnosisReport>>>;
  getRecent(limit: number): Promise<AppResult<Array<DiagnosisReport>>>;
  deleteById(reportId: string): Promise<AppResult<boolean>>;
  clearAll(): Promise<AppResult<number>>;
  enforceHistoryLimit(limit: number): Promise<AppResult<number>>;
}
