import { describe, expect, it } from '@ohos/hypium';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import { RouteName } from '../../main/ets/router/RouteNames';
import {
  DiagnosisRouteParams,
  PrivacyRouteParams,
  ReportRouteParams,
  RouteDecision,
  ToolType,
  ToolsRouteParams
} from '../../main/ets/router/RouteModels';
import {
  getRouteDefinitions,
  resolveRouteRequest
} from '../../main/ets/router/RouteRegistry';

interface UnsafeRouteParams {
  origin?: string;
  sourceType?: string;
  sessionId?: string;
  reportId?: string;
  rawText?: string;
  report?: object;
  imageData?: string;
}

interface UnsafeReportObject {
  id: string;
}

interface WrongTypeRouteParams {
  origin: string;
  reportId: number;
}

function requireAccepted(decision: RouteDecision): void {
  expect(decision.result.success).assertTrue();
  expect(decision.result.data === undefined).assertFalse();
}

function requireRejected(decision: RouteDecision, fallback: RouteName): void {
  expect(decision.result.success).assertFalse();
  expect(decision.result.error === undefined).assertFalse();
  expect(decision.result.error?.code).assertEqual('ROUTE_PARAM_INVALID');
  expect(decision.fallback).assertEqual(fallback);
}

export default function routeRegistryTest() {
  describe('RouteRegistry', () => {
    it('registers six unique route names with documented page paths', 0, () => {
      const definitions = getRouteDefinitions();
      const names = definitions.map((definition) => definition.name);

      expect(definitions.length).assertEqual(6);
      expect(new Set<RouteName>(names).size).assertEqual(6);
      expect(definitions[0].name).assertEqual(RouteName.HOME);
      expect(definitions[0].path).assertEqual('pages/home/HomePage');
      expect(definitions[1].path).assertEqual('pages/diagnosis/DiagnosisPage');
      expect(definitions[2].path).assertEqual('pages/report/ReportPage');
      expect(definitions[3].path).assertEqual('pages/tools/ToolsPage');
      expect(definitions[4].path).assertEqual('pages/history/HistorySettingsPage');
      expect(definitions[5].path).assertEqual('pages/settings/PrivacyPage');
    });

    it('accepts IMAGE and TEXT diagnosis sources and optional session id', 0, () => {
      const imageRouteParams: DiagnosisRouteParams = {
        sourceType: SourceType.IMAGE,
        origin: RouteName.HOME
      };
      const textRouteParams: DiagnosisRouteParams = {
        sourceType: SourceType.TEXT,
        sessionId: 'session-1',
        origin: RouteName.HISTORY_SETTINGS
      };
      const imageDecision = resolveRouteRequest(RouteName.DIAGNOSIS, imageRouteParams);
      const textDecision = resolveRouteRequest(RouteName.DIAGNOSIS, textRouteParams);

      requireAccepted(imageDecision);
      requireAccepted(textDecision);
      const imageParams = imageDecision.result.data?.params as DiagnosisRouteParams;
      const textParams = textDecision.result.data?.params as DiagnosisRouteParams;
      expect(imageParams.sourceType).assertEqual(SourceType.IMAGE);
      expect(textParams.sourceType).assertEqual(SourceType.TEXT);
      expect(textParams.sessionId).assertEqual('session-1');
    });

    it('rejects an invalid diagnosis source or origin without entering the page', 0, () => {
      const invalidSource: UnsafeRouteParams = {
        sourceType: 'CAMERA',
        origin: RouteName.HOME
      };
      const invalidOrigin: UnsafeRouteParams = {
        sourceType: SourceType.TEXT,
        origin: RouteName.PRIVACY
      };

      requireRejected(resolveRouteRequest(RouteName.DIAGNOSIS, invalidSource), RouteName.HOME);
      requireRejected(resolveRouteRequest(RouteName.DIAGNOSIS, invalidOrigin), RouteName.HOME);
    });

    it('accepts report navigation with only a session id', 0, () => {
      const routeParams: ReportRouteParams = {
        sessionId: 'session-1',
        origin: RouteName.DIAGNOSIS
      };
      const decision = resolveRouteRequest(RouteName.REPORT, routeParams);

      requireAccepted(decision);
      const params = decision.result.data?.params as ReportRouteParams;
      expect(params.sessionId).assertEqual('session-1');
      expect(params.reportId === undefined).assertTrue();
    });

    it('accepts report navigation with only a report id', 0, () => {
      const routeParams: ReportRouteParams = {
        reportId: 'report-1',
        origin: RouteName.HISTORY_SETTINGS
      };
      const decision = resolveRouteRequest(RouteName.REPORT, routeParams);

      requireAccepted(decision);
      const params = decision.result.data?.params as ReportRouteParams;
      expect(params.reportId).assertEqual('report-1');
      expect(params.sessionId === undefined).assertTrue();
    });

    it('rejects report navigation when both identifiers are present', 0, () => {
      const routeParams: ReportRouteParams = {
        sessionId: 'session-1',
        reportId: 'report-1',
        origin: RouteName.DIAGNOSIS
      };
      requireRejected(resolveRouteRequest(RouteName.REPORT, routeParams), RouteName.DIAGNOSIS);
    });

    it('rejects report navigation when both identifiers are absent', 0, () => {
      const routeParams: ReportRouteParams = {
        origin: RouteName.HOME
      };
      requireRejected(resolveRouteRequest(RouteName.REPORT, routeParams), RouteName.HOME);
    });

    it('rejects blank route identifiers', 0, () => {
      const reportParams: ReportRouteParams = {
        reportId: '   ',
        origin: RouteName.HISTORY_SETTINGS
      };
      const diagnosisParams: DiagnosisRouteParams = {
        sourceType: SourceType.TEXT,
        sessionId: '',
        origin: RouteName.HOME
      };
      requireRejected(resolveRouteRequest(RouteName.REPORT, reportParams), RouteName.HISTORY_SETTINGS);
      requireRejected(resolveRouteRequest(RouteName.DIAGNOSIS, diagnosisParams), RouteName.HOME);
    });

    it('rejects route identifiers with a non-string runtime type', 0, () => {
      const wrongTypeParams: WrongTypeRouteParams = {
        reportId: 1001,
        origin: RouteName.HISTORY_SETTINGS
      };
      requireRejected(resolveRouteRequest(RouteName.REPORT, wrongTypeParams), RouteName.HISTORY_SETTINGS);
    });

    it('accepts lightweight tools parameters and sanitizes them', 0, () => {
      const routeParams: ToolsRouteParams = {
        toolType: ToolType.JSON,
        reportId: 'report-1',
        origin: RouteName.REPORT
      };
      const decision = resolveRouteRequest(RouteName.TOOLS, routeParams);

      requireAccepted(decision);
      const params = decision.result.data?.params as ToolsRouteParams;
      expect(params.toolType).assertEqual(ToolType.JSON);
      expect(params.reportId).assertEqual('report-1');
    });

    it('rejects logs reports and image data in route parameters', 0, () => {
      const logParams: UnsafeRouteParams = {
        origin: RouteName.HOME,
        rawText: 'ArkTS compiler output'
      };
      const unsafeReport: UnsafeReportObject = {
        id: 'report-1'
      };
      const reportParams: UnsafeRouteParams = {
        origin: RouteName.HOME,
        report: unsafeReport
      };
      const imageParams: UnsafeRouteParams = {
        origin: RouteName.HOME,
        imageData: 'base64-data'
      };

      requireRejected(resolveRouteRequest(RouteName.TOOLS, logParams), RouteName.HOME);
      requireRejected(resolveRouteRequest(RouteName.HISTORY_SETTINGS, reportParams), RouteName.HOME);
      requireRejected(resolveRouteRequest(RouteName.DIAGNOSIS, imageParams), RouteName.HOME);
    });

    it('accepts privacy only from history and settings', 0, () => {
      const validParams: PrivacyRouteParams = {
        origin: RouteName.HISTORY_SETTINGS
      };
      const invalidParams: PrivacyRouteParams = {
        origin: RouteName.HOME
      };
      requireAccepted(resolveRouteRequest(RouteName.PRIVACY, validParams));
      requireRejected(resolveRouteRequest(RouteName.PRIVACY, invalidParams), RouteName.HOME);
    });

    it('resolves unknown route names to a safe home fallback', 0, () => {
      requireRejected(resolveRouteRequest('unknown-route'), RouteName.HOME);
    });
  });
}
