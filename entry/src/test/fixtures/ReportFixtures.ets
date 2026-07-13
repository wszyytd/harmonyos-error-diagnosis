import { DiagnosisReport, SourceType } from '../../main/ets/model/DiagnosisModels';

export function createReportFixture(
  id: string = 'synthetic-report-001',
  createdAt: number = 1700000000000,
  savedAt?: number,
  isFavorite: boolean = false
): DiagnosisReport {
  const report: DiagnosisReport = {
    id: id,
    errorType: 'ArkTSTypeMismatch',
    secondaryTags: ['ArkTS', 'synthetic'],
    summary: 'Synthetic report summary',
    evidence: ['Synthetic evidence'],
    possibleCauses: ['Synthetic cause'],
    steps: ['Synthetic step'],
    suggestions: ['Synthetic suggestion'],
    riskNotice: 'Synthetic risk notice',
    rawText: 'Synthetic compiler error text',
    sourceType: SourceType.TEXT,
    createdAt: createdAt,
    isFavorite: isFavorite,
    engineVersion: 'synthetic-rules-1'
  };
  if (savedAt !== undefined) {
    report.savedAt = savedAt;
  }
  return report;
}
