import { describe, expect, it } from '@ohos/hypium';
import {
  createEmptyFormReportSummary,
  createFormReportSummary,
  toFormSummaryBindingData
} from '../../main/ets/form/FormSummaryModels';
import { createReportFixture } from '../fixtures/ReportFixtures';

export default function formSummaryModelsTest() {
  describe('FormSummaryModels', () => {
    it('creates a safe summary from the latest saved report', 0, () => {
      const report = createReportFixture('private-report-id', 1, 1700000000000);
      report.rawText = 'PRIVATE_RAW_TEXT';
      report.evidence = ['PRIVATE_EVIDENCE'];

      const summary = createFormReportSummary(report);
      const serialized = JSON.stringify(summary);

      expect(summary.hasReport).assertTrue();
      expect(summary.errorType).assertEqual('ArkTSTypeMismatch');
      expect(summary.summary).assertEqual('Synthetic report summary');
      expect(summary.savedAtText.includes('2023-')).assertTrue();
      expect(serialized.includes('private-report-id')).assertFalse();
      expect(serialized.includes('PRIVATE_RAW_TEXT')).assertFalse();
      expect(serialized.includes('PRIVATE_EVIDENCE')).assertFalse();
    });

    it('truncates the card summary to sixty characters', 0, () => {
      const report = createReportFixture('long-summary', 1, 2);
      report.summary = 'S'.repeat(100);

      const summary = createFormReportSummary(report);

      expect(summary.summary.length).assertEqual(60);
      expect(summary.summary.endsWith('…')).assertTrue();
    });

    it('uses safe fallbacks for blank text and invalid saved time', 0, () => {
      const report = createReportFixture('fallback-report', 1);
      report.errorType = '   ';
      report.summary = '';

      const summary = createFormReportSummary(report);

      expect(summary.errorType).assertEqual('未分类错误');
      expect(summary.summary).assertEqual('暂无报告摘要');
      expect(summary.savedAtText).assertEqual('保存时间未知');
    });

    it('creates the documented empty state', 0, () => {
      const summary = createEmptyFormReportSummary();

      expect(summary.hasReport).assertFalse();
      expect(summary.errorType).assertEqual('暂无已保存报告');
      expect(summary.summary).assertEqual('完成一次诊断并保存后显示');
      expect(summary.savedAtText).assertEqual('');
    });

    it('combines static labels and summary without sensitive fields', 0, () => {
      const binding = toFormSummaryBindingData(createEmptyFormReportSummary());
      const serialized = JSON.stringify(binding);

      expect(binding.appName).assertEqual('开发报错诊断助手');
      expect(binding.hasReport).assertFalse();
      expect(binding.errorType).assertEqual('暂无已保存报告');
      expect(binding.actionLabel).assertEqual('打开应用');
      expect(serialized.includes('rawText')).assertFalse();
      expect(serialized.includes('reportId')).assertFalse();
      expect(serialized.includes('imageUri')).assertFalse();
    });
  });
}
