import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** Primitive values owned by the P0 settings Preferences file. */
export type PreferenceValue = string | number | boolean;

/** Injectable persistence boundary used by SettingsRepository. */
export interface PreferencesStore {
  read(key: string, defaultValue: PreferenceValue): Promise<PreferenceValue>;
  write(key: string, value: PreferenceValue): Promise<void>;
  flush(): Promise<void>;
}

/** HarmonyOS Preferences adapter. Platform exceptions stay behind the Repository boundary. */
export class HarmonyPreferencesStore implements PreferencesStore {
  private instance: preferences.Preferences;

  constructor(instance: preferences.Preferences) {
    this.instance = instance;
  }

  async read(key: string, defaultValue: PreferenceValue): Promise<PreferenceValue> {
    try {
      const value = await this.instance.get(key, defaultValue);
      if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        return value;
      }
      return defaultValue;
    } catch (_) {
      throw new Error('Preferences read failed');
    }
  }

  async write(key: string, value: PreferenceValue): Promise<void> {
    try {
      await this.instance.put(key, value);
    } catch (_) {
      throw new Error('Preferences write failed');
    }
  }

  async flush(): Promise<void> {
    try {
      await this.instance.flush();
    } catch (_) {
      throw new Error('Preferences flush failed');
    }
  }
}

/** Lazily obtains the Preferences instance so the first page never waits for storage setup. */
export class LazyHarmonyPreferencesStore implements PreferencesStore {
  private context: common.Context;
  private name: string;
  private instance?: preferences.Preferences;

  constructor(context: common.Context, name: string) {
    this.context = context;
    this.name = name;
  }

  async read(key: string, defaultValue: PreferenceValue): Promise<PreferenceValue> {
    const store = new HarmonyPreferencesStore(await this.getInstance());
    return store.read(key, defaultValue);
  }

  async write(key: string, value: PreferenceValue): Promise<void> {
    const store = new HarmonyPreferencesStore(await this.getInstance());
    return store.write(key, value);
  }

  async flush(): Promise<void> {
    const store = new HarmonyPreferencesStore(await this.getInstance());
    return store.flush();
  }

  private async getInstance(): Promise<preferences.Preferences> {
    if (this.instance === undefined) {
      try {
        this.instance = await preferences.getPreferences(this.context, this.name);
      } catch (_) {
        throw new Error('Preferences unavailable');
      }
    }
    return this.instance;
  }
}
