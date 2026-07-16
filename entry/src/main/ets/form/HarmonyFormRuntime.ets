import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import {
  FORM_SUMMARY_PREFERENCES_NAME
} from '../constants/StorageKeys';
import { ReportRepository } from '../repository/report/ReportRepository';
import { LazyHarmonyPreferencesStore } from '../storage/preferences/PreferencesStore';
import {
  FormCardRefreshService,
  FormUpdateGateway
} from './FormCardRefreshService';
import { QuickDiagnosisFormBindingData } from './FormCardModels';
import { FormSummaryRepository } from './FormSummaryRepository';

export class HarmonyFormUpdateGateway implements FormUpdateGateway {
  update(formId: string, binding: QuickDiagnosisFormBindingData): Promise<void> {
    try {
      return formProvider.updateForm(
        formId,
        formBindingData.createFormBindingData(binding)
      );
    } catch (_) {
      return Promise.reject(new Error('FORM_UPDATE_FAILED'));
    }
  }
}

export function createHarmonyFormRefreshService(
  context: common.Context,
  reports?: ReportRepository
): FormCardRefreshService {
  return new FormCardRefreshService(
    new FormSummaryRepository(
      new LazyHarmonyPreferencesStore(context, FORM_SUMMARY_PREFERENCES_NAME)
    ),
    new HarmonyFormUpdateGateway(),
    reports
  );
}
