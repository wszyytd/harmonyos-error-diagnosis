import { describe, expect, it } from '@ohos/hypium';
import { DIAGNOSIS_INPUT_MAX_CHARACTERS } from '../../main/ets/constants/AppLimits';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import {
  DiagnosisService,
  LocalDiagnosisService
} from '../../main/ets/domain/diagnosis/DiagnosisService';
import { RuleMatcher } from '../../main/ets/domain/diagnosis/RuleMatcher';
import { InputValidationService } from '../../main/ets/domain/validation/InputValidationService';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import { OperationStatus } from '../../main/ets/model/ResultModels';
import { AppRouter } from '../../main/ets/router/AppRouter';
import { RouteName } from '../../main/ets/router/RouteNames';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { DiagnosisSessionStore } from '../../main/ets/store/DiagnosisSessionStore';
import {
  DiagnosisFlowDependencies,
  DiagnosisViewModel
} from '../../main/ets/viewmodel/diagnosis/DiagnosisViewModel';
import { CapturingLogSink } from '../fakes/CapturingLogSink';
import {
  ControlledStaticContentRepository,
  FailingDiagnosisService,
  FailingStaticContentRepository,
  SuccessfulStaticContentRepository
} from '../fakes/DiagnosisFlowFakes';
import { FakeTimeProvider, SequenceIdGenerator } from '../fakes/DiagnosisSessionFakes';
import { FakeNavigationStack } from '../fakes/FakeNavigationStack';
import { createDiagnosisRulesFixture } from '../fixtures/DiagnosisEngineFixtures';
import { createReportFixture } from '../fixtures/ReportFixtures';

interface FlowFixture {
  store: DiagnosisSessionStore;
  viewModel: DiagnosisViewModel;
  stack: FakeNavigationStack;
  loggerSink: CapturingLogSink;
}

function createFlowFixture(
  repository: SuccessfulStaticContentRepository | FailingStaticContentRepository |
    ControlledStaticContentRepository = new SuccessfulStaticContentRepository(createDiagnosisRulesFixture()),
  diagnosisService: DiagnosisService = new LocalDiagnosisService(
    new RuleMatcher(),
    new SequenceIdGenerator(['report-t17']),
    new FakeTimeProvider(2000),
    new HiLogService(new CapturingLogSink())
  )
): FlowFixture {
  const loggerSink = new CapturingLogSink();
  const logger = new HiLogService(loggerSink);
  const store = new DiagnosisSessionStore(
    new SequenceIdGenerator(['session-t17', 'session-next']),
    new FakeTimeProvider(1000)
  );
  const stack = new FakeNavigationStack();
  const dependencies: DiagnosisFlowDependencies = {
    staticContentRepository: repository,
    diagnosisService: diagnosisService,
    router: new AppRouter(stack),
    logger: logger
  };
  return {
    store: store,
    viewModel: new DiagnosisViewModel(
      store,
      new InputValidationService(logger),
      { sourceType: SourceType.TEXT, origin: RouteName.HOME },
      dependencies
    ),
    stack: stack,
    loggerSink: loggerSink
  };
}

