# Form Kit Recent Report Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` task-by-task. Use TDD for production behavior.

**Goal:** 让现有 `2*4` 服务卡片显示最近一次已保存报告的错误类型、短摘要和保存时间，并在保存、删除、清空后更新本地快照和已知卡片。

**Architecture:** 完整报告仍由 `ReportRepository` 管理；新增 Form 专用脱敏摘要模型和 Preferences 快照。应用侧同步最近报告并发布到已登记 Form ID，FormExtensionAbility 只读取快照、登记生命周期和调用 `formProvider.updateForm`。

**Tech Stack:** ArkTS API 26、Form Kit、Preferences、Hypium、Hvigor。

## 约束

- 不向卡片写入报告 ID、`rawText`、证据、截图 URI、路径或 Token。
- 点击仍打开首页，不新增报告详情冷启动路由。
- 卡片刷新失败不改变报告保存、删除或清空的成功结果。
- 保留工作区中与本功能无关的课程报告文档改动，不暂存、不修改。

## Task 1：摘要模型与 Preferences 快照

**新增/修改：**

- `entry/src/main/ets/form/FormSummaryModels.ets`
- `entry/src/main/ets/form/FormSummaryRepository.ets`
- `entry/src/main/ets/constants/StorageKeys.ets`
- `entry/src/test/unit/FormSummaryModels.test.ets`
- `entry/src/test/unit/FormSummaryRepository.test.ets`
- `entry/src/test/List.test.ets`

**步骤：**

- [ ] 先写失败测试：有报告转换、60 字截断、非法时间、空状态、序列化不含敏感字段、快照读写、Form ID 去重与删除、损坏 JSON 回退。
- [ ] 运行 Local Test，确认因模块缺失失败。
- [ ] 实现：

```typescript
export interface FormReportSummary {
  hasReport: boolean;
  errorType: string;
  summary: string;
  savedAtText: string;
}

export function createEmptyFormReportSummary(): FormReportSummary;
export function createFormReportSummary(report: DiagnosisReport): FormReportSummary;
export function toFormBindingData(summary: FormReportSummary): QuickDiagnosisFormBindingData;

export class FormSummaryRepository {
  loadSummary(): Promise<FormReportSummary>;
  saveSummary(summary: FormReportSummary): Promise<boolean>;
  listFormIds(): Promise<Array<string>>;
  addFormId(formId: string): Promise<boolean>;
  removeFormId(formId: string): Promise<boolean>;
}
```

- [ ] Preferences 仅使用两个 JSON 字符串 Key：`form.summary.snapshot`、`form.instance.ids`，写后 flush。
- [ ] 运行完整 Local Test、`git diff --check`。
- [ ] 提交：`feat: add Form report summary snapshot`

## Task 2：卡片发布与 Form 生命周期

**新增/修改：**

- `entry/src/main/ets/form/FormCardRefreshService.ets`
- `entry/src/main/ets/form/HarmonyFormRuntime.ets`
- `entry/src/main/ets/form/QuickDiagnosisFormAbility.ets`
- `entry/src/main/ets/form/pages/QuickDiagnosisCard.ets`
- `entry/src/test/unit/FormCardRefreshService.test.ets`
- `entry/src/test/List.test.ets`

**步骤：**

- [ ] 先写失败测试：最新报告发布、无报告空状态、报告读取失败保留旧快照、多个 Form ID 独立刷新、单个刷新失败不阻止其他 ID、登记与移除。
- [ ] 运行 Local Test，确认因服务模块缺失失败。
- [ ] 实现平台无关服务：

```typescript
export interface FormUpdateGateway {
  update(formId: string, binding: QuickDiagnosisFormBindingData): Promise<void>;
}

export class FormCardRefreshService {
  syncFromRecentReport(): Promise<boolean>;
  registerAndPublish(formId: string): Promise<boolean>;
  publishStored(formId: string): Promise<boolean>;
  unregister(formId: string): Promise<boolean>;
}
```

- [ ] `HarmonyFormUpdateGateway` 仅封装 `formProvider.updateForm`；运行时工厂使用独立 Preferences 文件和现有 `ReportRepository`。
- [ ] `onAddForm` 返回安全空状态，读取 `FormParam.IDENTITY_KEY` 后异步登记和发布；`onUpdateForm` 发布已存快照；`onRemoveForm` 删除 ID。
- [ ] 卡片有报告时展示错误类型、两行摘要、保存时间；无报告时展示空状态；保留“打开应用”。
- [ ] 运行 Local Test、Linter、Debug HAP 构建和敏感字段扫描。
- [ ] 提交：`feat: show recent report on Form card`

## Task 3：报告变更联动与验证文档

**修改：**

- `entry/src/main/ets/service/platform/AppRuntime.ets`
- `entry/src/test/unit/ReportViewModel.test.ets`
- `entry/src/test/unit/HistoryViewModel.test.ets`
- `docs/verification/T0-能力兼容矩阵.md`
- `docs/开发实施计划.md`

**步骤：**

- [ ] 先写失败测试：报告保存成功后调用刷新回调；删除/清空后调用刷新回调；回调抛错不改变业务成功结果。摘要同步的最新报告、回退和空状态由 Task 2 服务测试覆盖。
- [ ] 在 `configureHomeRuntime` 创建单例 `FormCardRefreshService`；保存、删除、清空共用的刷新回调同时刷新首页与 Form 摘要。
- [ ] `disposeAppRuntime` 清理引用，不删除持久化快照和已登记 Form ID。
- [ ] 更新文档：静态编译证据、摘要字段、主动刷新边界；设备桌面运行仍为 `UNVERIFIED`。
- [ ] 最终运行：Local Test、ArkTS Linter、Debug HAP 构建、`git diff --check`、敏感字段扫描、`git status --short`。
- [ ] 提交：`docs: record recent report Form summary`

## 验收

- 卡片绑定数据只含应用文案、`hasReport`、错误类型、短摘要和保存时间。
- 保存新报告后快照变为最新报告；删除最新报告后回退到下一条；清空后为空状态。
- Form 更新失败不回滚报告操作。
- Local Test、Linter、Debug HAP 构建通过。
- 未签名或未在桌面运行时仍如实标记 `UNVERIFIED`。
