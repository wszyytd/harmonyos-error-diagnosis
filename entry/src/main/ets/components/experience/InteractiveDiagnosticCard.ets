import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { sensor } from '@kit.SensorServiceKit';
import { uiMaterial } from '@kit.ArkUI';

@Component
export struct InteractiveDiagnosticCard {
  @State private activated: boolean = false;
  @State private sensorStatus: string = '点击启用摇一摇，也可直接点击卡片演示';
  private lastTriggerAt: number = 0;
  private readonly material: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: '#221A3B5C',
    applyShadow: true,
    interactive: true,
    lightEffect: { color: '#5CE1D0' }
  });

  private trigger(): void {
    const now = Date.now();
    if (now - this.lastTriggerAt < 700) {
      return;
    }
    this.lastTriggerAt = now;
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.activated = !this.activated;
    });
  }

  private async enableShake(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const manager = abilityAccessCtrl.createAtManager();
      const permission: Permissions = 'ohos.permission.ACCELEROMETER';
      const result = await manager.requestPermissionsFromUser(context, [permission]);
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        this.sensorStatus = '未获得传感器权限，可点击卡片演示动态效果';
        return;
      }
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse): void => {
        const strength = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
        if (strength > 19) {
          this.trigger();
          this.sensorStatus = '检测到摇一摇，互动卡片已切换';
        }
      }, { interval: 100000000 });
      this.sensorStatus = '传感器已启用，请摇动设备';
    } catch (_) {
      this.sensorStatus = '模拟器传感器不可用，可点击卡片演示';
    }
  }

  aboutToDisappear(): void {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (_) {
    }
  }

  build() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column({ space: 8 }) {
          Text(this.activated ? '动态诊断卡片' : '互动诊断卡片')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#F4F7FC')
            .fontVariations([{ axis: 'wght', value: this.activated ? 820 : 650 }])
          Text(this.activated ? '前景已出框 · 规则匹配 12 项 · AI 就绪' : '摇一摇手机，让静态卡片转为动态状态')
            .fontSize(13).fontColor('#AAB8CC').textAlign(TextAlign.Center)
        }
        .translate({ y: this.activated ? -8 : 0 })
        if (this.activated) {
          Text('⚡').fontSize(46).translate({ x: 120, y: -76 }).rotate({ angle: 12 })
        }
      }
      .width('100%').height(190).backgroundColor('#B30B1628').systemMaterial(this.material)
      .border({ width: 1, color: this.activated ? '#5CE1D0' : '#34506F' }).borderRadius(24)
      .shadow({ radius: this.activated ? 26 : 8, color: this.activated ? '#665CE1D0' : '#22000000', offsetY: 8 })
      .scale({ x: this.activated ? 1.02 : 1, y: this.activated ? 1.02 : 1 })
      .onClick(() => this.trigger())
      Text(this.sensorStatus).width('100%').fontSize(12).fontColor('#91A0B8')
      Button('启用摇一摇').width('100%').height(46).backgroundColor('#12A69A').borderRadius(14)
        .onClick(() => this.enableShake())
    }.width('100%')
  }
}
