# Form Kit Minimal Service Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 API 26 ArkTS Stage 工程中增加一个可编译的 `2*4` Form Kit 最小服务卡片，展示固定的非敏感文案，并通过标准卡片动作打开现有 `EntryAbility`。

**Architecture:** FormExtensionAbility 只创建静态绑定数据，卡片页面只负责渲染与发送 `router` 动作；应用入口继续加载现有首页。原型不依赖 Repository、数据库、OCR、网络、AI 或应用内路由参数，服务卡片仍是系统桌面入口而不是应用内页面组。

**Tech Stack:** HarmonyOS API 26、ArkTS Stage 模型、ArkUI、Form Kit、Hypium Local Test、ArkTS Linter、Hvigor。

## Global Constraints

- 本计划实现的是 P1 Form Kit 的最小原型，不表示完整服务卡片功能交付。
- 只支持 `2*4`，不增加其他尺寸。
- 只允许打开现有 `EntryAbility`，不修改 `EntryAbility`，不解析卡片 Want 参数。
- 不读取 `ReportRepository`、relationalStore 或任何诊断会话。
- 不执行 OCR、网络请求、AI 调用、定时刷新或主动刷新。
- 不创建新的应用内页面组。
- 不提交证书、私钥、密码、签名中间物、HAP 或测试构建产物。
- 所有实现步骤先建立失败证据，再写最小实现；每项完成声明前运行对应验证。
- 设备桌面添加、展示和点击结果必须标记为“未验证”，除非后续确实取得设备证据。

## File and Responsibility Map

| 文件 | 变更 | 唯一职责 |
|---|---|---|
| `entry/src/main/ets/form/FormCardModels.ets` | 新增 | 定义允许展示的卡片数据以及静态默认值和绑定数据转换 |
| `entry/src/main/ets/form/QuickDiagnosisFormAbility.ets` | 新增 | 响应 `onAddForm` 并返回静态 `FormBindingData` |
| `entry/src/main/ets/form/pages/QuickDiagnosisCard.ets` | 新增 | 渲染 `2*4` 卡片并向 `EntryAbility` 发送标准 `router` 动作 |
| `entry/src/main/resources/base/profile/quick_diagnosis_form_config.json` | 新增 | 声明卡片名称、ArkTS 入口、尺寸、颜色与刷新策略 |
| `entry/src/main/module.json5` | 修改 | 注册 `form` 类型 ExtensionAbility 并关联 profile |
| `entry/src/main/resources/base/element/string.json` | 修改 | 增加卡片注册所需展示名和说明资源 |
| `entry/src/main/resources/base/element/color.json` | 修改 | 增加浅色卡片语义颜色 |
| `entry/src/main/resources/dark/element/color.json` | 修改 | 增加深色卡片语义颜色 |
| `entry/src/test/unit/FormCardModels.test.ets` | 新增 | 验证非敏感数据合同和对象隔离 |
| `entry/src/test/unit/FormProfile.test.ets` | 新增 | 验证 profile 的最小配置约束 |
| `entry/src/test/List.test.ets` | 修改 | 注册两组新增 Local Test |
| `docs/verification/T0-能力兼容矩阵.md` | 修改 | 记录静态编译证据与设备运行未验证状态 |
| `docs/开发实施计划.md` | 修改 | 记录该 P1 最小原型的实际结果和未完成边界 |

## Public Contracts

`FormCardModels.ets` 只公开以下合同：

```typescript
export interface QuickDiagnosisFormData {
  appName: string;
  title: string;
  description: string;
  actionLabel: string;
  privacyHint: string;
}

export function createQuickDiagnosisFormData(): QuickDiagnosisFormData;

export function toFormBindingRecord(
  data: QuickDiagnosisFormData
): Record<string, string>;
```

禁止向该合同加入 `rawText`、`imageUri`、`reportId`、完整路径、Token 或报告对象。

---

## Task 1: Add the Static Form Data Contract

**Files:**

- Create: `entry/src/test/unit/FormCardModels.test.ets`
- Modify: `entry/src/test/List.test.ets`
- Create: `entry/src/main/ets/form/FormCardModels.ets`

### Step 1: Write the failing model tests

- [ ] 新建 `entry/src/test/unit/FormCardModels.test.ets`：

