import { describe, expect, it } from '@ohos/hypium';
import {
  createQuickDiagnosisFormData,
  QuickDiagnosisFormData,
  toFormBindingRecord
} from '../../main/ets/form/FormCardModels';

export default function formCardModelsTest() {
  describe('FormCardModels', () => {
    it('creates stable non-empty prototype copy', 0, () => {
      const data = createQuickDiagnosisFormData();

      expect(data.appName).assertEqual('开发报错诊断助手');
      expect(data.title).assertEqual('快速诊断');
      expect(data.description).assertEqual('从桌面进入本地报错分析');
      expect(data.actionLabel).assertEqual('打开应用');
      expect(data.privacyHint).assertEqual('数据仅保存在本机');
    });

    it('returns independent data objects', 0, () => {
      const first = createQuickDiagnosisFormData();
      const second = createQuickDiagnosisFormData();

      first.title = 'changed';

      expect(second.title).assertEqual('快速诊断');
      expect(first === second).assertFalse();
    });

    it('whitelists only the five safe binding fields', 0, () => {
      const data: QuickDiagnosisFormData = createQuickDiagnosisFormData();
      const binding = toFormBindingRecord(data);

      expect(binding.appName).assertEqual(data.appName);
      expect(binding.title).assertEqual(data.title);
      expect(binding.description).assertEqual(data.description);
      expect(binding.actionLabel).assertEqual(data.actionLabel);
      expect(binding.privacyHint).assertEqual(data.privacyHint);
      expect(binding.hasReport).assertFalse();
      expect(binding.errorType).assertEqual('暂无已保存报告');
      expect(binding.reportSummary).assertEqual('完成一次诊断并保存后显示');
      expect(binding.savedAtText).assertEqual('');
      const serialized = JSON.stringify(binding);
      expect(serialized.includes('rawText')).assertFalse();
      expect(serialized.includes('imageUri')).assertFalse();
      expect(serialized.includes('reportId')).assertFalse();
      expect(Object.keys(binding).length).assertEqual(9);
    });
  });
}
