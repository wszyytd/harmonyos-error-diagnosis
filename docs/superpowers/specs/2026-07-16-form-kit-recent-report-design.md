# Form Kit 最近报告摘要设计

## 目标

把现有 `2*4` 静态服务卡片升级为最近一次已保存报告摘要卡片。卡片显示错误类型、最多两行的短摘要和保存时间；没有记录时显示空状态。点击仍打开现有 `EntryAbility` 首页。

## 方案

采用“脱敏摘要快照 + 主动刷新”：

1. 报告保存成功后，从 `DiagnosisReport` 生成独立的 `FormReportSummary`。
2. 摘要只包含 `errorType`、截断后的 `summary` 和格式化后的 `savedAt`，不包含报告 ID、`rawText`、证据、截图 URI、路径或 Token。
3. 摘要写入独立 Preferences；FormExtensionAbility 添加卡片时先返回安全默认状态，再异步读取快照并调用 `formProvider.updateForm`。
4. FormExtensionAbility 记录已添加的 Form ID，移除卡片时删除对应 ID。
5. 新报告保存成功后更新快照并刷新已知卡片；刷新失败不回滚报告保存。
6. 删除报告或清空历史后重新计算最近摘要；无报告时写入空状态。

不采用 Form 进程直接查询完整报告数据库，避免卡片生命周期直接承担数据库初始化、报告解析和完整领域对象读取。

## 状态与降级

- 有报告：显示错误类型、短摘要、保存时间和“打开应用”。
- 无报告：显示“暂无已保存报告”和“完成一次诊断并保存后显示”。
- 快照读取失败：显示安全空状态，不显示技术错误。
- 卡片主动刷新失败：保留宿主中的上一份内容，不影响保存、删除或清空操作。
- Form Kit 不可用：应用图标和应用内首页仍可正常使用。

## 职责边界

- `FormSummaryModels`：摘要模型、截断和敏感字段白名单转换。
- `FormSummaryRepository`：Preferences 中摘要和 Form ID 的读写。
- `FormCardRefreshService`：生成快照并调用 `formProvider.updateForm`。
- `QuickDiagnosisFormAbility`：卡片添加、更新、移除生命周期。
- `QuickDiagnosisCard`：只渲染绑定数据和打开应用。

页面层不得直接操作 Preferences、Form ID 或 `formProvider`。

## 测试与验收

- 摘要转换不包含报告 ID、原始日志、证据和图片 URI。
- 长摘要稳定截断，时间输入非法时使用安全文案。
- Preferences 支持有报告、空状态、Form ID 去重和删除。
- 保存成功后触发摘要更新；刷新失败不改变保存成功结果。
- 删除和清空后摘要与最近报告一致。
- Local Test、ArkTS Linter 和 Debug HAP 构建通过。
- 模拟器桌面实际刷新仍需签名安装后验证；没有设备证据时标记为 `UNVERIFIED`。

## 本次不包含

- 不展示完整报告或原始错误日志；
- 不点击直达报告详情；
- 不增加其他卡片尺寸；
- 不增加网络、AI、OCR 或定时刷新；
- 不修改 P0/P1 产品范围。
