import { AppRouter } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import { AppStateStore } from '../../store/AppStateStore';
import { getThemePalette, ThemePalette, themeStatusText } from '../../theme/ThemeModels';

@Component
export struct HistorySettingsPage {
  @Consume('appRouter')
  router: AppRouter;
  @Consume('appState')
  appState: AppStateStore;

  private palette(): ThemePalette {
    return getThemePalette(this.appState.effectiveTheme);
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text($r('app.string.route_history_settings_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().primaryText)
        Text($r('app.string.route_placeholder_message'))
          .fontColor(this.palette().secondaryText)
        Text(themeStatusText(this.appState.selectedThemeMode, this.appState.effectiveTheme))
          .fontColor(this.palette().accent)
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
      .backgroundColor(this.palette().pageBackground)
    }
    .title($r('app.string.route_history_settings_title'))
    .backgroundColor(this.palette().navigationBackground)
  }
}
