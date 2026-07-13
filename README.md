# 开发报错诊断助手

HarmonyOS API 26、ArkTS Stage模型的本地开发报错诊断应用。

## 开发环境

- DevEco Studio 26.0.0.461
- HarmonyOS SDK 26.0.0.23 / API 26
- OHPM 26.0.0.410
- Hvigor 6.26.1

PowerShell执行 Hvigor前设置：

```powershell
$env:DEVECO_SDK_HOME='D:\Dev\IDE\DevEco Studio\sdk'
```

## 验证命令

依赖安装、Local Test和 Debug构建：

```powershell
& 'D:\Dev\IDE\DevEco Studio\tools\ohpm\bin\ohpm.bat' install

& 'D:\Dev\IDE\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default `
  test --no-daemon

& 'D:\Dev\IDE\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p module=entry@default -p product=default `
  -p buildMode=debug -p requiredDeviceType=phone `
  assembleHap --no-daemon
```

ArkTS Linter（命令行参数中的 SDK根目录是 `sdk`，API数值版本需使用 `26.0.0`）：

```powershell
$project = (Get-Location).Path
$node = 'D:\Dev\IDE\DevEco Studio\tools\node\node.exe'
$linter = 'D:\Dev\IDE\DevEco Studio\plugins\codelinter\index.js'
$checkPaths = '[\"' + ($project -replace '\\', '/') + '/entry/src/main/ets\"]'

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

设备测试需要先安装由同一套本地 Debug签名签署的应用 HAP和 `ohosTest` HAP。签名产物只放在被 Git忽略的 `entry/build/`，不得使用或提交发布证书、私钥和口令。安装完成后执行：

```powershell
$hdc = 'D:\Dev\IDE\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc list targets
& $hdc -t 127.0.0.1:5555 shell aa test `
  -b com.example.errordiagnosis -m entry_test `
  -s unittest OpenHarmonyTestRunner -s timeout 30000 -w 60
```

当前 `build-profile.json5` 不保存本机签名配置，因此直接执行 `onDeviceTest` 会在安装前因缺少 signed HAP退出非零；这不影响 Local Test、ohosTest源码编译或 Debug unsigned HAP构建。

## 测试边界

- Local Test只测试纯逻辑、Fixture和通过接口注入的替身。
- UI/Instrument Test用于真实 ArkUI、系统存储和设备流程。
- 测试不访问网络、OCR、真实账号、签名材料或设备隐私数据。
- 后续 Repository/Service必须先定义生产接口，测试 Fake放在测试源集并实现同一接口。
