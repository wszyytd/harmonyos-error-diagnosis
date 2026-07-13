import { AppRouter } from '../../router/AppRouter';

@Component
export struct ToolsPage {
  @Consume('appRouter')
  router: AppRouter;

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text($r('app.string.route_tools_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_placeholder_message'))
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.route_back_origin'))
          .onClick(() => this.router.back())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .title($r('app.string.route_tools_title'))
  }
}
