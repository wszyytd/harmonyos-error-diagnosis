import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { DiagnosisReport, SourceType } from '../../main/ets/model/DiagnosisModels';
import {
  deserializeDiagnosisReport,
  ReportDatabaseRow,
  serializeDiagnosisReport
} from '../../main/ets/storage/database/ReportRowMapper';

function completeReport(): DiagnosisReport {
  return {
    id: 'synthetic-report-t9-full',
    errorType: 'ArkTSTypeMismatch',
    secondaryTags: ['ArkTS', 'type'],
    summary: 'Synthetic summary',
    evidence: ['Type mismatch at line 12'],
    possibleCauses: ['Synthetic cause'],
    steps: ['Check the declared type'],
    suggestions: ['Use an explicit number'],
    riskNotice: 'Keep a backup before editing.',
    rawText: 'Synthetic ArkTS compiler error',
    sourceType: SourceType.TEXT,
    createdAt: 1700000000000,
    savedAt: 1700000001000,
    isFavorite: true,
    engineVersion: 'synthetic-rules-1'
  };
}

function validRow(): ReportDatabaseRow {
  return {
    id: 'synthetic-row-001',
    error_type: 'ArkTSTypeMismatch',
    secondary_tags_json: '["ArkTS"]',
    summary: 'Synthetic summary',
    evidence_json: '["Synthetic evidence"]',
    causes_json: '["Synthetic cause"]',
    steps_json: '["Synthetic step"]',
    suggestions_json: '["Synthetic suggestion"]',
    risk_notice: null,
    raw_text: 'Synthetic compiler text',
    source_type: 'TEXT',
    created_at: 1700000000000,
    saved_at: 1700000001000,
    is_favorite: 0,
    engine_version: 'synthetic-rules-1'
  };
}

function expectReportsEqual(actual: DiagnosisReport | undefined, expected: DiagnosisReport): void {
  expect(actual?.id).assertEqual(expected.id);
  expect(actual?.errorType).assertEqual(expected.errorType);
  expect(JSON.stringify(actual?.secondaryTags)).assertEqual(JSON.stringify(expected.secondaryTags));
  expect(actual?.summary).assertEqual(expected.summary);
  expect(JSON.stringify(actual?.evidence)).assertEqual(JSON.stringify(expected.evidence));
  expect(JSON.stringify(actual?.possibleCauses)).assertEqual(JSON.stringify(expected.possibleCauses));
  expect(JSON.stringify(actual?.steps)).assertEqual(JSON.stringify(expected.steps));
  expect(JSON.stringify(actual?.suggestions)).assertEqual(JSON.stringify(expected.suggestions));
  expect(actual?.riskNotice).assertEqual(expected.riskNotice);
  expect(actual?.rawText).assertEqual(expected.rawText);
  expect(actual?.sourceType).assertEqual(expected.sourceType);
  expect(actual?.createdAt).assertEqual(expected.createdAt);
  expect(actual?.savedAt).assertEqual(expected.savedAt);
  expect(actual?.isFavorite).assertEqual(expected.isFavorite);
  expect(actual?.engineVersion).assertEqual(expected.engineVersion);
}

