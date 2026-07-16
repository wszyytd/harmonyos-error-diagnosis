import { AsyncStatePanel } from '../../components/common/AsyncStatePanel';
import { ConfirmActionDialog } from '../../components/common/ConfirmActionDialog';
import { GlassActionButton } from '../../components/common/GlassActionButton';
import { GlassActionStyle } from '../../components/common/GlassActionButtonModels';
import { EmptyStateView } from '../../components/common/EmptyStateView';
import { InlineErrorNotice } from '../../components/common/InlineErrorNotice';
import { HistoryReportCard } from '../../components/history/HistoryReportCard';
import { OperationStatus } from '../../model/ResultModels';
import { AppRouter } from '../../router/AppRouter';
import { createHistoryViewModel } from '../../service/platform/AppRuntime';
import { AppStateStore } from '../../store/AppStateStore';
import { getThemePalette, ThemePalette } from '../../theme/ThemeModels';
import { HomeReportItem } from '../../viewmodel/home/HomeModels';
import { HistoryViewModel } from '../../viewmodel/history/HistoryViewModel';

@Component
export struct RecordsRootView {
  @Consume('appRouter')
  router: AppRouter;
  @Consume('appState')
  appState: AppStateStore;
  @State
  private viewModel: HistoryViewModel | undefined = undefined;
  @State
  private pendingDeleteId: string = '';

  private deleteDialogController: CustomDialogController = new CustomDialogController({
    builder: ConfirmActionDialog({
      title: '删除这条历史记录？',
      message: '删除后无法恢复，但不会影响其他历史记录。',
      dangerous: true,
      onConfirm: (): void => { this.confirmDelete(); },
      onCancel: (): void => { this.pendingDeleteId = ''; }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  private clearDialogController: CustomDialogController = new CustomDialogController({
    builder: ConfirmActionDialog({
      title: '清空全部历史记录？',
      message: '将永久删除全部历史报告，此操作不可恢复。',
      dangerous: true,
      onConfirm: (): void => { this.viewModel?.clearHistory(); },
      onCancel: (): void => {}
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  private palette(): ThemePalette {
    return getThemePalette(this.appState.effectiveTheme, this.appState.accentTheme);
  }

  aboutToAppear(): void {
    if (this.viewModel === undefined) {
      this.viewModel = createHistoryViewModel(this.router);
    }
    this.viewModel.loadHistory();
  }

  aboutToDisappear(): void {
    this.viewModel?.dispose();
  }

  private requestDelete(reportId: string): void {
    this.pendingDeleteId = reportId;
    this.deleteDialogController.open();
  }

  private confirmDelete(): void {
    const reportId = this.pendingDeleteId;
    this.pendingDeleteId = '';
    if (reportId.length > 0) {
      this.viewModel?.deleteReport(reportId);
    }
  }

  private toggleFavorite(reportId: string, favorite: boolean): Promise<boolean> {
    if (this.viewModel === undefined) {
      return Promise.resolve(false);
    }
    return this.viewModel.toggleFavorite(reportId, favorite);
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
        if (this.viewModel === undefined || this.viewModel.historyStatus === OperationStatus.LOADING) {
          AsyncStatePanel({
            status: OperationStatus.LOADING,
            message: '正在加载历史记录',
            showContent: false
          })
        } else {
          if (this.viewModel.historyStatus === OperationStatus.ERROR) {
            InlineErrorNotice({
              message: this.viewModel.historyError?.message ??
                '暂时无法读取历史记录，请稍后重试。',
              actionLabel: '重新加载',
              onAction: (): void => { this.viewModel?.retryHistory(); }
            })
          }
          if (this.viewModel.mutationStatus === OperationStatus.LOADING) {
            Text('正在更新历史记录…')
              .width('100%')
              .fontColor(this.palette().secondaryText)
          } else if (this.viewModel.mutationStatus === OperationStatus.ERROR) {
            InlineErrorNotice({
              message: this.viewModel.mutationError?.message ?? '更新失败，历史记录未更改，请重试。',
              actionLabel: '重试',
              onAction: (): void => { this.viewModel?.retryMutation(); }
            })
          }
          if (this.viewModel.isHistoryEmpty) {
            EmptyStateView({
              title: '还没有诊断记录',
              description: '完成诊断并主动保存后，记录会显示在这里。'
            })
          } else {
            ForEach(this.viewModel.historyReports, (item: HomeReportItem) => {
              HistoryReportCard({
                item: item,
                compact: false,
                idPrefix: 'history_report',
                showActions: true,
                onOpen: (): void => { this.viewModel?.openReport(item.reportId); },
                onFavorite: (favorite: boolean): Promise<boolean> => {
                  return this.toggleFavorite(item.reportId, favorite);
                },
                onDelete: (): void => { this.requestDelete(item.reportId); }
              })
            }, (item: HomeReportItem): string => item.reportId)
          }
        }
        if (this.viewModel !== undefined && !this.viewModel.isHistoryEmpty) {
          GlassActionButton({
            label: '清空全部历史记录',
            buttonId: 'history_clear_all',
            actionEnabled: this.viewModel.mutationStatus !== OperationStatus.LOADING,
            actionStyle: GlassActionStyle.DANGER,
            onAction: (): void => { this.clearDialogController.open(); }
          })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 190 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().pageBackground)
  }
}
