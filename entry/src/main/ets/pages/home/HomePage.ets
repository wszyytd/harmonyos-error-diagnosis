@Entry
@Component
struct HomePage {
  build() {
    Column({ space: 12 }) {
      Text($r('app.string.app_name'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text($r('app.string.home_placeholder'))
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }
}
