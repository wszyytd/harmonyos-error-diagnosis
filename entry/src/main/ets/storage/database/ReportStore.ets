import {
  DIAGNOSIS_REPORT_COLUMNS,
  DIAGNOSIS_REPORT_TABLE
} from '../../constants/DatabaseConstants';
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
  LogMetadataKey
} from '../../service/platform/HiLogService';
import {
  DatabaseQuerySpec,
  DatabaseResultSet,
  DatabaseStore,
  DatabaseValues
} from './DatabaseManager';
import {
  deserializeDiagnosisReport,
  ReportDatabaseRow,
  serializeDiagnosisReport
} from './ReportRowMapper';

function databaseValues(row: ReportDatabaseRow): DatabaseValues {
  return {
    id: row.id as string,
    error_type: row.error_type as string,
    secondary_tags_json: row.secondary_tags_json as string,
    summary: row.summary as string,
    evidence_json: row.evidence_json as string,
    causes_json: row.causes_json as string,
    steps_json: row.steps_json as string,
    suggestions_json: row.suggestions_json as string,
    risk_notice: row.risk_notice as string | null,
    raw_text: row.raw_text as string,
    source_type: row.source_type as string,
    created_at: row.created_at as number,
    saved_at: row.saved_at as number,
    is_favorite: row.is_favorite as number,
    engine_version: row.engine_version as string
  };
}

function reportRow(resultSet: DatabaseResultSet): ReportDatabaseRow {
  return {
    id: resultSet.getValue('id'),
    error_type: resultSet.getValue('error_type'),
    secondary_tags_json: resultSet.getValue('secondary_tags_json'),
    summary: resultSet.getValue('summary'),
    evidence_json: resultSet.getValue('evidence_json'),
    causes_json: resultSet.getValue('causes_json'),
    steps_json: resultSet.getValue('steps_json'),
    suggestions_json: resultSet.getValue('suggestions_json'),
    risk_notice: resultSet.getValue('risk_notice'),
    raw_text: resultSet.getValue('raw_text'),
    source_type: resultSet.getValue('source_type'),
    created_at: resultSet.getValue('created_at'),
    saved_at: resultSet.getValue('saved_at'),
    is_favorite: resultSet.getValue('is_favorite'),
    engine_version: resultSet.getValue('engine_version')
  };
}

/** Low-level V1 report operations. Business save policy deliberately belongs to T10. */
export class ReportStore {
  private database: DatabaseStore | undefined;
  private logger: HiLogService;

  constructor(database: DatabaseStore | undefined, logger: HiLogService) {
    this.database = database;
    this.logger = logger;
  }

  async insert(report: DiagnosisReport): Promise<AppResult<number>> {
    if (this.database === undefined) {
      return this.failure<number>(ErrorCode.STORAGE_WRITE_FAILED, 'insert_unavailable');
    }
    const serialized = serializeDiagnosisReport(report);
    if (!serialized.success || serialized.data === undefined) {
      this.logFailure(ErrorCode.DATA_PARSE_FAILED, 'serialize');
      return this.forwardFailure<number>(serialized, ErrorCode.DATA_PARSE_FAILED);
    }
    try {
      const rowId = await this.database.insert(DIAGNOSIS_REPORT_TABLE, databaseValues(serialized.data));
      if (rowId < 0) {
        return this.failure<number>(ErrorCode.STORAGE_WRITE_FAILED, 'insert_result');
      }
      return createSuccessResult<number>(rowId);
    } catch (_) {
      return this.failure<number>(ErrorCode.STORAGE_WRITE_FAILED, 'insert');
    }
  }

  async getById(reportId: string): Promise<AppResult<DiagnosisReport>> {
    const spec: DatabaseQuerySpec = {
      tableName: DIAGNOSIS_REPORT_TABLE,
      filterColumn: 'id',
      filterValue: reportId,
      limit: 1
    };
    const result = await this.readReports(spec);
    if (!result.success || result.data === undefined) {
      return this.forwardFailure<DiagnosisReport>(result, ErrorCode.STORAGE_READ_FAILED);
    }
    if (result.data.length === 0) {
      return this.failure<DiagnosisReport>(ErrorCode.REPORT_NOT_FOUND, 'get_by_id_empty');
    }
    return createSuccessResult<DiagnosisReport>(result.data[0]);
  }

  async list(offset: number, limit: number): Promise<AppResult<Array<DiagnosisReport>>> {
    if (!Number.isInteger(offset) || offset < 0 || !Number.isInteger(limit) || limit <= 0) {
      return this.failure<Array<DiagnosisReport>>(ErrorCode.VAL_FORMAT_INVALID, 'list_range');
    }
    return this.readReports({
      tableName: DIAGNOSIS_REPORT_TABLE,
      descendingColumn: 'saved_at',
      offset: offset,
      limit: limit
    });
  }

