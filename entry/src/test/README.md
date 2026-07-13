# Local Test 约定

## 目录

- `unit/`：不依赖 HarmonyOS设备、存储或平台能力的单元测试。
- `components/`：可在 Local Test环境运行的纯组件状态与事件测试。
- `fixtures/`：合成、可复现且不含隐私数据的测试输入。
- `fakes/`：后续 Repository和 Service测试替身；只实现生产接口，不定义平行契约。
- `List.test.ets`：测试套件唯一聚合入口。

## 规则

1. 测试文件使用 `<Subject>.test.ets`，suite名称与被测对象一致，case名称描述可观察行为。
2. 每个 case只验证一个行为；测试必须能说明删掉或破坏哪项行为时会失败。
3. Fixture每次返回独立实例，测试不得依赖执行顺序或其他 case遗留状态。
4. Fake只隔离网络、OCR、系统能力或持久化边界；不得断言 Fake本身“被创建”，也不得在生产代码增加测试专用方法。
5. Repository和 Service通过接口注入；页面/ViewModel测试依赖接口或 Fake，不直接访问真实数据库和平台服务。
6. Local Test禁止网络、OCR、真实账号、签名材料、设备标识、用户文件和真实日志。
7. 测试数据必须明确为 synthetic，不包含 Token、密码、Authorization、私有地址或个人信息。

`entry/src/mock/` 是 DevEco预览 Mock配置，不作为业务测试替身目录。
