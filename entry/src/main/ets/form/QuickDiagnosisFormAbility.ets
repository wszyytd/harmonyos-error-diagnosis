import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { createQuickDiagnosisFormData, toFormBindingRecord } from './FormCardModels';

export default class QuickDiagnosisFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(
      toFormBindingRecord(createQuickDiagnosisFormData())
    );
  }
}
