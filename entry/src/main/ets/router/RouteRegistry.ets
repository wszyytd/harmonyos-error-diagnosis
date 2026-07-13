import { ErrorCode } from '../constants/ErrorCodes';
import { SourceType } from '../model/DiagnosisModels';
import { AppError, createFailureResult, createSuccessResult } from '../model/ResultModels';
import { RouteName } from './RouteNames';
import {
  AppRouteParams,
  DiagnosisRouteParams,
  HistorySettingsRouteParams,
  PrivacyRouteParams,
  ReportRouteParams,
  ResolvedRoute,
  RouteDecision,
  RouteDefinition,
  RouteParamBag,
  ToolType,
  ToolsRouteParams
} from './RouteModels';

const ROUTE_ID_MAX_LENGTH: number = 128;

const ROUTE_DEFINITIONS: Array<RouteDefinition> = [
  { name: RouteName.HOME, path: 'pages/home/HomePage' },
  { name: RouteName.DIAGNOSIS, path: 'pages/diagnosis/DiagnosisPage' },
  { name: RouteName.REPORT, path: 'pages/report/ReportPage' },
  { name: RouteName.TOOLS, path: 'pages/tools/ToolsPage' },
  { name: RouteName.HISTORY_SETTINGS, path: 'pages/history/HistorySettingsPage' },
  { name: RouteName.PRIVACY, path: 'pages/settings/PrivacyPage' }
];

const DIAGNOSIS_KEYS: Array<string> = ['sourceType', 'sessionId', 'origin'];
const REPORT_KEYS: Array<string> = ['sessionId', 'reportId', 'origin'];
const TOOLS_KEYS: Array<string> = ['toolType', 'sessionId', 'reportId', 'origin'];
const HISTORY_KEYS: Array<string> = ['origin'];
const PRIVACY_KEYS: Array<string> = ['origin'];

function createRouteError(message: string): AppError {
  return {
    code: ErrorCode.ROUTE_PARAM_INVALID,
    message: message,
    retryable: false,
    causeType: 'RouteValidation'
  };
}

function copyDefinition(definition: RouteDefinition): RouteDefinition {
  return {
    name: definition.name,
    path: definition.path
  };
}

export function getRouteDefinitions(): Array<RouteDefinition> {
  return ROUTE_DEFINITIONS.map((definition: RouteDefinition): RouteDefinition => copyDefinition(definition));
}

export function getRouteDefinition(name: string): RouteDefinition | undefined {
  const definition = ROUTE_DEFINITIONS.find((item: RouteDefinition) => item.name === name);
  return definition === undefined ? undefined : copyDefinition(definition);
}

function rejectRoute(message: string, fallback: RouteName): RouteDecision {
  return {
    result: createFailureResult<ResolvedRoute>(createRouteError(message)),
    fallback: fallback
  };
}

function acceptRoute(definition: RouteDefinition, params?: AppRouteParams): RouteDecision {
  const route: ResolvedRoute = {
    name: definition.name,
    path: definition.path
  };
  if (params !== undefined) {
    route.params = params;
  }
  return {
    result: createSuccessResult<ResolvedRoute>(route),
    fallback: RouteName.HOME
  };
}

function hasOnlyKeys(rawParams: object, allowedKeys: Array<string>): boolean {
  const keys = Object.keys(rawParams);
  return keys.every((key: string) => allowedKeys.includes(key));
}

function isValidOptionalId(value?: string): boolean {
  if (value === undefined) {
    return true;
  }
  if (typeof value !== 'string') {
    return false;
  }
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= ROUTE_ID_MAX_LENGTH;
}

function copyOptionalId(value?: string): string | undefined {
  return value === undefined ? undefined : value.trim();
}

function isOneOf(value: string | undefined, allowed: Array<RouteName>): boolean {
  if (value === undefined) {
    return false;
  }
  return allowed.some((item: RouteName) => item === value);
}

function originFallback(rawParams: object | undefined, allowed: Array<RouteName>): RouteName {
  if (rawParams === undefined) {
    return RouteName.HOME;
  }
  const origin = (rawParams as RouteParamBag).origin;
  return isOneOf(origin, allowed) ? origin as RouteName : RouteName.HOME;
}

function isToolType(value?: string): boolean {
  if (value === undefined) {
    return true;
  }
  return value === ToolType.JSON || value === ToolType.HTTP_STATUS || value === ToolType.URL_CODEC ||
    value === ToolType.BASE64_CODEC || value === ToolType.REGEX;
}

function resolveHome(definition: RouteDefinition, rawParams?: object): RouteDecision {
  if (rawParams !== undefined && Object.keys(rawParams).length > 0) {
    return rejectRoute('Home route does not accept parameters.', RouteName.HOME);
  }
  return acceptRoute(definition);
}

function resolveDiagnosis(definition: RouteDefinition, rawParams?: object): RouteDecision {
  const allowedOrigins: Array<RouteName> = [RouteName.HOME, RouteName.REPORT, RouteName.HISTORY_SETTINGS];
  const fallback = originFallback(rawParams, allowedOrigins);
  if (rawParams === undefined || !hasOnlyKeys(rawParams, DIAGNOSIS_KEYS)) {
    return rejectRoute('Diagnosis route contains unsupported parameters.', fallback);
  }
  const input = rawParams as RouteParamBag;
  const validSource = input.sourceType === SourceType.IMAGE || input.sourceType === SourceType.TEXT;
  if (!validSource || !isOneOf(input.origin, allowedOrigins) || !isValidOptionalId(input.sessionId)) {
    return rejectRoute('Diagnosis route parameters are invalid.', fallback);
  }
  const params: DiagnosisRouteParams = {
    sourceType: input.sourceType as SourceType,
    origin: input.origin as RouteName
  };
  const sessionId = copyOptionalId(input.sessionId);
  if (sessionId !== undefined) {
    params.sessionId = sessionId;
  }
  return acceptRoute(definition, params);
}

