import { AppStateStore } from '../../store/AppStateStore';
import {
  beginFavoriteToggle,
  completeFavoriteToggle,
  FavoriteToggleTransition
} from '../common/FavoriteActionModels';
import { GlassActionButton } from '../common/GlassActionButton';
import { GlassActionStyle } from '../common/GlassActionButtonModels';
import {
  getThemePalette,
  ThemePalette
} from '../../theme/ThemeModels';
import { HomeReportItem } from '../../viewmodel/home/HomeModels';

@Component
export struct HistoryReportCard {
  @Consume('appState')
  appState: AppStateStore;
  @Prop
  item: HomeReportItem;
  @Prop
  compact: boolean = true;
  @Prop
  idPrefix: string = 'home_recent_report';
  @Prop
  showActions: boolean = false;
  @State
  private favoriteValue: boolean = false;
  @State
  private favoriteUpdating: boolean = false;
  onOpen: () => void = (): void => {};
  onFavorite: (favorite: boolean) => Promise<boolean> = async (): Promise<boolean> => false;
  onDelete: () => void = (): void => {};

  aboutToAppear(): void {
    this.favoriteValue = this.item.isFavorite;
  }

  private async toggleFavorite(): Promise<void> {
    if (this.favoriteUpdating) {
      return;
    }
    const transition: FavoriteToggleTransition = beginFavoriteToggle(this.favoriteValue);
    this.favoriteUpdating = true;
    this.favoriteValue = transition.pendingValue;
    const succeeded: boolean = await this.onFavorite(transition.pendingValue);
    this.favoriteValue = completeFavoriteToggle(transition, succeeded);
    this.favoriteUpdating = false;
  }

  private palette(): ThemePalette {
    return getThemePalette(this.appState.effectiveTheme, this.appState.accentTheme);
  }

  build() {
    Column({ space: this.compact ? 8 : 12 }) {
      Row({ space: 8 }) {
        Text(this.item.errorType)
          .layoutWeight(1)
          .fontSize((this.compact ? 16 : 18) * this.appState.contentFontMultiplier)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().primaryText)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.sourceLabel)
          .fontSize(12 * this.appState.contentFontMultiplier)
          .fontColor(this.palette().accent)
      }
      .width('100%')

      Text(this.item.summary)
        .width('100%')
          .fontSize(14 * this.appState.contentFontMultiplier)
        .fontColor(this.palette().secondaryText)
        .maxLines(this.compact ? 2 : 4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(this.item.savedAtText)
          .fontSize(12 * this.appState.contentFontMultiplier)
          .fontColor(this.palette().secondaryText)
        Blank()
        GlassActionButton({
          label: $r('app.string.home_recent_open'),
          buttonId: `${this.idPrefix}_open_${this.item.reportId}`,
          compact: true,
          actionStyle: GlassActionStyle.PRIMARY,
          onAction: (): void => { this.onOpen(); }
        })
      }
      .width('100%')

      if (this.showActions) {
        Row({ space: 10 }) {
          GlassActionButton({
            label: this.favoriteValue ? '取消收藏' : '收藏',
            buttonId: `${this.idPrefix}_favorite_${this.item.reportId}`,
            buttonWidth: '48%',
            loading: this.favoriteUpdating,
            actionStyle: GlassActionStyle.FAVORITE,
            onAction: (): void => { this.toggleFavorite(); }
          })
          GlassActionButton({
            label: '删除',
            buttonId: `${this.idPrefix}_delete_${this.item.reportId}`,
            buttonWidth: '48%',
            actionStyle: GlassActionStyle.DANGER,
            onAction: (): void => { this.onDelete(); }
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 88 })
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .borderRadius(14)
    .backgroundColor(this.palette().surfaceBackground)
    .id(`${this.idPrefix}_${this.item.reportId}`)
    .accessibilityGroup(true)
    .accessibilityText(this.item.accessibilityText)
    .accessibilityDescription($r('app.string.home_recent_open_accessibility'))
    .onClick((): void => {
      if (!this.showActions) {
        this.onOpen();
      }
    })
  }
}
