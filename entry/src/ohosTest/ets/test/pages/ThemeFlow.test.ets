import { Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { describe, it } from '@ohos/hypium';
import { appStateStore } from '../../../../main/ets/service/platform/AppRuntime';
import { themeStatusText } from '../../../../main/ets/theme/ThemeModels';

const UI_SETTLE_MS: number = 350;

async function clickText(driver: Driver, text: string): Promise<void> {
  const component = await driver.findComponent(ON.text(text));
  await component.click();
  await driver.delayMs(UI_SETTLE_MS);
}

async function assertCurrentTheme(driver: Driver): Promise<void> {
  await driver.assertComponentExist(ON.text(themeStatusText(
    appStateStore.selectedThemeMode,
    appStateStore.effectiveTheme
  )));
}

export default function themeFlowTest() {
  describe('ThemeFlow', () => {
    it('applies LIGHT DARK and SYSTEM across the Navigation root and all six pages', 0, async () => {
      const want: Want = {
        bundleName: 'com.example.errordiagnosis',
        abilityName: 'EntryAbility'
      };
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility(want);
      const driver = Driver.create();
      await driver.delayMs(1000);

      await driver.assertComponentExist(ON.text('首页'));
      await assertCurrentTheme(driver);

      await clickText(driver, '验证浅色主题');
      await driver.assertComponentExist(ON.text('当前主题：LIGHT/LIGHT'));
      await clickText(driver, '进入诊断页');
      await driver.assertComponentExist(ON.text('诊断页'));
      await driver.assertComponentExist(ON.text('当前主题：LIGHT/LIGHT'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);

      await clickText(driver, '验证深色主题');
      await driver.assertComponentExist(ON.text('当前主题：DARK/DARK'));
      await clickText(driver, '进入验证工具页');
      await driver.assertComponentExist(ON.text('验证工具页'));
      await driver.assertComponentExist(ON.text('当前主题：DARK/DARK'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);

      await clickText(driver, '进入记录与设置页');
      await driver.assertComponentExist(ON.text('记录与设置页'));
      await driver.assertComponentExist(ON.text('当前主题：DARK/DARK'));
      await clickText(driver, '查看隐私说明');
      await driver.assertComponentExist(ON.text('隐私说明页'));
      await driver.assertComponentExist(ON.text('当前主题：DARK/DARK'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);
      await clickText(driver, '查看报告占位页');
      await driver.assertComponentExist(ON.text('诊断报告页'));
      await driver.assertComponentExist(ON.text('当前主题：DARK/DARK'));
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);
      await driver.pressBack();
      await driver.delayMs(UI_SETTLE_MS);

      await clickText(driver, '验证跟随系统');
      await assertCurrentTheme(driver);
    });
  });
}