```typescript
import { describe, expect, it } from '@ohos/hypium';
import {
  createQuickDiagnosisFormData,
  QuickDiagnosisFormData,
  toFormBindingRecord
} from '../../main/ets/form/FormCardModels';

export default function formCardModelsTest() {
  describe('FormCardModels', () => {
    it('creates stable non-empty prototype copy', 0, () => {
      const data = createQuickDiagnosisFormData();

      expect(data.appName).assertEqual('开发报错诊断助手');
      expect(data.title).assertEqual('快速诊断');
      expect(data.description).assertEqual('从桌面进入本地报错分析');
      expect(data.actionLabel).assertEqual('打开应用');
      expect(data.privacyHint).assertEqual('数据仅保存在本机');
    });

    it('returns independent data objects', 0, () => {
      const first = createQuickDiagnosisFormData();
      const second = createQuickDiagnosisFormData();

      first.title = 'changed';

      expect(second.title).assertEqual('快速诊断');
      expect(first === second).assertFalse();
    });

    it('whitelists only the five safe binding fields', 0, () => {
      const data: QuickDiagnosisFormData = createQuickDiagnosisFormData();
      const binding = toFormBindingRecord(data);

      expect(binding.appName).assertEqual(data.appName);
      expect(binding.title).assertEqual(data.title);
      expect(binding.description).assertEqual(data.description);
      expect(binding.actionLabel).assertEqual(data.actionLabel);
      expect(binding.privacyHint).assertEqual(data.privacyHint);
      expect(binding.rawText === undefined).assertTrue();
      expect(binding.imageUri === undefined).assertTrue();
      expect(binding.reportId === undefined).assertTrue();
      expect(Object.keys(binding).length).assertEqual(5);
    });
  });
}
```

- [ ] 在 `entry/src/test/List.test.ets` 的 import 区增加：

```typescript
import formCardModelsTest from './unit/FormCardModels.test';
```

- [ ] 在 `testsuite()` 中增加：

```typescript
formCardModelsTest();
```

### Step 2: Prove the test is red

- [ ] 运行：

```powershell
& 'D:\Dev\IDE\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default `
  test --no-daemon
