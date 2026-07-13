import { ThemeMode } from '../../main/ets/model/SettingsModels';
import {
  EffectiveTheme,
  SystemThemeListener,
  ThemePlatform
} from '../../main/ets/theme/ThemeModels';

export class FakeThemePlatform implements ThemePlatform {
  systemTheme: EffectiveTheme;
  appliedModes: Array<ThemeMode> = [];
  startCount: number = 0;
  stopCount: number = 0;
  private listener?: SystemThemeListener;

  constructor(systemTheme: EffectiveTheme = EffectiveTheme.LIGHT) {
    this.systemTheme = systemTheme;
  }

  getSystemTheme(): EffectiveTheme {
    return this.systemTheme;
  }

  applyThemeMode(mode: ThemeMode): void {
    this.appliedModes.push(mode);
  }

  start(listener: SystemThemeListener): void {
    this.startCount++;
    this.listener = listener;
  }

  stop(): void {
    this.stopCount++;
    this.listener = undefined;
  }

  emitSystemTheme(theme: EffectiveTheme): void {
    this.systemTheme = theme;
    this.listener?.(theme);
  }
}
