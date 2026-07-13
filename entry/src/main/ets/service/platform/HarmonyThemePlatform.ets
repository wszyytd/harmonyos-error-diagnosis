import {
  common,
  ConfigurationConstant,
  systemConfiguration
} from '@kit.AbilityKit';
import { ThemeMode } from '../../model/SettingsModels';
import {
  EffectiveTheme,
  SystemThemeListener,
  ThemePlatform
} from '../../theme/ThemeModels';

function toEffectiveTheme(colorMode: ConfigurationConstant.ColorMode): EffectiveTheme {
  return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ?
    EffectiveTheme.DARK : EffectiveTheme.LIGHT;
}

/** API 26 adapter for application color mode and real system color-mode updates. */
export class HarmonyThemePlatform implements ThemePlatform {
  private context: common.ApplicationContext;
  private currentSystemTheme: EffectiveTheme;
  private listener?: SystemThemeListener;
  private started: boolean = false;
  private callback: systemConfiguration.UpdatedCallback;

  constructor(
    context: common.ApplicationContext,
    initialColorMode: ConfigurationConstant.ColorMode
  ) {
    this.context = context;
    this.currentSystemTheme = toEffectiveTheme(initialColorMode);
    this.callback = {
      onColorModeUpdated: (colorMode: ConfigurationConstant.ColorMode): void => {
        this.currentSystemTheme = toEffectiveTheme(colorMode);
        this.listener?.(this.currentSystemTheme);
      }
    };
  }

  getSystemTheme(): EffectiveTheme {
    return this.currentSystemTheme;
  }

  applyThemeMode(mode: ThemeMode): void {
    try {
      if (mode === ThemeMode.DARK) {
        this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === ThemeMode.LIGHT) {
        this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (_) {
      // Semantic colors in AppStateStore remain the safe fallback if the platform call fails.
    }
  }

  start(listener: SystemThemeListener): void {
    this.listener = listener;
    if (this.started) {
      return;
    }
    try {
      this.context.onSystemConfigurationUpdated(this.callback);
      this.started = true;
    } catch (_) {
      this.started = false;
    }
  }

  stop(): void {
    this.listener = undefined;
    if (!this.started) {
      return;
    }
    try {
      this.context.offSystemConfigurationUpdated(this.callback);
    } catch (_) {
      // Listener cleanup must not make Ability destruction fail.
    }
    this.started = false;
  }
}