export default function diagnosisFlowTest() {
  describe('DiagnosisFlow', () => {
    it('does not load rules for empty or whitespace-only input', 0, async () => {
      const repository = new SuccessfulStaticContentRepository(createDiagnosisRulesFixture());
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('\t\n  ');

      expect(await fixture.viewModel.diagnose()).assertFalse();

      expect(repository.loadRulesCount).assertEqual(0);
      expect(fixture.viewModel.diagnosisOperation.status).assertEqual(OperationStatus.ERROR);
      expect(fixture.viewModel.diagnosisError?.code).assertEqual(ErrorCode.VAL_INPUT_EMPTY);
      expect(fixture.viewModel.rawText).assertEqual('\t\n  ');
      expect(fixture.stack.paths.length).assertEqual(0);
    });

    it('does not load rules for overlong input', 0, async () => {
      const repository = new SuccessfulStaticContentRepository(createDiagnosisRulesFixture());
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('x'.repeat(DIAGNOSIS_INPUT_MAX_CHARACTERS + 1));

      expect(await fixture.viewModel.diagnose()).assertFalse();

      expect(repository.loadRulesCount).assertEqual(0);
      expect(fixture.viewModel.diagnosisError?.code).assertEqual(ErrorCode.VAL_INPUT_TOO_LONG);
      expect(fixture.viewModel.rawText.length).assertEqual(100001);
    });

    it('keeps input and ends loading when bundled rules fail', 0, async () => {
      const repository = new FailingStaticContentRepository();
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('synthetic failure');

      expect(await fixture.viewModel.diagnose()).assertFalse();

      expect(fixture.viewModel.rawText).assertEqual('synthetic failure');
      expect(fixture.viewModel.diagnosisOperation.status).assertEqual(OperationStatus.ERROR);
      expect(fixture.viewModel.diagnosisError?.code).assertEqual(ErrorCode.RULE_RESOURCE_FAILED);
      expect(fixture.stack.paths.length).assertEqual(0);
    });

    it('keeps input and the last valid report when the engine fails', 0, async () => {
      const fixture = createFlowFixture(
        new SuccessfulStaticContentRepository(createDiagnosisRulesFixture()),
        new FailingDiagnosisService()
      );
      fixture.store.setPendingReport(createReportFixture('last-valid', 1, 2));
      fixture.viewModel.updateText('synthetic engine failure');

      expect(await fixture.viewModel.diagnose()).assertFalse();

      expect(fixture.viewModel.rawText).assertEqual('synthetic engine failure');
      expect(fixture.viewModel.session.pendingReport?.id).assertEqual('last-valid');
      expect(fixture.viewModel.diagnosisError?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('rejects a duplicate click while rule loading is in progress', 0, async () => {
      const repository = new ControlledStaticContentRepository();
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('ArkTS:ERROR arkts-no-type-query');

      const first = fixture.viewModel.diagnose();
      const second = await fixture.viewModel.diagnose();

      expect(second).assertFalse();
      expect(repository.loadRulesCount).assertEqual(1);
      repository.succeed(createDiagnosisRulesFixture());
      expect(await first).assertTrue();
      expect(fixture.stack.paths.length).assertEqual(1);
    });

    it('ignores an old asynchronous result after a new session starts', 0, async () => {
      const repository = new ControlledStaticContentRepository();
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('old ArkTS:ERROR');
      const pending = fixture.viewModel.diagnose();

      fixture.viewModel.startNewSession(SourceType.TEXT);
      repository.succeed(createDiagnosisRulesFixture());

      expect(await pending).assertFalse();
      expect(fixture.viewModel.session.sessionId).assertEqual('session-next');
      expect(fixture.viewModel.session.pendingReport).assertUndefined();
      expect(fixture.stack.paths.length).assertEqual(0);
    });

    it('ignores asynchronous completion after disposal', 0, async () => {
      const repository = new ControlledStaticContentRepository();
      const fixture = createFlowFixture(repository);
      fixture.viewModel.updateText('old ArkTS:ERROR');
      const pending = fixture.viewModel.diagnose();

      fixture.viewModel.dispose();
      repository.succeed(createDiagnosisRulesFixture());

      expect(await pending).assertFalse();
      expect(fixture.store.currentSession?.pendingReport).assertUndefined();
      expect(fixture.stack.paths.length).assertEqual(0);
      expect(fixture.viewModel.diagnosisOperation.status).assertEqual(OperationStatus.CANCELLED);
    });

    it('does not log the original text report content or image URI', 0, async () => {
      const fixture = createFlowFixture();
      const sensitive = 'ArkTS:ERROR D:\\Synthetic\\private token=SYNTHETIC_SECRET';
      fixture.viewModel.updateText(sensitive);
      fixture.viewModel.updateImageUri('photo://synthetic/private');

      await fixture.viewModel.diagnose();
      const logs = JSON.stringify(fixture.loggerSink.records);

      expect(logs.includes(sensitive)).assertFalse();
      expect(logs.includes('SYNTHETIC_SECRET')).assertFalse();
      expect(logs.includes('photo://')).assertFalse();
      expect(logs.includes('ArkTS编译错误')).assertFalse();
    });
  });
}
