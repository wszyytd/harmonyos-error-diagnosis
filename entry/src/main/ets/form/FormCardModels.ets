/** Non-sensitive values exposed to the system desktop Form host. */
export interface QuickDiagnosisFormData {
  appName: string;
  title: string;
  description: string;
  actionLabel: string;
  privacyHint: string;
}

/** Explicit ArkTS shape passed to FormBindingData. */
export interface QuickDiagnosisFormBindingData {
  appName: string;
  title: string;
  description: string;
  actionLabel: string;
  privacyHint: string;
}

/** Creates a fresh static value object for the minimal Form prototype. */
export function createQuickDiagnosisFormData(): QuickDiagnosisFormData {
  return {
    appName: '开发报错诊断助手',
    title: '快速诊断',
    description: '从桌面进入本地报错分析',
    actionLabel: '打开应用',
    privacyHint: '数据仅保存在本机'
  };
}

/** Copies only explicitly allowed fields into FormBindingData input. */
export function toFormBindingRecord(data: QuickDiagnosisFormData): QuickDiagnosisFormBindingData {
  return {
    appName: data.appName,
    title: data.title,
    description: data.description,
    actionLabel: data.actionLabel,
    privacyHint: data.privacyHint
  };
}
