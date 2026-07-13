import {
  DiagnosisInput,
  DiagnosisReport,
  DiagnosisRule,
  SourceType
} from '../../main/ets/model/DiagnosisModels';
import { HttpStatusEntry } from '../../main/ets/model/ResultModels';

export const SYNTHETIC_TIMESTAMP_MS: number = 1700000000000;

export function createDiagnosisInputFixture(): DiagnosisInput {
  return {
    sessionId: 'synthetic-session-001',
    sourceType: SourceType.TEXT,
    rawText: "ArkTS:ERROR Type 'string' is not assignable to type 'number'",
    createdAt: SYNTHETIC_TIMESTAMP_MS
  };
}

export function createDiagnosisReportFixture(): DiagnosisReport {
  return {
    id: 'synthetic-report-001',
    errorType: 'ArkTSTypeMismatch',
    summary: 'Synthetic type mismatch for model tests',
    evidence: [],
    possibleCauses: [],
    steps: [],
    rawText: "ArkTS:ERROR Type 'string' is not assignable to type 'number'",
    sourceType: SourceType.TEXT,
    createdAt: SYNTHETIC_TIMESTAMP_MS,
    isFavorite: false,
    engineVersion: 'synthetic-rules-1'
  };
}

export function createDiagnosisRuleFixture(): DiagnosisRule {
  return {
    ruleId: 'synthetic-rule-001',
    errorType: 'ArkTSTypeMismatch',
    keywords: ['ArkTS:ERROR'],
    patterns: [],
    priority: 100,
    summaryTemplate: 'Synthetic summary',
    causes: [],
    steps: [],
    version: 'synthetic-rules-1'
  };
}

export function createHttpStatusEntryFixture(): HttpStatusEntry {
  return {
    code: 404,
    name: 'Not Found',
    category: 'Client Error',
    description: 'Synthetic HTTP status entry',
    causes: [],
    steps: []
  };
}
