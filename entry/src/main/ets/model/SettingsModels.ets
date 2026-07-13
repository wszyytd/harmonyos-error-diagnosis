import { HISTORY_RECORD_LIMIT } from '../constants/AppLimits';

/** Stable values persisted by the settings repository. */
export enum ThemeMode {
  SYSTEM = 'SYSTEM',
  LIGHT = 'LIGHT',
  DARK = 'DARK'
}

/** Preferences-backed user settings. No field contains sensitive data. */
export interface UserSettings {
  themeMode: ThemeMode;
  historyLimit: number;
  firstLaunchCompleted: boolean;
  draftRecoveryEnabled: boolean;
}

/** Returns a new settings object with the documented P0 defaults. */
export function createDefaultUserSettings(): UserSettings {
  return {
    themeMode: ThemeMode.SYSTEM,
    historyLimit: HISTORY_RECORD_LIMIT,
    firstLaunchCompleted: false,
    draftRecoveryEnabled: false
  };
}
