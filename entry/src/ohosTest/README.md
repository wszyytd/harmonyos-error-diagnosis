# Device Test 约定

- `ets/test/pages/`：页面与导航 smoke/UI测试。
- `ets/test/components/`：需要真实 ArkUI渲染的组件测试。
- `ets/test/repository/`：后续 Preferences、relationalStore等设备集成测试。
- `ets/test/acceptance/`：后续 AC-P0验收流程。
- `ets/test/List.test.ets`：设备测试套件唯一聚合入口。

设备测试只使用课程允许的模拟器或测试设备，不读取用户相册、账号、Token、签名文件或其他隐私数据。每个测试自行建立前置状态并清理其创建的数据，不依赖设备中已有的个人数据。
