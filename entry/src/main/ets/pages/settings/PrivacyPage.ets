import { AppRouter } from '../../router/AppRouter';

@Component
export struct PrivacyPage {
  @Consume('appRouter')
  router: AppRouter;

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text($r('app.string.route_privacy_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_placeholder_message'))
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.route_back_history_settings'))
          .onClick(() => this.router.back())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .title($r('app.string.route_privacy_title'))
  }
}
