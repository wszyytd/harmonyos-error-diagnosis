import { describe, expect, it } from '@ohos/hypium';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import {
  createDiagnosisInputFixture,
  createDiagnosisReportFixture,
  createDiagnosisRuleFixture,
  SYNTHETIC_TIMESTAMP_MS
} from '../fixtures/ModelFixtures';

export default function diagnosisModelsTest() {
  describe('DiagnosisModels', () => {
    it('uses the documented source type wire values', 0, () => {
      expect(SourceType.IMAGE).assertEqual('IMAGE');
      expect(SourceType.TEXT).assertEqual('TEXT');
    });

    it('keeps image URI optional and time in Unix milliseconds', 0, () => {
      const input = createDiagnosisInputFixture();

      expect(input.imageUri === undefined).assertTrue();
      expect(input.createdAt).assertEqual(SYNTHETIC_TIMESTAMP_MS);
      expect(input.sourceType).assertEqual(SourceType.TEXT);
    });

    it('keeps optional report collections absent at the domain boundary', 0, () => {
      const report = createDiagnosisReportFixture();

      expect(report.secondaryTags === undefined).assertTrue();
      expect(report.suggestions === undefined).assertTrue();
      expect(report.savedAt === undefined).assertTrue();
      expect(report.evidence.length).assertEqual(0);
      expect(report.isFavorite).assertFalse();
    });

    it('requires rule resource arrays while keeping risk notice optional', 0, () => {
      const rule = createDiagnosisRuleFixture();

      expect(rule.keywords.length).assertEqual(1);
      expect(rule.patterns.length).assertEqual(0);
      expect(rule.causes.length).assertEqual(0);
      expect(rule.steps.length).assertEqual(0);
      expect(rule.riskNotice === undefined).assertTrue();
    });
  });
}
