import { VisualEffectMode } from '../../model/SettingsModels';
import { EffectiveTheme, ThemePalette } from '../../theme/ThemeModels';

export interface GlassActionVisualState {
  backgroundColor: string;
  foregroundColor: string;
  borderColor: string;
  borderWidth: number;
  shadowRadius: number;
  shadowColor: string;
  shadowOffsetY: number;
  useLightMaterial: boolean;
  useDarkBlur: boolean;
  scale: number;
  opacity: number;
  animationEnabled: boolean;
}

export interface GlassActionInteractionState {
  actionAvailable: boolean;
  nativeEnabled: boolean;
}

export enum GlassActionStyle {
  PRIMARY = 'PRIMARY',
  FAVORITE = 'FAVORITE',
  DANGER = 'DANGER',
  SECONDARY = 'SECONDARY'
}

interface MorandiStyleColors {
  background: string;
  foreground: string;
  border: string;
  glow: string;
}

function morandiColors(style: GlassActionStyle, theme: EffectiveTheme): MorandiStyleColors {
  if (style === GlassActionStyle.FAVORITE) {
    return {
      background: '#E67F9B86',
      foreground: theme === EffectiveTheme.DARK ? '#FFFDFC' : '#18232D',
      border: theme === EffectiveTheme.DARK ? '#D4E4D7' : '#D7E5D9',
      glow: '#667F9B86'
    };
  }
  if (style === GlassActionStyle.DANGER) {
    return {
      background: '#E6B06F61',
      foreground: theme === EffectiveTheme.DARK ? '#FFFDFC' : '#18232D',
      border: theme === EffectiveTheme.DARK ? '#F0D0C9' : '#E9CBC4',
      glow: '#66B06F61'
    };
  }
  if (style === GlassActionStyle.SECONDARY) {
    return {
      background: '#D9A7B2BE',
      foreground: theme === EffectiveTheme.DARK ? '#F5F7F9' : '#263441',
      border: theme === EffectiveTheme.DARK ? '#D5DDE5' : '#DDE4EA',
      glow: '#4DA7B2BE'
    };
  }
  return {
    background: '#E67189A6',
    foreground: theme === EffectiveTheme.DARK ? '#FFFDFC' : '#18232D',
    border: theme === EffectiveTheme.DARK ? '#D8E2EC' : '#D7E0E9',
    glow: '#667189A6'
  };
}

export function canDispatchGlassAction(enabled: boolean, loading: boolean): boolean {
  return enabled && !loading;
}

export function createGlassActionInteractionState(
  enabled: boolean,
  loading: boolean
): GlassActionInteractionState {
  return {
    actionAvailable: canDispatchGlassAction(enabled, loading),
    nativeEnabled: true
  };
}

export function createGlassActionVisualState(
  palette: ThemePalette,
  theme: EffectiveTheme,
  effectMode: VisualEffectMode,
  enabled: boolean,
  pressed: boolean,
  style: GlassActionStyle = GlassActionStyle.PRIMARY
): GlassActionVisualState {
  const effectsEnabled: boolean = effectMode !== VisualEffectMode.OFF && enabled;
  const colors: MorandiStyleColors = morandiColors(style, theme);
  let shadowRadius: number = 0;
  if (effectsEnabled) {
    shadowRadius = effectMode === VisualEffectMode.FULL ? 24 : 10;
  }
  return {
    backgroundColor: enabled ? colors.background : '#B3A7B2BE',
    foregroundColor: enabled ? colors.foreground : palette.primaryText,
    borderColor: enabled ? colors.border : '#8097A4B0',
    borderWidth: 1,
    shadowRadius: shadowRadius,
    shadowColor: effectsEnabled ? colors.glow : '#00000000',
    shadowOffsetY: effectsEnabled ? 5 : 0,
    useLightMaterial: false,
    useDarkBlur: effectsEnabled && theme === EffectiveTheme.DARK,
    scale: effectsEnabled && pressed ? 0.98 : 1,
    opacity: 1,
    animationEnabled: effectsEnabled
  };
}
