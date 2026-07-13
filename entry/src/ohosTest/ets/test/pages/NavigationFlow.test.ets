import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { describe, it } from '@ohos/hypium';

const UI_SETTLE_MS: number = 300;

async function clickText(driver: Driver, text: string): Promise<void> {
  const component = await driver.findComponent(ON.text(text));
  await component.click();
  await driver.delayMs(UI_SETTLE_MS);
}

export default function navigationFlowTest() {
  describe('NavigationFlow', () => {
    it('loads all six pages and preserves explicit and system return paths', 0, async () => {
      const want: Want = {
        bundleName: 'com.example.errordiagnosis',
        abilityName: 'EntryAbility'
      };
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);

      const driver = Driver.create();
      await driver.delayMs(1000);
      await driver.assertComponentExist(ON.text('首页'));

      await clickText(driver, '进入诊断页');
      await driver.assertComponentExist(ON.text('诊断页'));
      await clickText(driver, '返回首页');
      await driver.assertComponentExist(ON.text('首页'));

      await clickText(driver, '进入验证工具页');
      await driver.assertComponentExist(ON.text('验证工具页'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);
      await driver.assertComponentExist(ON.text('首页'));

      await clickText(driver, '进入记录与设置页');
      await driver.assertComponentExist(ON.text('记录与设置页'));
      await clickText(driver, '查看隐私说明');
      await driver.assertComponentExist(ON.text('隐私说明页'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);
      await driver.assertComponentExist(ON.text('记录与设置页'));

      await clickText(driver, '查看报告占位页');
      await driver.assertComponentExist(ON.text('诊断报告页'));
      await clickText(driver, '返回记录与设置');
      await driver.assertComponentExist(ON.text('记录与设置页'));

      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);
      await driver.assertComponentExist(ON.text('首页'));
    });
  });
}
