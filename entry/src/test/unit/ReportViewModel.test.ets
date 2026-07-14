import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import { OperationStatus } from '../../main/ets/model/ResultModels';
import { AppRouter } from '../../main/ets/router/AppRouter';
import { RouteName } from '../../main/ets/router/RouteNames';
import { DiagnosisSessionStore } from '../../main/ets/store/DiagnosisSessionStore';
import { ReportViewModel } from '../../main/ets/viewmodel/report/ReportViewModel';
import { FakeTimeProvider, SequenceIdGenerator } from '../fakes/DiagnosisSessionFakes';
import { FakeNavigationStack } from '../fakes/FakeNavigationStack';
import { createReportFixture } from '../fixtures/ReportFixtures';

function createStore(withReport: boolean = true): DiagnosisSessionStore {
  const store = new DiagnosisSessionStore(
    new SequenceIdGenerator(['session-report']),
    new FakeTimeProvider(1000)
  );
  store.startNewSession(SourceType.TEXT);
  store.updateRawText('original editable text');
  if (withReport) {
    store.setPendingReport(createReportFixture('pending-report', 1));
  }
  return store;
}

export default function reportViewModelTest() {
  describe('ReportViewModel', () => {
    it('loads an unsaved report from the exact current memory session', 0, () => {
      const store = createStore();
      const viewModel = new ReportViewModel(
        store,
        new AppRouter(new FakeNavigationStack()),
        { sessionId: 'session-report', origin: RouteName.DIAGNOSIS }
      );

      expect(viewModel.reportOperation.status).assertEqual(OperationStatus.SUCCESS);
      expect(viewModel.report?.id).assertEqual('pending-report');
      expect(viewModel.report?.savedAt).assertUndefined();
    });

    it('fails safely for a missing session or a session without a report', 0, () => {
      const missingSession = new ReportViewModel(
        createStore(),
        new AppRouter(new FakeNavigationStack()),
        { sessionId: 'missing', origin: RouteName.DIAGNOSIS }
      );
      const noReport = new ReportViewModel(
        createStore(false),
        new AppRouter(new FakeNavigationStack()),
        { sessionId: 'session-report', origin: RouteName.DIAGNOSIS }
      );

      expect(missingSession.reportOperation.status).assertEqual(OperationStatus.ERROR);
      expect(missingSession.reportError?.code).assertEqual(ErrorCode.ROUTE_PARAM_INVALID);
      expect(noReport.reportOperation.status).assertEqual(OperationStatus.ERROR);
      expect(noReport.reportError?.code).assertEqual(ErrorCode.REPORT_NOT_FOUND);
    });

    it('does not fabricate or query a reportId before T18', 0, () => {
      const viewModel = new ReportViewModel(
        createStore(),
        new AppRouter(new FakeNavigationStack()),
        { reportId: 'history-report', origin: RouteName.HOME }
      );

      expect(viewModel.report).assertUndefined();
      expect(viewModel.reportOperation.status).assertEqual(OperationStatus.ERROR);
      expect(viewModel.reportError?.code).assertEqual(ErrorCode.REPORT_NOT_FOUND);
      expect(viewModel.reportError?.message.includes('历史报告')).assertTrue();
    });

    it('returns isolated report arrays', 0, () => {
      const store = createStore();
      const viewModel = new ReportViewModel(
        store,
        new AppRouter(new FakeNavigationStack()),
        { sessionId: 'session-report', origin: RouteName.DIAGNOSIS }
      );
      viewModel.report?.steps.push('MUTATED');

      expect(viewModel.report?.steps.includes('MUTATED')).assertFalse();
      expect(store.currentSession?.pendingReport?.steps.includes('MUTATED')).assertFalse();
    });

    it('returns to edit without changing raw text source or session identity', 0, () => {
      const store = createStore();
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);
      router.openDiagnosis({ sourceType: SourceType.TEXT, origin: RouteName.HOME });
      router.openReport({ sessionId: 'session-report', origin: RouteName.DIAGNOSIS });
      const viewModel = new ReportViewModel(
        store,
        router,
        { sessionId: 'session-report', origin: RouteName.DIAGNOSIS }
      );

      expect(viewModel.editInput()).assertTrue();

      expect(stack.paths.length).assertEqual(1);
      expect(store.currentSession?.sessionId).assertEqual('session-report');
      expect(store.currentSession?.sourceType).assertEqual(SourceType.TEXT);
      expect(store.currentSession?.rawText).assertEqual('original editable text');
    });

    it('re-diagnose returns to the same editable session', 0, () => {
      const store = createStore();
      const stack = new FakeNavigationStack();
      stack.paths.push({ name: RouteName.DIAGNOSIS });
      stack.paths.push({ name: RouteName.REPORT });
      const viewModel = new ReportViewModel(
        store,
        new AppRouter(stack),
        { sessionId: 'session-report', origin: RouteName.DIAGNOSIS }
      );

      expect(viewModel.rediagnose()).assertTrue();
      expect(stack.paths.length).assertEqual(1);
      expect(store.currentSession?.sessionId).assertEqual('session-report');
    });
  });
}
