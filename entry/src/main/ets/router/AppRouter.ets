import { AppResult } from '../model/ResultModels';
import { RouteName } from './RouteNames';
import {
  DiagnosisRouteParams,
  HistorySettingsRouteParams,
  PrivacyRouteParams,
  ReportRouteParams,
  ResolvedRoute,
  ToolsRouteParams
} from './RouteModels';
import { resolveRouteRequest } from './RouteRegistry';

export interface RoutePathInfo {
  name: string;
  param?: object;
}

/** Minimal Navigation operations used by AppRouter and replaceable in Local Test. */
export interface NavigationStack {
  pushPath(info: RoutePathInfo): void;
  pop(): void;
  popToName(name: string): number;
  clear(): void;
  getAllPathName(): Array<string>;
}

/** Adapts API 26 NavPathStack without exposing it to pure route tests. */
export class ArkNavigationStack implements NavigationStack {
  private readonly stack: NavPathStack;

  constructor(stack: NavPathStack) {
    this.stack = stack;
  }

  pushPath(info: RoutePathInfo): void {
    this.stack.pushPath(new NavPathInfo(info.name, info.param));
  }

  pop(): void {
    this.stack.pop();
  }

  popToName(name: string): number {
    return this.stack.popToName(name);
  }

  clear(): void {
    this.stack.clear();
  }

  getAllPathName(): Array<string> {
    return this.stack.getAllPathName();
  }
}

export class AppRouter {
  private readonly stack: NavigationStack;
  private lastRouteName: string = '';
  private lastParamSignature: string = '';

  constructor(stack: NavigationStack) {
    this.stack = stack;
  }

  navigate(name: string, rawParams?: object): AppResult<ResolvedRoute> {
    const decision = resolveRouteRequest(name, rawParams);
    if (!decision.result.success || decision.result.data === undefined) {
      this.recover(decision.fallback);
      return decision.result;
    }
    const route = decision.result.data;
    if (route.name === RouteName.HOME) {
      this.stack.clear();
      this.resetDuplicateGuard();
      return decision.result;
    }
    const signature = route.params === undefined ? '' : JSON.stringify(route.params);
    const names = this.stack.getAllPathName();
    const topName = names.length === 0 ? '' : names[names.length - 1];
    if (topName === route.name && this.lastRouteName === route.name && this.lastParamSignature === signature) {
      return decision.result;
    }
    const pathInfo: RoutePathInfo = {
      name: route.name
    };
    if (route.params !== undefined) {
      pathInfo.param = route.params;
    }
    this.stack.pushPath(pathInfo);
    this.lastRouteName = route.name;
    this.lastParamSignature = signature;
    return decision.result;
  }

  openHome(): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.HOME);
  }

  openDiagnosis(params: DiagnosisRouteParams): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.DIAGNOSIS, params);
  }

  openReport(params: ReportRouteParams): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.REPORT, params);
  }

  openTools(params: ToolsRouteParams): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.TOOLS, params);
  }

  openHistorySettings(params?: HistorySettingsRouteParams): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.HISTORY_SETTINGS, params);
  }

  openPrivacy(params: PrivacyRouteParams): AppResult<ResolvedRoute> {
    return this.navigate(RouteName.PRIVACY, params);
  }

  back(): void {
    if (this.stack.getAllPathName().length > 0) {
      this.stack.pop();
    } else {
      this.stack.clear();
    }
    this.resetDuplicateGuard();
  }

  private recover(fallback: RouteName): void {
    const names = this.stack.getAllPathName();
    if (fallback === RouteName.HOME) {
      this.stack.clear();
      this.resetDuplicateGuard();
      return;
    }
    const topName = names.length === 0 ? '' : names[names.length - 1];
    if (topName === fallback) {
      return;
    }
    if (names.includes(fallback)) {
      this.stack.popToName(fallback);
      this.resetDuplicateGuard();
      return;
    }
    this.stack.clear();
    this.resetDuplicateGuard();
  }

  private resetDuplicateGuard(): void {
    this.lastRouteName = '';
    this.lastParamSignature = '';
  }
}