function resolveReport(definition: RouteDefinition, rawParams?: object): RouteDecision {
  const allowedOrigins: Array<RouteName> = [RouteName.DIAGNOSIS, RouteName.HOME, RouteName.HISTORY_SETTINGS];
  const fallback = originFallback(rawParams, allowedOrigins);
  if (rawParams === undefined || !hasOnlyKeys(rawParams, REPORT_KEYS)) {
    return rejectRoute('Report route contains unsupported parameters.', fallback);
  }
  const input = rawParams as RouteParamBag;
  const sessionIdPresent = input.sessionId !== undefined;
  const reportIdPresent = input.reportId !== undefined;
  if (sessionIdPresent === reportIdPresent || !isOneOf(input.origin, allowedOrigins) ||
    !isValidOptionalId(input.sessionId) || !isValidOptionalId(input.reportId)) {
    return rejectRoute('Report route requires exactly one non-empty identifier.', fallback);
  }
  const params: ReportRouteParams = {
    origin: input.origin as RouteName
  };
  const sessionId = copyOptionalId(input.sessionId);
  const reportId = copyOptionalId(input.reportId);
  if (sessionId !== undefined) {
    params.sessionId = sessionId;
  }
  if (reportId !== undefined) {
    params.reportId = reportId;
  }
  return acceptRoute(definition, params);
}

function resolveTools(definition: RouteDefinition, rawParams?: object): RouteDecision {
  const allowedOrigins: Array<RouteName> = [RouteName.HOME, RouteName.REPORT];
  const fallback = originFallback(rawParams, allowedOrigins);
  if (rawParams === undefined || !hasOnlyKeys(rawParams, TOOLS_KEYS)) {
    return rejectRoute('Tools route contains unsupported parameters.', fallback);
  }
  const input = rawParams as RouteParamBag;
  if (!isOneOf(input.origin, allowedOrigins) || !isToolType(input.toolType) ||
    !isValidOptionalId(input.sessionId) || !isValidOptionalId(input.reportId)) {
    return rejectRoute('Tools route parameters are invalid.', fallback);
  }
  const params: ToolsRouteParams = {
    origin: input.origin as RouteName
  };
  const sessionId = copyOptionalId(input.sessionId);
  const reportId = copyOptionalId(input.reportId);
  if (input.toolType !== undefined) {
    params.toolType = input.toolType as ToolType;
  }
  if (sessionId !== undefined) {
    params.sessionId = sessionId;
  }
  if (reportId !== undefined) {
    params.reportId = reportId;
  }
  return acceptRoute(definition, params);
}

function resolveHistorySettings(definition: RouteDefinition, rawParams?: object): RouteDecision {
  const allowedOrigins: Array<RouteName> = [RouteName.HOME, RouteName.REPORT];
  if (rawParams === undefined) {
    const defaultParams: HistorySettingsRouteParams = {
      origin: RouteName.HOME
    };
    return acceptRoute(definition, defaultParams);
  }
  const fallback = originFallback(rawParams, allowedOrigins);
  if (!hasOnlyKeys(rawParams, HISTORY_KEYS)) {
    return rejectRoute('History and settings route contains unsupported parameters.', fallback);
  }
  const input = rawParams as RouteParamBag;
  if (input.origin !== undefined && !isOneOf(input.origin, allowedOrigins)) {
    return rejectRoute('History and settings origin is invalid.', RouteName.HOME);
  }
  const params: HistorySettingsRouteParams = {
    origin: input.origin === undefined ? RouteName.HOME : input.origin as RouteName
  };
  return acceptRoute(definition, params);
}

function resolvePrivacy(definition: RouteDefinition, rawParams?: object): RouteDecision {
  const allowedOrigins: Array<RouteName> = [RouteName.HISTORY_SETTINGS];
  const fallback = originFallback(rawParams, allowedOrigins);
  if (rawParams === undefined || !hasOnlyKeys(rawParams, PRIVACY_KEYS)) {
    return rejectRoute('Privacy route contains unsupported parameters.', fallback);
  }
  const input = rawParams as RouteParamBag;
  if (input.origin !== RouteName.HISTORY_SETTINGS) {
    return rejectRoute('Privacy route must originate from history and settings.', RouteName.HOME);
  }
  const params: PrivacyRouteParams = {
    origin: RouteName.HISTORY_SETTINGS
  };
  return acceptRoute(definition, params);
}

/** Resolves and sanitizes a route request before it can mutate Navigation state. */
export function resolveRouteRequest(name: string, rawParams?: object): RouteDecision {
  const definition = getRouteDefinition(name);
  if (definition === undefined) {
    return rejectRoute('Unknown route name.', RouteName.HOME);
  }
  switch (definition.name) {
    case RouteName.HOME:
      return resolveHome(definition, rawParams);
    case RouteName.DIAGNOSIS:
      return resolveDiagnosis(definition, rawParams);
    case RouteName.REPORT:
      return resolveReport(definition, rawParams);
    case RouteName.TOOLS:
      return resolveTools(definition, rawParams);
    case RouteName.HISTORY_SETTINGS:
      return resolveHistorySettings(definition, rawParams);
    case RouteName.PRIVACY:
      return resolvePrivacy(definition, rawParams);
  }
}
