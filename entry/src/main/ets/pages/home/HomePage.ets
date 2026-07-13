import { SourceType } from '../../model/DiagnosisModels';
import { ThemeMode } from '../../model/SettingsModels';
import { AppRouter, ArkNavigationStack } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import {
  appStateStore as globalAppStateStore,
  switchApplicationTheme
} from '../../service/platform/AppRuntime';
import { AppStateStore } from '../../store/AppStateStore';
import {
  getThemePalette,
  ThemePalette,
  themeStatusText
} from '../../theme/ThemeModels';
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
  @Provide('appState')
  private appState: AppStateStore = globalAppStateStore;

  private palette(): ThemePalette {
    return getThemePalette(this.appState.effectiveTheme);
  }

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
            .fontColor(this.palette().primaryText)
          Text($r('app.string.route_unknown_message'))
            .fontColor(this.palette().secondaryText)
          Button($r('app.string.route_back_home'))
            .onClick(() => this.appRouter.openHome())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(24)
        .backgroundColor(this.palette().pageBackground)
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
          .fontColor(this.palette().primaryText)
        Text($r('app.string.app_name'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().primaryText)
        Text($r('app.string.home_placeholder'))
          .fontSize(16)
          .fontColor(this.palette().secondaryText)
        Text($r('app.string.route_placeholder_message'))
          .fontSize(14)
          .fontColor(this.palette().secondaryText)
        Text(themeStatusText(this.appState.selectedThemeMode, this.appState.effectiveTheme))
          .fontSize(14)
          .fontColor(this.palette().accent)
        if (this.appState.isThemeSessionOnly) {
          Text($r('app.string.theme_session_only'))
            .fontSize(14)
            .fontColor(this.palette().error)
        }
        Button($r('app.string.theme_verify_light'))
          .onClick(() => switchApplicationTheme(ThemeMode.LIGHT))
        Button($r('app.string.theme_verify_dark'))
          .onClick(() => switchApplicationTheme(ThemeMode.DARK))
        Button($r('app.string.theme_verify_system'))
          .onClick(() => switchApplicationTheme(ThemeMode.SYSTEM))
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
      .backgroundColor(this.palette().pageBackground)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeDestination)
    .backgroundColor(this.palette().navigationBackground)
  }
}
