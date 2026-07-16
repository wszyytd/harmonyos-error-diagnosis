import { Want } from '@kit.AbilityKit';
import {
  FormExtensionAbility,
  formBindingData,
  formInfo
} from '@kit.FormKit';
import { FormCardRefreshService } from './FormCardRefreshService';
import { createHarmonyFormRefreshService } from './HarmonyFormRuntime';
import {
  createEmptyFormReportSummary,
  toFormSummaryBindingData
} from './FormSummaryModels';

export default class QuickDiagnosisFormAbility extends FormExtensionAbility {
  private refreshService?: FormCardRefreshService;

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = this.formIdFromWant(want);
    if (formId !== undefined) {
      this.registerAndPublish(formId);
    }
    return formBindingData.createFormBindingData(
      toFormSummaryBindingData(createEmptyFormReportSummary())
    );
  }

  onUpdateForm(formId: string): void {
    this.publishStored(formId);
  }

  onRemoveForm(formId: string): void {
    this.unregister(formId);
  }

  private getRefreshService(): FormCardRefreshService {
    if (this.refreshService === undefined) {
      this.refreshService = createHarmonyFormRefreshService(this.context);
    }
    return this.refreshService;
  }

  private formIdFromWant(want: Want): string | undefined {
    const value = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    return typeof value === 'string' && value.trim().length > 0 ? value : undefined;
  }

  private async registerAndPublish(formId: string): Promise<void> {
    await this.getRefreshService().registerAndPublish(formId);
  }

  private async publishStored(formId: string): Promise<void> {
    await this.getRefreshService().publishStored(formId);
  }

  private async unregister(formId: string): Promise<void> {
    await this.getRefreshService().unregister(formId);
  }
}
