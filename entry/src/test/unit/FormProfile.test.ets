import { describe, expect, it } from '@ohos/hypium';
import formProfileResource from '../../main/resources/base/profile/quick_diagnosis_form_config.json';

interface QuickDiagnosisFormProfile {
  name: string;
  src: string;
  uiSyntax: string;
  isDynamic: boolean;
  colorMode: string;
  isDefault: boolean;
  updateEnabled: boolean;
  defaultDimension: string;
  supportDimensions: Array<string>;
  supportDeviceTypes: Array<string>;
}

interface QuickDiagnosisFormConfig {
  forms: Array<QuickDiagnosisFormProfile>;
}

export default function formProfileTest() {
  describe('FormProfile', () => {
    const config: QuickDiagnosisFormConfig = formProfileResource;
    const profile = config.forms[0];

    it('declares one ArkTS dynamic Form without refresh', 0, () => {
      expect(config.forms.length).assertEqual(1);
      expect(profile.name).assertEqual('quick_diagnosis');
      expect(profile.uiSyntax).assertEqual('arkts');
      expect(profile.isDynamic).assertTrue();
      expect(profile.colorMode).assertEqual('auto');
      expect(profile.updateEnabled).assertFalse();
    });

    it('supports only the default 2 by 4 dimension', 0, () => {
      expect(profile.isDefault).assertTrue();
      expect(profile.defaultDimension).assertEqual('2*4');
      expect(profile.supportDimensions.length).assertEqual(1);
      expect(profile.supportDimensions[0]).assertEqual('2*4');
    });

    it('targets the ArkTS card and current device families', 0, () => {
      expect(profile.src).assertEqual('./ets/form/pages/QuickDiagnosisCard.ets');
      expect(profile.supportDeviceTypes.length).assertEqual(2);
      expect(profile.supportDeviceTypes[0]).assertEqual('phone');
      expect(profile.supportDeviceTypes[1]).assertEqual('tablet');
    });
  });
}