export default function reportRowMapperTest() {
  describe('ReportRowMapper', () => {
    it('round trips every field of a complete report', 0, () => {
      const report = completeReport();
      const serialized = serializeDiagnosisReport(report);
      const restored = deserializeDiagnosisReport(serialized.data as ReportDatabaseRow);

      expect(serialized.success).assertTrue();
      expect(restored.success).assertTrue();
      expectReportsEqual(restored.data, report);
    });

    it('maps absent optional collections to empty JSON arrays and risk notice to null', 0, () => {
      const report = completeReport();
      report.secondaryTags = undefined;
      report.suggestions = undefined;
      report.riskNotice = undefined;

      const serialized = serializeDiagnosisReport(report);
      const row = serialized.data as ReportDatabaseRow;
      const restored = deserializeDiagnosisReport(row);

      expect(serialized.success).assertTrue();
      expect(row.secondary_tags_json).assertEqual('[]');
      expect(row.suggestions_json).assertEqual('[]');
      expect(row.risk_notice === null).assertTrue();
      expect(JSON.stringify(restored.data?.secondaryTags)).assertEqual('[]');
      expect(JSON.stringify(restored.data?.suggestions)).assertEqual('[]');
      expect(restored.data?.riskNotice === undefined).assertTrue();
    });

    it('round trips empty arrays without treating them as missing data', 0, () => {
      const report = completeReport();
      report.secondaryTags = [];
      report.evidence = [];
      report.possibleCauses = [];
      report.steps = [];
      report.suggestions = [];

      const serialized = serializeDiagnosisReport(report);
      const restored = deserializeDiagnosisReport(serialized.data as ReportDatabaseRow);

      expect(restored.success).assertTrue();
      expect(JSON.stringify(restored.data?.secondaryTags)).assertEqual('[]');
      expect(JSON.stringify(restored.data?.evidence)).assertEqual('[]');
      expect(JSON.stringify(restored.data?.possibleCauses)).assertEqual('[]');
      expect(JSON.stringify(restored.data?.steps)).assertEqual('[]');
      expect(JSON.stringify(restored.data?.suggestions)).assertEqual('[]');
    });

    it('preserves quotes slashes newlines Unicode and Chinese text', 0, () => {
      const report = completeReport();
      report.summary = '中文 “摘要” \\ path\nnext line 😀';
      report.evidence = ['quote: "value"', '反斜杠 \\ 与换行\n'];
      report.rawText = 'ArkTS 错误："类型"\nD:\\synthetic\\project';

      const serialized = serializeDiagnosisReport(report);
      const restored = deserializeDiagnosisReport(serialized.data as ReportDatabaseRow);

      expect(restored.data?.summary).assertEqual(report.summary);
      expect(JSON.stringify(restored.data?.evidence)).assertEqual(JSON.stringify(report.evidence));
      expect(restored.data?.rawText).assertEqual(report.rawText);
    });

    it('converts only boolean false and true to integer zero and one', 0, () => {
      const falseReport = completeReport();
      falseReport.isFavorite = false;
      const trueReport = completeReport();

      expect(serializeDiagnosisReport(falseReport).data?.is_favorite).assertEqual(0);
      expect(serializeDiagnosisReport(trueReport).data?.is_favorite).assertEqual(1);
      const falseRow = validRow();
      falseRow.is_favorite = 0;
      const trueRow = validRow();
      trueRow.is_favorite = 1;
      expect(deserializeDiagnosisReport(falseRow).data?.isFavorite).assertFalse();
      expect(deserializeDiagnosisReport(trueRow).data?.isFavorite).assertTrue();
    });

    it('rejects malformed array JSON', 0, () => {
      const row = validRow();
      row.evidence_json = '["unterminated"';
      const result = deserializeDiagnosisReport(row);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('rejects JSON arrays containing non-string values', 0, () => {
      const row = validRow();
      row.causes_json = '["valid", 7]';
      const result = deserializeDiagnosisReport(row);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('rejects an unknown persisted source type', 0, () => {
      const row = validRow();
      row.source_type = 'CAMERA';
      const result = deserializeDiagnosisReport(row);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('rejects a favorite integer other than zero or one', 0, () => {
      const row = validRow();
      row.is_favorite = 2;
      const result = deserializeDiagnosisReport(row);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('rejects missing or incorrectly typed required values', 0, () => {
      const missing = validRow();
      missing.summary = undefined;
      const wrongTime = validRow();
      wrongTime.created_at = '1700000000000';

      expect(deserializeDiagnosisReport(missing).error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
      expect(deserializeDiagnosisReport(wrongTime).error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('requires a persisted report to already have savedAt', 0, () => {
      const report = completeReport();
      report.savedAt = undefined;
      const result = serializeDiagnosisReport(report);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('returns isolated report objects and mutable arrays on every read', 0, () => {
      const row = validRow();
      const first = deserializeDiagnosisReport(row);
      const second = deserializeDiagnosisReport(row);

      first.data?.evidence.push('caller mutation');
      first.data?.secondaryTags?.push('caller tag');

      expect(JSON.stringify(second.data?.evidence)).assertEqual('["Synthetic evidence"]');
      expect(JSON.stringify(second.data?.secondaryTags)).assertEqual('["ArkTS"]');
      expect(first.data === second.data).assertFalse();
    });
  });
}
