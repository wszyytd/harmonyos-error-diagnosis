import { AppRouter } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';

@Component
export struct HistorySettingsPage {
  @Consume('appRouter')
  router: AppRouter;

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text($r('app.string.route_history_settings_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_placeholder_message'))
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.route_open_privacy'))
          .onClick(() => this.router.openPrivacy({
            origin: RouteName.HISTORY_SETTINGS
          }))
        Button($r('app.string.route_open_report_placeholder'))
          .onClick(() => this.router.openReport({
            reportId: 't11-placeholder-report',
            origin: RouteName.HISTORY_SETTINGS
          }))
        Button($r('app.string.route_back_home'))
          .onClick(() => this.router.back())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .title($r('app.string.route_history_settings_title'))
  }
}
