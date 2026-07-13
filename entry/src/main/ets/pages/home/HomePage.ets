import { SourceType } from '../../model/DiagnosisModels';
import { AppRouter, ArkNavigationStack } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import { DiagnosisPage } from '../diagnosis/DiagnosisPage';
import { HistorySettingsPage } from '../history/HistorySettingsPage';
import { ReportPage } from '../report/ReportPage';
import { PrivacyPage } from '../settings/PrivacyPage';
import { ToolsPage } from '../tools/ToolsPage';

@Entry
@Component
struct HomePage {
  private readonly pathStack: NavPathStack = new NavPathStack();
  @Provide('appRouter')
  private appRouter: AppRouter = new AppRouter(new ArkNavigationStack(this.pathStack));

  @Builder
  routeDestination(routeName: string) {
    if (routeName === RouteName.DIAGNOSIS) {
      DiagnosisPage();
    } else if (routeName === RouteName.REPORT) {
      ReportPage();
    } else if (routeName === RouteName.TOOLS) {
      ToolsPage();
    } else if (routeName === RouteName.HISTORY_SETTINGS) {
      HistorySettingsPage();
    } else if (routeName === RouteName.PRIVACY) {
      PrivacyPage();
    } else {
      NavDestination() {
        Column({ space: 12 }) {
          Text($r('app.string.route_unknown_title'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
          Text($r('app.string.route_unknown_message'))
          Button($r('app.string.route_back_home'))
            .onClick(() => this.appRouter.openHome())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(24)
      }
      .title($r('app.string.route_unknown_title'))
    }
  }

  build() {
    Navigation(this.pathStack) {
      Column({ space: 12 }) {
        Text($r('app.string.route_home_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.app_name'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.home_placeholder'))
          .fontSize(16)
          .fontColor($r('sys.color.font_secondary'))
        Text($r('app.string.route_placeholder_message'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.route_open_diagnosis'))
          .onClick(() => this.appRouter.openDiagnosis({
            sourceType: SourceType.TEXT,
            origin: RouteName.HOME
          }))
        Button($r('app.string.route_open_tools'))
          .onClick(() => this.appRouter.openTools({
            origin: RouteName.HOME
          }))
        Button($r('app.string.route_open_history_settings'))
          .onClick(() => this.appRouter.openHistorySettings({
            origin: RouteName.HOME
          }))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeDestination)
  }
}
