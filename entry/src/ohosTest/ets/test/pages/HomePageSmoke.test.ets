import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { describe, it } from '@ohos/hypium';

export default function homePageSmokeTest() {
  describe('HomePageSmoke', () => {
    it('opens text diagnosis and renders its primary controls without scrolling', 0, async () => {
      const want: Want = {
        bundleName: 'com.example.errordiagnosis',
        abilityName: 'EntryAbility'
      };
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);

      const driver = Driver.create();
      await driver.delayMs(1000);
      await driver.assertComponentExist(ON.text('开发报错诊断助手'));
      const textEntry = await driver.findComponent(ON.id('home_text_diagnosis'));
      await textEntry.click();
      await driver.delayMs(350);
      await driver.assertComponentExist(ON.id('diagnosis_text_editor'));
      await driver.assertComponentExist(ON.id('diagnosis_start'));
    });
  });
}
