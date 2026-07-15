import { EmptyStateView } from '../../components/common/EmptyStateView';
import { HistoryReportCard } from '../../components/history/HistoryReportCard';
import { AppRouter } from '../../router/AppRouter';
import { RouteName } from '../../router/RouteNames';
import { getHomeViewModel } from '../../service/platform/AppRuntime';
import { AppStateStore } from '../../store/AppStateStore';
import { getThemePalette, ThemePalette } from '../../theme/ThemeModels';
import { HomeReportItem } from '../../viewmodel/home/HomeModels';
import { HomeViewModel } from '../../viewmodel/home/HomeViewModel';

@Component
export struct RecordsRootView {
  @Consume('appRouter')
  router: AppRouter;
  @Consume('appState')
  appState: AppStateStore;
  @State
  private homeViewModel: HomeViewModel = getHomeViewModel();

  private palette(): ThemePalette {
    return getThemePalette(this.appState.effectiveTheme, this.appState.accentTheme);
  }

  aboutToAppear(): void {
    this.homeViewModel.loadRecent();
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('诊断记录')
          .width('100%')
          .fontSize(30 * this.appState.contentFontMultiplier)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().primaryText)
        Text('最近保存的本地诊断报告')
          .width('100%')
          .fontSize(15 * this.appState.contentFontMultiplier)
          .fontColor(this.palette().secondaryText)
        if (this.homeViewModel.recentReports.length > 0) {
          ForEach(this.homeViewModel.recentReports, (item: HomeReportItem) => {
            HistoryReportCard({
              item: item,
              compact: false,
              onOpen: (): void => {
                this.router.openReport({
                  reportId: item.reportId,
                  origin: RouteName.HISTORY_SETTINGS
                });
              }
            })
          }, (item: HomeReportItem): string => item.reportId)
        } else {
          EmptyStateView({
            title: '还没有诊断记录',
            description: '完成诊断并主动保存后，记录会显示在这里。'
          })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 112 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().pageBackground)
  }
}