```

Expected: `FAIL`，编译阶段明确提示无法解析 `FormCardModels`；不得用其他失败替代该红灯证据。

### Step 3: Implement the smallest safe model

- [ ] 新建 `entry/src/main/ets/form/FormCardModels.ets`：

```typescript
/** Non-sensitive values exposed to the system desktop Form host. */
export interface QuickDiagnosisFormData {
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
export function toFormBindingRecord(
  data: QuickDiagnosisFormData
): Record<string, string> {
  return {
    appName: data.appName,
    title: data.title,
    description: data.description,
    actionLabel: data.actionLabel,
    privacyHint: data.privacyHint
  };
}
```

### Step 4: Verify and commit

- [ ] 重复运行 Local Test。Expected: 本任务新增 3 项测试通过，完整套件 `Failure 0, Error 0`。
- [ ] 运行 `git diff --check`。Expected: 无输出，退出码为 0。
- [ ] 检查 `git diff -- entry/src/main/ets/form/FormCardModels.ets entry/src/test/unit/FormCardModels.test.ets entry/src/test/List.test.ets`，确认没有业务依赖和敏感字段。
- [ ] 提交：

```powershell
git add entry/src/main/ets/form/FormCardModels.ets entry/src/test/unit/FormCardModels.test.ets entry/src/test/List.test.ets
git commit -m "feat: add safe Form card data contract"
```

---

## Task 2: Declare and Validate the Form Profile

**Files:**

- Create: `entry/src/test/unit/FormProfile.test.ets`
- Modify: `entry/src/test/List.test.ets`
- Create: `entry/src/main/resources/base/profile/quick_diagnosis_form_config.json`
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/base/element/color.json`
- Modify: `entry/src/main/resources/dark/element/color.json`

### Step 1: Write the failing profile tests

- [ ] 新建 `entry/src/test/unit/FormProfile.test.ets`：

```typescript
import { describe, expect, it } from '@ohos/hypium';
import formProfileResource from '../../main/resources/base/profile/quick_diagnosis_form_config.json';

interface QuickDiagnosisFormProfile {
  name: string;
  src: string;
  uiSyntax: string;
  isDynamic: boolean;
  colorMode: string;
  isDefault: boolean;
  updateEnabled: boolean;
  defaultDimension: string;
  supportDimensions: Array<string>;
  supportDeviceTypes: Array<string>;
}

interface QuickDiagnosisFormConfig {
  forms: Array<QuickDiagnosisFormProfile>;
}

export default function formProfileTest() {
  describe('FormProfile', () => {
    const config: QuickDiagnosisFormConfig = formProfileResource;
    const profile = config.forms[0];

    it('declares one ArkTS dynamic Form without refresh', 0, () => {
      expect(config.forms.length).assertEqual(1);
      expect(profile.name).assertEqual('quick_diagnosis');
      expect(profile.uiSyntax).assertEqual('arkts');
      expect(profile.isDynamic).assertTrue();
      expect(profile.colorMode).assertEqual('auto');
      expect(profile.updateEnabled).assertFalse();
    });

    it('supports only the default 2 by 4 dimension', 0, () => {
      expect(profile.isDefault).assertTrue();
      expect(profile.defaultDimension).assertEqual('2*4');
      expect(profile.supportDimensions.length).assertEqual(1);
      expect(profile.supportDimensions[0]).assertEqual('2*4');
    });

    it('targets the ArkTS card and current device families', 0, () => {
      expect(profile.src).assertEqual('./ets/form/pages/QuickDiagnosisCard.ets');
      expect(profile.supportDeviceTypes.length).assertEqual(2);
      expect(profile.supportDeviceTypes[0]).assertEqual('phone');
      expect(profile.supportDeviceTypes[1]).assertEqual('tablet');
    });
  });
}
```

- [ ] 在 `entry/src/test/List.test.ets` 增加 import 与调用：

```typescript
import formProfileTest from './unit/FormProfile.test';
```

```typescript
formProfileTest();
```

### Step 2: Prove the test is red

- [ ] 运行完整 Local Test。Expected: `FAIL`，编译阶段明确提示找不到 `quick_diagnosis_form_config.json`。

### Step 3: Add the profile and module registration

- [ ] 新建 `entry/src/main/resources/base/profile/quick_diagnosis_form_config.json`：

```json
{
  "forms": [
    {
      "name": "quick_diagnosis",
      "displayName": "$string:quick_diagnosis_form_name",
      "description": "$string:quick_diagnosis_form_description",
      "src": "./ets/form/pages/QuickDiagnosisCard.ets",
      "uiSyntax": "arkts",
      "isDynamic": true,
      "colorMode": "auto",
      "isDefault": true,
      "updateEnabled": false,
      "defaultDimension": "2*4",
      "supportDimensions": [
        "2*4"
      ],
      "fontScaleFollowSystem": true,
      "supportDeviceTypes": [
        "phone",
        "tablet"
      ]
    }
  ]
}
```

- [ ] 在 `entry/src/main/module.json5` 的 `extensionAbilities` 数组中追加：

```json5
{
  "name": "QuickDiagnosisFormAbility",
  "srcEntry": "./ets/form/QuickDiagnosisFormAbility.ets",
  "type": "form",
  "exported": false,
  "metadata": [
    {
      "name": "ohos.extension.form",
      "resource": "$profile:quick_diagnosis_form_config"
    }
  ]
}
```

- [ ] 在 `entry/src/main/resources/base/element/string.json` 的 `string` 数组追加：

```json
{
  "name": "quick_diagnosis_form_name",
  "value": "快速诊断"
},
{
  "name": "quick_diagnosis_form_description",
  "value": "从桌面打开开发报错诊断助手"
}
```

- [ ] 在 `entry/src/main/resources/base/element/color.json` 的 `color` 数组追加：

```json
{
  "name": "form_card_background",
  "value": "#E7ECEF"
},
{
  "name": "form_card_primary",
  "value": "#2F3E46"
},
{
  "name": "form_card_secondary",
  "value": "#5C677D"
},
{
  "name": "form_card_accent",
  "value": "#7189A6"
},
{
  "name": "form_card_on_accent",
  "value": "#FFFFFF"
}
```

- [ ] 在 `entry/src/main/resources/dark/element/color.json` 的 `color` 数组追加同名深色资源：

```json
{
  "name": "form_card_background",
  "value": "#242A30"
},
{
  "name": "form_card_primary",
  "value": "#F2F5F7"
},
{
  "name": "form_card_secondary",
  "value": "#C3CCD5"
},
{
  "name": "form_card_accent",
  "value": "#8FA6BF"
},
{
  "name": "form_card_on_accent",
  "value": "#17212B"
}
```

### Step 4: Verify profile data, then record the expected integration red state

- [ ] 运行 Local Test。Expected: 新增 3 项 profile 测试通过，完整套件 `Failure 0, Error 0`。
- [ ] 运行 Debug HAP 构建：

```powershell
& 'D:\Dev\IDE\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default `
  -p buildMode=debug -p requiredDeviceType=phone `
  assembleHap --no-daemon
```

Expected: `FAIL`，错误应明确指向尚未创建的 `QuickDiagnosisFormAbility.ets` 或 `QuickDiagnosisCard.ets`。这证明 module/profile 已进入真实构建图；如果错误来自 profile Schema，则先按本机 API 26 Schema 做最小字段修正，并同步调整测试和计划记录，不能隐藏失败。

- [ ] 运行 `git diff --check`。
- [ ] 本任务先不提交，因为 module 配置暂时引用尚未存在的入口；与 Task 3 的最小实现一起形成可构建提交。

---

## Task 3: Implement the Minimal Form Ability and Card UI

**Files:**

- Create: `entry/src/main/ets/form/QuickDiagnosisFormAbility.ets`
- Create: `entry/src/main/ets/form/pages/QuickDiagnosisCard.ets`
- Include the uncommitted configuration/resource/test changes from Task 2

### Step 1: Implement the FormExtensionAbility

- [ ] 新建 `entry/src/main/ets/form/QuickDiagnosisFormAbility.ets`：

```typescript
import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import {
  createQuickDiagnosisFormData,
  toFormBindingRecord
} from './FormCardModels';

export default class QuickDiagnosisFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(
      toFormBindingRecord(createQuickDiagnosisFormData())
    );
  }
}
```

`want` 由平台回调签名要求保留；不得读取或记录其中内容。

### Step 2: Implement the 2*4 ArkTS card

- [ ] 新建 `entry/src/main/ets/form/pages/QuickDiagnosisCard.ets`：

```typescript
const formStorage = new LocalStorage();

@Entry(formStorage)
@Component
struct QuickDiagnosisCard {
  @LocalStorageProp('appName') appName: string = '开发报错诊断助手';
  @LocalStorageProp('title') title: string = '快速诊断';
  @LocalStorageProp('description') description: string = '从桌面进入本地报错分析';
  @LocalStorageProp('actionLabel') actionLabel: string = '打开应用';
  @LocalStorageProp('privacyHint') privacyHint: string = '数据仅保存在本机';

  build() {
    Column({ space: 8 }) {
      Text(this.appName)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')

      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.form_card_primary'))
        .width('100%')

      Text(this.description)
        .fontSize(14)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')

      Blank()

      Button(this.actionLabel)
        .height(44)
        .width('100%')
        .fontSize(16)
        .fontColor($r('app.color.form_card_on_accent'))
        .backgroundColor($r('app.color.form_card_accent'))
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility'
          });
        })

      Text(this.privacyHint)
        .fontSize(11)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.form_card_background'))
  }
}
```

### Step 3: Run the complete static verification

- [ ] 运行完整 Local Test。Expected: 所有既有测试及新增 6 项测试通过，`Failure 0, Error 0`。
- [ ] 运行 ArkTS Linter：

```powershell
$project = (Get-Location).Path
$node = 'D:\Dev\IDE\DevEco Studio\tools\node\node.exe'
$linter = 'D:\Dev\IDE\DevEco Studio\plugins\codelinter\index.js'
$checkPaths = '["' + ($project -replace '\\', '/') + '/entry/src/main/ets"]'
& $node $linter `
  --project $project `
  --dir $checkPaths `
  --config "$project\code-linter.json5" `
  --sdkPath 'D:\Dev\IDE\DevEco Studio\sdk' `
  --sdkNumberVersion '26.0.0' `
  --sdkStringVersion '26.0.0' `
  --workdir 'D:\Dev\IDE\DevEco Studio\plugins\codelinter' `
  --logPath "$project\entry\build\code-linter.log" `
  --inIde false --incremental false --fix false --fixSelected false -l cn
```

Expected: 退出码 0，新增文件无缺陷。若 `want` 的未使用参数被报告，只允许采用平台兼容的最小消除方式，不删除回调签名、不记录 Want。

- [ ] 运行 Debug HAP 构建：

```powershell
& 'D:\Dev\IDE\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default `
  -p buildMode=debug -p requiredDeviceType=phone `
  assembleHap --no-daemon
```

Expected: `BUILD SUCCESSFUL`，profile 通过当前 SDK Schema，FormExtensionAbility 和 ArkTS 卡片均完成编译。

- [ ] 运行敏感边界检查：

```powershell
rg -n "rawText|imageUri|reportId|token|password|ReportRepository|relationalStore|OCR|http" entry/src/main/ets/form entry/src/main/resources/base/profile/quick_diagnosis_form_config.json
```

Expected: 无命中，退出码 1；`rg` 的 1 在这里表示检查通过。

- [ ] 运行范围检查：

```powershell
git diff --name-only
```

Expected: 只出现 File and Responsibility Map 中 Task 2、Task 3 的代码、资源和测试文件，没有 `EntryAbility`、页面路由、Repository 或数据库文件。

- [ ] 运行 `git diff --check`。Expected: 无输出。

### Step 4: Commit the complete compilable prototype

- [ ] 提交：

```powershell
git add entry/src/main/ets/form entry/src/main/module.json5 entry/src/main/resources/base/profile/quick_diagnosis_form_config.json entry/src/main/resources/base/element/string.json entry/src/main/resources/base/element/color.json entry/src/main/resources/dark/element/color.json entry/src/test/unit/FormProfile.test.ets entry/src/test/List.test.ets
git commit -m "feat: add minimal Form Kit service card"
```

---

## Task 4: Record Evidence and Remaining Runtime Gap

**Files:**

- Modify: `docs/verification/T0-能力兼容矩阵.md`
- Modify: `docs/开发实施计划.md`

### Step 1: Update the compatibility evidence

- [ ] 在 `docs/verification/T0-能力兼容矩阵.md` 的 Form Kit 节记录本次实际命令和结果，必须明确区分：

```text
- SDK/API 静态存在性：PASS（沿用 T0 证据）
- Form profile Schema/HAP 编译：PASS（附本轮 Hvigor 命令和日期）
- FormExtensionAbility 与 ArkTS 卡片编译：PASS
- 模拟器桌面添加卡片：UNVERIFIED
- 模拟器点击拉起应用：UNVERIFIED
- 真机展示与交互：UNVERIFIED
- 当前结论：可进入完整 P1 Form Kit 设备验收，但最小原型不等同于运行闭环通过
```

### Step 2: Update the implementation plan status

- [ ] 在 `docs/开发实施计划.md` 的 P1 增量部分增加一个“Form Kit 最小原型”执行记录，至少写清：

```text
已完成：单一 2*4 静态卡片、非敏感 FormBindingData、打开 EntryAbility、配置/模型测试、Linter、Debug HAP 构建。
未完成：桌面实际添加与点击、最近记录摘要、三个定向入口、刷新、冷启动参数、其他尺寸和真机兼容验证。
范围判断：这是 P1 技术原型，不改变 P0/P1 产品定义，不计入应用内页面组。
```

### Step 3: Verify documentation accuracy and commit

- [ ] 运行：

```powershell
rg -n "Form Kit|2\*4|UNVERIFIED|未验证|最小原型" docs/verification/T0-能力兼容矩阵.md docs/开发实施计划.md
```

Expected: 两份文档均能检索到静态通过与运行未验证的明确记录。

- [ ] 再次运行完整 Local Test、Linter、Debug HAP 构建和 `git diff --check`。Expected: 与 Task 3 相同，全部通过。
- [ ] 提交：

```powershell
git add docs/verification/T0-能力兼容矩阵.md docs/开发实施计划.md
git commit -m "docs: record Form Kit prototype verification"
```

---

## Final Acceptance Checklist

- [ ] `module.json5` 注册一个 `type: "form"` 的 `QuickDiagnosisFormAbility`。
- [ ] profile 只有一个 Form，默认尺寸和支持尺寸都只有 `2*4`。
- [ ] profile 使用 ArkTS 动态卡片、自动颜色和关闭刷新。
- [ ] 绑定数据严格只有五个非敏感字符串字段。
- [ ] 卡片只调用 `postCardAction(... action: 'router' ...)` 打开 `EntryAbility`。
- [ ] `EntryAbility`、应用内页面、路由、Repository、数据库、OCR、网络和 AI 未被修改。
- [ ] Local Test 全量通过且新增 6 项测试通过。
- [ ] ArkTS Linter 无新增缺陷。
- [ ] Debug HAP 构建成功。
- [ ] `git diff --check` 通过。
- [ ] 文档将设备桌面添加、显示和点击明确标记为 `UNVERIFIED`。
- [ ] Git 状态只包含预期提交，构建产物和签名材料未被追踪。

## Rollback and Cleanup

若当前 API 26 SDK 的 Form profile Schema 或 ArkTS 卡片编译无法通过：

1. 保留原始构建日志并记录失败字段；
2. 只按本机 SDK Schema 调整 Form 专属文件，不改需求方向；
3. 若仍不可用，撤销未提交的 Task 2、Task 3 文件，保留设计与验证记录；
4. 不修改 `EntryAbility` 或正式业务链路来规避 Form Kit 失败；
5. `entry/build/`、`entry/.test/` 和本地签名材料仍由现有 `.gitignore` 管理，可直接清理，不纳入源码提交。

