/**
 * T17 UI 自动化边界：API 26 模拟器的 UiTest 滚动/手势 API 会阻塞全局测试通道。
 * 依赖滚动的诊断与报告流程改为手动验收；校验、并发、旧异步结果和报告会话由 Local Test 覆盖。
 * 本套件暂不注册到日常 ohosTest；唯一的无滚动入口冒烟用例保留在 HomePageSmoke.test.ets。
 */
export default function manualDiagnosisFlowTest(): void {
}