  async deleteById(reportId: string): Promise<AppResult<boolean>> {
    if (this.database === undefined) {
      return this.failure<boolean>(ErrorCode.STORAGE_DELETE_FAILED, 'delete_unavailable');
    }
    try {
      const count = await this.database.delete({
        tableName: DIAGNOSIS_REPORT_TABLE,
        filterColumn: 'id',
        filterValue: reportId
      });
      return createSuccessResult<boolean>(count > 0);
    } catch (_) {
      return this.failure<boolean>(ErrorCode.STORAGE_DELETE_FAILED, 'delete');
    }
  }

  async clearAll(): Promise<AppResult<number>> {
    if (this.database === undefined) {
      return this.failure<number>(ErrorCode.STORAGE_DELETE_FAILED, 'clear_unavailable');
    }
    try {
      return createSuccessResult<number>(await this.database.delete({
        tableName: DIAGNOSIS_REPORT_TABLE
      }));
    } catch (_) {
      return this.failure<number>(ErrorCode.STORAGE_DELETE_FAILED, 'clear');
    }
  }

  private async readReports(spec: DatabaseQuerySpec): Promise<AppResult<Array<DiagnosisReport>>> {
    if (this.database === undefined) {
      return this.failure<Array<DiagnosisReport>>(ErrorCode.STORAGE_READ_FAILED, 'query_unavailable');
    }
    let resultSet: DatabaseResultSet;
    try {
      resultSet = await this.database.query(spec, DIAGNOSIS_REPORT_COLUMNS);
    } catch (_) {
      return this.failure<Array<DiagnosisReport>>(ErrorCode.STORAGE_READ_FAILED, 'query');
    }

    let result: AppResult<Array<DiagnosisReport>>;
    try {
      const reports: Array<DiagnosisReport> = [];
      while (resultSet.goToNextRow()) {
        const parsed = deserializeDiagnosisReport(reportRow(resultSet));
        if (!parsed.success || parsed.data === undefined) {
          this.logFailure(ErrorCode.DATA_PARSE_FAILED, 'row_parse');
          result = this.forwardFailure<Array<DiagnosisReport>>(parsed, ErrorCode.DATA_PARSE_FAILED);
          return this.closeResult(resultSet, result);
        }
        reports.push(parsed.data);
      }
      result = createSuccessResult<Array<DiagnosisReport>>(reports);
    } catch (_) {
      result = this.failure<Array<DiagnosisReport>>(ErrorCode.STORAGE_READ_FAILED, 'result_read');
    }
    return this.closeResult(resultSet, result);
  }

  private closeResult<T>(resultSet: DatabaseResultSet, result: AppResult<T>): AppResult<T> {
    try {
      resultSet.close();
      return result;
    } catch (_) {
      return this.failure<T>(ErrorCode.STORAGE_READ_FAILED, 'result_close');
    }
  }

  private forwardFailure<T>(source: AppResult<DiagnosisReport> | AppResult<ReportDatabaseRow> |
    AppResult<Array<DiagnosisReport>>, fallbackCode: ErrorCode): AppResult<T> {
    if (source.error !== undefined) {
      return createFailureResult<T>(source.error);
    }
    return this.failure<T>(fallbackCode, 'missing_error');
  }

  private failure<T>(code: ErrorCode, stage: string): AppResult<T> {
    this.logFailure(code, stage);
    let message = '本地报告操作失败。';
    let retryable = true;
    if (code === ErrorCode.REPORT_NOT_FOUND) {
      message = '报告不存在或已删除。';
      retryable = false;
    } else if (code === ErrorCode.DATA_PARSE_FAILED) {
      message = '本地报告数据无法读取。';
      retryable = false;
    } else if (code === ErrorCode.VAL_FORMAT_INVALID) {
      message = '报告查询范围无效。';
      retryable = false;
    }
    return createFailureResult<T>({
      code: code,
      message: message,
      retryable: retryable,
      causeType: 'REPORT_STORE'
    });
  }

  private logFailure(code: ErrorCode, stage: string): void {
    this.logger.log(code === ErrorCode.REPORT_NOT_FOUND ? LogLevel.WARN : LogLevel.ERROR, {
      domain: 'report_store',
      event: 'report_store_failed',
      result: 'failure',
      errorCode: code,
      metadata: [
        { key: LogMetadataKey.STAGE, value: stage },
        { key: LogMetadataKey.RESOURCE_NAME, value: 'report.record' }
      ]
    });
  }
}
