import { describe, expect, it } from '@ohos/hypium';
import {
  canDispatchGlassAction,
  createGlassActionInteractionState,
  createGlassActionVisualState,
  GlassActionStyle,
  GlassActionInteractionState
} from '../../main/ets/components/common/GlassActionButtonModels';
import { AccentTheme, VisualEffectMode } from '../../main/ets/model/SettingsModels';
import { EffectiveTheme, getThemePalette } from '../../main/ets/theme/ThemeModels';

export default function glassActionButtonModelsTest() {
  describe('GlassActionButtonModels', () => {
    it('uses fixed Morandi primary tokens in light and dark themes', 0, () => {
      const lightPalette = getThemePalette(EffectiveTheme.LIGHT, AccentTheme.BLUE);
      const darkPalette = getThemePalette(EffectiveTheme.DARK, AccentTheme.PURPLE);
      const light = createGlassActionVisualState(
        lightPalette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, false
      );
      const dark = createGlassActionVisualState(
        darkPalette, EffectiveTheme.DARK, VisualEffectMode.FULL, true, false
      );

      expect(light.backgroundColor).assertEqual('#E67189A6');
      expect(light.foregroundColor).assertEqual('#18232D');
      expect(light.borderColor).assertEqual('#D7E0E9');
      expect(light.useLightMaterial).assertFalse();
      expect(light.useDarkBlur).assertFalse();
      expect(dark.backgroundColor).assertEqual('#E67189A6');
      expect(dark.shadowColor).assertEqual('#667189A6');
      expect(dark.useLightMaterial).assertFalse();
      expect(dark.useDarkBlur).assertTrue();
    });

    it('reduces and disables visual effects deterministically', 0, () => {
      const palette = getThemePalette(EffectiveTheme.DARK, AccentTheme.BLUE);
      const full = createGlassActionVisualState(
        palette, EffectiveTheme.DARK, VisualEffectMode.FULL, true, false
      );
      const reduced = createGlassActionVisualState(
        palette, EffectiveTheme.DARK, VisualEffectMode.REDUCED, true, false
      );
      const off = createGlassActionVisualState(
        palette, EffectiveTheme.DARK, VisualEffectMode.OFF, true, true
      );

      expect(full.shadowRadius).assertEqual(24);
      expect(reduced.shadowRadius).assertEqual(10);
      expect(off.shadowRadius).assertEqual(0);
      expect(off.useDarkBlur).assertFalse();
      expect(off.scale).assertEqual(1);
    });

    it('keeps disabled text readable and removes glow', 0, () => {
      const palette = getThemePalette(EffectiveTheme.LIGHT, AccentTheme.GREEN);
      const disabled = createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, false, false
      );

      expect(disabled.foregroundColor).assertEqual(palette.primaryText);
      expect(disabled.opacity).assertEqual(1);
      expect(disabled.shadowRadius).assertEqual(0);
      expect(disabled.useLightMaterial).assertFalse();
    });

    it('scales only an enabled pressed button when effects are active', 0, () => {
      const palette = getThemePalette(EffectiveTheme.LIGHT, AccentTheme.BLUE);
      expect(createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, true
      ).scale).assertEqual(0.98);
      expect(createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, false, true
      ).scale).assertEqual(1);
    });

    it('dispatches only while enabled and not loading', 0, () => {
      expect(canDispatchGlassAction(true, false)).assertTrue();
      expect(canDispatchGlassAction(false, false)).assertFalse();
      expect(canDispatchGlassAction(true, true)).assertFalse();
    });

    it('maps fixed Morandi colors to semantic button styles', 0, () => {
      const palette = getThemePalette(EffectiveTheme.LIGHT, AccentTheme.PURPLE);
      const primary = createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, false, GlassActionStyle.PRIMARY
      );
      const favorite = createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, false, GlassActionStyle.FAVORITE
      );
      const danger = createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, false, GlassActionStyle.DANGER
      );
      const secondary = createGlassActionVisualState(
        palette, EffectiveTheme.LIGHT, VisualEffectMode.FULL, true, false, GlassActionStyle.SECONDARY
      );

      expect(primary.backgroundColor).assertEqual('#E67189A6');
      expect(favorite.backgroundColor).assertEqual('#E67F9B86');
      expect(danger.backgroundColor).assertEqual('#E6B06F61');
      expect(secondary.backgroundColor).assertEqual('#D9A7B2BE');
      expect(primary.shadowColor).assertEqual('#667189A6');
      expect(favorite.shadowColor).assertEqual('#667F9B86');
      expect(danger.shadowColor).assertEqual('#66B06F61');
    });

    it('keeps semantic colors fixed across accent themes and removes glow when effects are off', 0, () => {
      const blue = createGlassActionVisualState(
        getThemePalette(EffectiveTheme.DARK, AccentTheme.BLUE), EffectiveTheme.DARK,
        VisualEffectMode.OFF, true, true, GlassActionStyle.FAVORITE
      );
      const purple = createGlassActionVisualState(
        getThemePalette(EffectiveTheme.DARK, AccentTheme.PURPLE), EffectiveTheme.DARK,
        VisualEffectMode.OFF, true, true, GlassActionStyle.FAVORITE
      );

      expect(blue.backgroundColor).assertEqual(purple.backgroundColor);
      expect(blue.shadowRadius).assertEqual(0);
      expect(blue.scale).assertEqual(1);
      expect(blue.useDarkBlur).assertFalse();
    });

    it('keeps native rendering enabled while blocking unavailable actions', 0, () => {
      const disabled: GlassActionInteractionState = createGlassActionInteractionState(false, false);
      const loading: GlassActionInteractionState = createGlassActionInteractionState(true, true);

      expect(disabled.nativeEnabled).assertTrue();
      expect(disabled.actionAvailable).assertFalse();
      expect(loading.nativeEnabled).assertTrue();
      expect(loading.actionAvailable).assertFalse();
    });
  });
}
