import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisReport, SourceType } from '../../model/DiagnosisModels';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';

export type ReportRowValue = string | number | boolean | null | undefined;

/** Complete V1 report row shape. The broad value type allows corrupted rows to be validated safely. */
export interface ReportDatabaseRow {
  id: ReportRowValue;
  error_type: ReportRowValue;
  secondary_tags_json: ReportRowValue;
  summary: ReportRowValue;
  evidence_json: ReportRowValue;
  causes_json: ReportRowValue;
  steps_json: ReportRowValue;
  suggestions_json: ReportRowValue;
  risk_notice: ReportRowValue;
  raw_text: ReportRowValue;
  source_type: ReportRowValue;
  created_at: ReportRowValue;
  saved_at: ReportRowValue;
  is_favorite: ReportRowValue;
  engine_version: ReportRowValue;
}

function parseFailure(causeType: string): AppResult<DiagnosisReport> {
  return createFailureResult<DiagnosisReport>({
    code: ErrorCode.DATA_PARSE_FAILED,
    message: '本地报告数据无法读取。',
    retryable: false,
    causeType: causeType
  });
}

function serializationFailure(): AppResult<ReportDatabaseRow> {
  return createFailureResult<ReportDatabaseRow>({
    code: ErrorCode.DATA_PARSE_FAILED,
    message: '报告数据无法转换为存储格式。',
    retryable: false,
    causeType: 'REPORT_ROW_SERIALIZATION'
  });
}

function isRequiredText(value: ReportRowValue): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function isStringArray(value: Array<string>): boolean {
  if (!Array.isArray(value)) {
    return false;
  }
  for (let index: number = 0; index < value.length; index++) {
    if (typeof value[index] !== 'string') {
      return false;
    }
  }
  return true;
}

function parseStringArray(value: ReportRowValue): Array<string> | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  try {
    const parsed = JSON.parse(value) as Array<string>;
    if (!isStringArray(parsed)) {
      return undefined;
    }
    return parsed.slice();
  } catch (_) {
    return undefined;
  }
}

function isUnixMilliseconds(value: ReportRowValue): boolean {
  return typeof value === 'number' && Number.isFinite(value) &&
    Number.isInteger(value) && value >= 0;
}

function validSourceType(value: ReportRowValue): boolean {
  return value === SourceType.IMAGE || value === SourceType.TEXT;
}

function validReportArray(value: Array<string> | undefined, optional: boolean): boolean {
  if (value === undefined) {
    return optional;
  }
  return isStringArray(value);
}

/** Converts a persistable report into the exact V1 row without retaining mutable arrays. */
export function serializeDiagnosisReport(report: DiagnosisReport): AppResult<ReportDatabaseRow> {
  if (!isRequiredText(report.id) || !isRequiredText(report.errorType) ||
    !isRequiredText(report.summary) || !isRequiredText(report.rawText) ||
    !isRequiredText(report.engineVersion) || !validSourceType(report.sourceType) ||
    !isUnixMilliseconds(report.createdAt) || !isUnixMilliseconds(report.savedAt) ||
    typeof report.isFavorite !== 'boolean' ||
    !validReportArray(report.secondaryTags, true) || !validReportArray(report.evidence, false) ||
    !validReportArray(report.possibleCauses, false) || !validReportArray(report.steps, false) ||
    !validReportArray(report.suggestions, true) ||
    (report.riskNotice !== undefined && typeof report.riskNotice !== 'string')) {
    return serializationFailure();
  }

  const row: ReportDatabaseRow = {
    id: report.id,
    error_type: report.errorType,
    secondary_tags_json: JSON.stringify(report.secondaryTags === undefined ? [] : report.secondaryTags),
    summary: report.summary,
    evidence_json: JSON.stringify(report.evidence),
    causes_json: JSON.stringify(report.possibleCauses),
    steps_json: JSON.stringify(report.steps),
    suggestions_json: JSON.stringify(report.suggestions === undefined ? [] : report.suggestions),
    risk_notice: report.riskNotice === undefined ? null : report.riskNotice,
    raw_text: report.rawText,
    source_type: report.sourceType,
    created_at: report.createdAt,
    saved_at: report.savedAt,
    is_favorite: report.isFavorite ? 1 : 0,
    engine_version: report.engineVersion
  };
  return createSuccessResult<ReportDatabaseRow>(row);
}

/** Validates and converts one untrusted V1 database row into an isolated domain report. */
export function deserializeDiagnosisReport(row: ReportDatabaseRow): AppResult<DiagnosisReport> {
  if (!isRequiredText(row.id) || !isRequiredText(row.error_type) ||
    !isRequiredText(row.summary) || !isRequiredText(row.raw_text) ||
    !isRequiredText(row.engine_version) || !validSourceType(row.source_type) ||
    !isUnixMilliseconds(row.created_at) || !isUnixMilliseconds(row.saved_at) ||
    (row.risk_notice !== null && typeof row.risk_notice !== 'string') ||
    (row.is_favorite !== 0 && row.is_favorite !== 1)) {
    return parseFailure('REPORT_ROW_VALIDATION');
  }

  const secondaryTags = parseStringArray(row.secondary_tags_json);
  const evidence = parseStringArray(row.evidence_json);
  const possibleCauses = parseStringArray(row.causes_json);
  const steps = parseStringArray(row.steps_json);
  const suggestions = parseStringArray(row.suggestions_json);
  if (secondaryTags === undefined || evidence === undefined || possibleCauses === undefined ||
    steps === undefined || suggestions === undefined) {
    return parseFailure('REPORT_ROW_JSON');
  }

  const report: DiagnosisReport = {
    id: row.id as string,
    errorType: row.error_type as string,
    secondaryTags: secondaryTags.slice(),
    summary: row.summary as string,
    evidence: evidence.slice(),
    possibleCauses: possibleCauses.slice(),
    steps: steps.slice(),
    suggestions: suggestions.slice(),
    rawText: row.raw_text as string,
    sourceType: row.source_type as SourceType,
    createdAt: row.created_at as number,
    savedAt: row.saved_at as number,
    isFavorite: row.is_favorite === 1,
    engineVersion: row.engine_version as string
  };
  if (typeof row.risk_notice === 'string') {
    report.riskNotice = row.risk_notice;
  }
  return createSuccessResult<DiagnosisReport>(report);
}
