import { SourceType } from '../model/DiagnosisModels';
import { AppResult } from '../model/ResultModels';
import { RouteName } from './RouteNames';

/** Tool values defined by detailed design; T11 only transports the enum. */
export enum ToolType {
  JSON = 'JSON',
  HTTP_STATUS = 'HTTP_STATUS',
  URL_CODEC = 'URL_CODEC',
  BASE64_CODEC = 'BASE64_CODEC',
  REGEX = 'REGEX'
}

export interface DiagnosisRouteParams {
  sourceType: SourceType;
  sessionId?: string;
  origin: RouteName;
}

export interface ReportRouteParams {
  sessionId?: string;
  reportId?: string;
  origin: RouteName;
}

export interface ToolsRouteParams {
  toolType?: ToolType;
  sessionId?: string;
  reportId?: string;
  origin: RouteName;
}

export interface HistorySettingsRouteParams {
  origin?: RouteName;
}

export interface PrivacyRouteParams {
  origin: RouteName;
}

export type AppRouteParams = DiagnosisRouteParams | ReportRouteParams | ToolsRouteParams |
  HistorySettingsRouteParams | PrivacyRouteParams;

/** Runtime view of an external route object before validation and sanitization. */
export interface RouteParamBag {
  sourceType?: string;
  sessionId?: string;
  reportId?: string;
  toolType?: string;
  origin?: string;
}

export interface RouteDefinition {
  name: RouteName;
  path: string;
}

export interface ResolvedRoute {
  name: RouteName;
  path: string;
  params?: AppRouteParams;
}

/** A failed decision always provides the route to use for safe recovery. */
export interface RouteDecision {
  result: AppResult<ResolvedRoute>;
  fallback: RouteName;
}
