import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { describe, it } from '@ohos/hypium';

export default function homePageSmokeTest() {
  describe('HomePageSmoke', () => {
    it('shows the application name and skeleton status', 0, async () => {
      const want: Want = {
        bundleName: 'com.example.errordiagnosis',
        abilityName: 'EntryAbility'
      };
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);

      const driver = Driver.create();
      await driver.delayMs(1000);
      await driver.assertComponentExist(ON.text('开发报错诊断助手'));
      await driver.assertComponentExist(ON.text('工程骨架已就绪'));
    });
  });
}
