import { StorageKey } from '../constants/StorageKeys';
import { PreferencesStore, PreferenceValue } from '../storage/preferences/PreferencesStore';
import {
  createEmptyFormReportSummary,
  FormReportSummary
} from './FormSummaryModels';

function validSummary(summary: FormReportSummary): boolean {
  return typeof summary.hasReport === 'boolean' &&
    typeof summary.errorType === 'string' && summary.errorType.trim().length > 0 &&
    typeof summary.summary === 'string' && summary.summary.trim().length > 0 &&
    typeof summary.savedAtText === 'string';
}

function parseSummary(value: PreferenceValue): FormReportSummary {
  if (typeof value !== 'string') {
    return createEmptyFormReportSummary();
  }
  try {
    const parsed = JSON.parse(value) as FormReportSummary;
    return validSummary(parsed) ? {
      hasReport: parsed.hasReport,
      errorType: parsed.errorType,
      summary: parsed.summary,
      savedAtText: parsed.savedAtText
    } : createEmptyFormReportSummary();
  } catch (_) {
    return createEmptyFormReportSummary();
  }
}

function parseFormIds(value: PreferenceValue): Array<string> {
  if (typeof value !== 'string') {
    return [];
  }
  try {
    const parsed = JSON.parse(value) as Array<string>;
    if (!Array.isArray(parsed)) {
      return [];
    }
    const ids: Array<string> = [];
    for (let index: number = 0; index < parsed.length; index++) {
      const id = parsed[index];
      if (typeof id !== 'string' || id.trim().length === 0 || ids.includes(id)) {
        return [];
      }
      ids.push(id);
    }
    return ids;
  } catch (_) {
    return [];
  }
}

export class FormSummaryRepository {
  private store: PreferencesStore;

  constructor(store: PreferencesStore) {
    this.store = store;
  }

  async loadSummary(): Promise<FormReportSummary> {
    try {
      const value = await this.store.read(StorageKey.FORM_SUMMARY_SNAPSHOT, '');
      return parseSummary(value);
    } catch (_) {
      return createEmptyFormReportSummary();
    }
  }

  async saveSummary(summary: FormReportSummary): Promise<boolean> {
    if (!validSummary(summary)) {
      return false;
    }
    try {
      await this.store.write(StorageKey.FORM_SUMMARY_SNAPSHOT, JSON.stringify(summary));
      await this.store.flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  async listFormIds(): Promise<Array<string>> {
    try {
      const value = await this.store.read(StorageKey.FORM_INSTANCE_IDS, '[]');
      return parseFormIds(value);
    } catch (_) {
      return [];
    }
  }

  async addFormId(formId: string): Promise<boolean> {
    const normalized = formId.trim();
    if (normalized.length === 0) {
      return false;
    }
    const ids = await this.listFormIds();
    if (!ids.includes(normalized)) {
      ids.push(normalized);
    }
    return this.saveFormIds(ids);
  }

  async removeFormId(formId: string): Promise<boolean> {
    const normalized = formId.trim();
    if (normalized.length === 0) {
      return false;
    }
    const ids = (await this.listFormIds()).filter((id: string): boolean => id !== normalized);
    return this.saveFormIds(ids);
  }

  private async saveFormIds(ids: Array<string>): Promise<boolean> {
    try {
      await this.store.write(StorageKey.FORM_INSTANCE_IDS, JSON.stringify(ids));
      await this.store.flush();
      return true;
    } catch (_) {
      return false;
    }
  }
}
