import {
  common,
  ConfigurationConstant
} from '@kit.AbilityKit';
import { SETTINGS_PREFERENCES_NAME } from '../../constants/StorageKeys';
import { ThemeMode } from '../../model/SettingsModels';
import {
  LocalSettingsRepository,
  SettingsRepository
} from '../../repository/settings/SettingsRepository';
import { AppStateStore } from '../../store/AppStateStore';
import { LazyHarmonyPreferencesStore } from '../../storage/preferences/PreferencesStore';
import { SettingsViewModel } from '../../viewmodel/settings/SettingsViewModel';
import { ThemePlatform } from '../../theme/ThemeModels';
import { HarmonyHiLogSink } from './HarmonyHiLogSink';
import { HiLogService } from './HiLogService';
import { HarmonyThemePlatform } from './HarmonyThemePlatform';

/** Process-level state shared by the Navigation root and all six T11 pages. */
export const appStateStore: AppStateStore = new AppStateStore();

let settingsViewModel: SettingsViewModel | undefined;

/** Synchronously wires dependencies, then restores Preferences without blocking first render. */
export function configureAppRuntime(context: common.UIAbilityContext): Promise<boolean> {
  const initialColorMode = context.config.colorMode === undefined ?
    ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : context.config.colorMode;
  const repository = new LocalSettingsRepository(
    new LazyHarmonyPreferencesStore(context, SETTINGS_PREFERENCES_NAME),
    new HiLogService(new HarmonyHiLogSink())
  );
  return configureAppRuntimeWithAdapters(
    repository,
    new HarmonyThemePlatform(context.getApplicationContext(), initialColorMode),
    new HiLogService(new HarmonyHiLogSink())
  );
}

/** Replaceable composition boundary used by device tests and future platform variants. */
export function configureAppRuntimeWithAdapters(
  repository: SettingsRepository,
  themePlatform: ThemePlatform,
  logger: HiLogService
): Promise<boolean> {
  settingsViewModel?.dispose();
  settingsViewModel = new SettingsViewModel(repository, appStateStore, themePlatform, logger);
  return settingsViewModel.initialize();
}

export function switchApplicationTheme(themeMode: ThemeMode): Promise<boolean> {
  if (settingsViewModel === undefined) {
    return Promise.resolve(false);
  }
  return settingsViewModel.switchTheme(themeMode);
}

export function resetApplicationSettings(): Promise<boolean> {
  if (settingsViewModel === undefined) {
    return Promise.resolve(false);
  }
  return settingsViewModel.resetSettings();
}

export function clearApplicationSettingsError(): void {
  settingsViewModel?.clearError();
}

export function disposeAppRuntime(): void {
  settingsViewModel?.dispose();
  settingsViewModel = undefined;
}
