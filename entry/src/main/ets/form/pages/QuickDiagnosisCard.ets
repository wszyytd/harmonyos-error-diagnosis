const formStorage = new LocalStorage();

@Entry(formStorage)
@Component
struct QuickDiagnosisCard {
  @LocalStorageProp('appName') appName: string = '开发报错诊断助手';
  @LocalStorageProp('title') title: string = '快速诊断';
  @LocalStorageProp('description') description: string = '从桌面进入本地报错分析';
  @LocalStorageProp('actionLabel') actionLabel: string = '打开应用';
  @LocalStorageProp('privacyHint') privacyHint: string = '数据仅保存在本机';

  build() {
    Column({ space: 8 }) {
      Text(this.appName)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')

      Text(this.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.form_card_primary'))
        .width('100%')

      Text(this.description)
        .fontSize(14)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')

      Blank()

      Button(this.actionLabel)
        .height(44)
        .width('100%')
        .fontSize(16)
        .fontColor($r('app.color.form_card_on_accent'))
        .backgroundColor($r('app.color.form_card_accent'))
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility'
          });
        })

      Text(this.privacyHint)
        .fontSize(11)
        .fontColor($r('app.color.form_card_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.form_card_background'))
  }
}
