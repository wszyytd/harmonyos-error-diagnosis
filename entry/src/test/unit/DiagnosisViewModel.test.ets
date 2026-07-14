import { describe, expect, it } from '@ohos/hypium';
import { DIAGNOSIS_INPUT_MAX_CHARACTERS } from '../../main/ets/constants/AppLimits';
import { DIAGNOSIS_EXAMPLE_TEXT } from '../../main/ets/constants/DiagnosisExamples';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { InputValidationService } from '../../main/ets/domain/validation/InputValidationService';
import { LocalDiagnosisService } from '../../main/ets/domain/diagnosis/DiagnosisService';
import { RuleMatcher } from '../../main/ets/domain/diagnosis/RuleMatcher';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import { OperationStatus } from '../../main/ets/model/ResultModels';
import { RouteName } from '../../main/ets/router/RouteNames';
import { ReportRouteParams } from '../../main/ets/router/RouteModels';
import { AppRouter } from '../../main/ets/router/AppRouter';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { DiagnosisSessionStore } from '../../main/ets/store/DiagnosisSessionStore';
import {
  DiagnosisFlowDependencies,
  DiagnosisViewModel
} from '../../main/ets/viewmodel/diagnosis/DiagnosisViewModel';
import { CapturingLogSink } from '../fakes/CapturingLogSink';
import { FakeTimeProvider, SequenceIdGenerator } from '../fakes/DiagnosisSessionFakes';
import { FakeNavigationStack } from '../fakes/FakeNavigationStack';
import { SuccessfulStaticContentRepository } from '../fakes/DiagnosisFlowFakes';
import { createDiagnosisRulesFixture } from '../fixtures/DiagnosisEngineFixtures';

interface DiagnosisViewModelFixture {
  store: DiagnosisSessionStore;
  viewModel: DiagnosisViewModel;
}

function createFixture(ids: Array<string> = ['session-1', 'session-2']): DiagnosisViewModelFixture {
  const logger = new HiLogService(new CapturingLogSink());
  const store = new DiagnosisSessionStore(new SequenceIdGenerator(ids), new FakeTimeProvider(1000));
  return {
    store: store,
    viewModel: new DiagnosisViewModel(
      store,
      new InputValidationService(logger),
      { sourceType: SourceType.TEXT, origin: RouteName.HOME }
    )
  };
}

export default function diagnosisViewModelTest() {
  describe('DiagnosisViewModel', () => {
    it('diagnoses valid text into the current memory session and navigates with sessionId only', 0, async () => {
      const fixture = createFixture();
      const stack = new FakeNavigationStack();
      const logger = new HiLogService(new CapturingLogSink());
      const dependencies: DiagnosisFlowDependencies = {
        staticContentRepository: new SuccessfulStaticContentRepository(createDiagnosisRulesFixture()),
        diagnosisService: new LocalDiagnosisService(
          new RuleMatcher(),
          new SequenceIdGenerator(['report-t17']),
          new FakeTimeProvider(2000),
          logger
        ),
        router: new AppRouter(stack),
        logger: logger
      };
      const viewModel = new DiagnosisViewModel(
        fixture.store,
        new InputValidationService(logger),
        { sourceType: SourceType.TEXT, origin: RouteName.HOME },
        dependencies
      );
      viewModel.updateText('ArkTS:ERROR arkts-no-type-query');

      expect(await viewModel.diagnose()).assertTrue();

      expect(viewModel.diagnosisOperation.status).assertEqual(OperationStatus.SUCCESS);
      expect(viewModel.session.pendingReport?.errorType).assertEqual('ArkTS编译错误');
      expect((viewModel.session.pendingReport?.evidence ?? []).length > 0).assertTrue();
      expect((viewModel.session.pendingReport?.possibleCauses ?? []).length > 0).assertTrue();
      expect((viewModel.session.pendingReport?.steps ?? []).length > 0).assertTrue();
      expect(stack.paths.length).assertEqual(1);
      expect(stack.paths[0].name).assertEqual(RouteName.REPORT);
      const params = stack.paths[0].param as ReportRouteParams;
      expect(params.sessionId).assertEqual('session-2');
      expect(params.origin).assertEqual(RouteName.DIAGNOSIS);
      expect(params.reportId).assertUndefined();
      expect(JSON.stringify(stack.paths[0].param).includes('ArkTS')).assertFalse();
    });

    it('creates a new TEXT session from route parameters', 0, () => {
      const fixture = createFixture();

      expect(fixture.viewModel.session.sessionId).assertEqual('session-1');
      expect(fixture.viewModel.session.sourceType).assertEqual(SourceType.TEXT);
    });

    it('creates a new IMAGE session and keeps its URI only in memory', 0, () => {
      const logger = new HiLogService(new CapturingLogSink());
      const store = new DiagnosisSessionStore(
        new SequenceIdGenerator(['image-session']),
        new FakeTimeProvider(1000)
      );
      const viewModel = new DiagnosisViewModel(
        store,
        new InputValidationService(logger),
        { sourceType: SourceType.IMAGE, origin: RouteName.HOME }
      );

      expect(viewModel.updateImageUri('photo://synthetic/in-memory')).assertTrue();
      expect(viewModel.session.imageUri).assertEqual('photo://synthetic/in-memory');
      expect(JSON.stringify(viewModel.session).includes('photo://synthetic/in-memory')).assertTrue();
    });

    it('restores only a matching current session and ignores the route source', 0, () => {
      const logger = new HiLogService(new CapturingLogSink());
      const store = new DiagnosisSessionStore(
        new SequenceIdGenerator(['existing', 'new']),
        new FakeTimeProvider(1000)
      );
      store.startNewSession(SourceType.IMAGE);
      store.updateRawText('retained text');

      const viewModel = new DiagnosisViewModel(
        store,
        new InputValidationService(logger),
        { sourceType: SourceType.TEXT, sessionId: 'existing', origin: RouteName.REPORT }
      );

      expect(viewModel.session.sessionId).assertEqual('existing');
      expect(viewModel.session.sourceType).assertEqual(SourceType.IMAGE);
      expect(viewModel.rawText).assertEqual('retained text');
    });

    it('creates a safe new session for missing or invalid session identifiers', 0, () => {
      const fixture = createFixture(['first', 'replacement']);
      const logger = new HiLogService(new CapturingLogSink());
      fixture.store.updateRawText('old');

      const replacement = new DiagnosisViewModel(
        fixture.store,
        new InputValidationService(logger),
        { sourceType: SourceType.TEXT, sessionId: 'missing', origin: RouteName.REPORT }
      );

      expect(replacement.session.sessionId).assertEqual('replacement');
      expect(replacement.rawText).assertEqual('');
    });

    it('safely falls back to TEXT for an illegal route source', 0, () => {
      const logger = new HiLogService(new CapturingLogSink());
      const store = new DiagnosisSessionStore(
        new SequenceIdGenerator(['fallback']),
        new FakeTimeProvider(1000)
      );

      const viewModel = new DiagnosisViewModel(
        store,
        new InputValidationService(logger),
        { sourceType: 'INVALID' as SourceType, origin: RouteName.HOME }
      );

      expect(viewModel.session.sourceType).assertEqual(SourceType.TEXT);
    });

    it('updates raw text and exposes raw UTF-16 count and remaining capacity', 0, () => {
      const fixture = createFixture();

      fixture.viewModel.updateText('中😀');

      expect(fixture.viewModel.rawText).assertEqual('中😀');
      expect(fixture.viewModel.characterCount).assertEqual(3);
      expect(fixture.viewModel.remainingCharacters).assertEqual(DIAGNOSIS_INPUT_MAX_CHARACTERS - 3);
    });

    it('uses the centralized safe example and remains editable without diagnosing or persisting', 0, () => {
      const fixture = createFixture();

      expect(fixture.viewModel.useExample()).assertTrue();
      expect(fixture.viewModel.rawText).assertEqual(DIAGNOSIS_EXAMPLE_TEXT);
      expect(fixture.viewModel.session.usedExample).assertTrue();
      expect(fixture.viewModel.session.pendingReport === undefined).assertTrue();
      fixture.viewModel.updateText(`${DIAGNOSIS_EXAMPLE_TEXT}\nEdited`);

      expect(fixture.viewModel.rawText.endsWith('Edited')).assertTrue();
      expect(fixture.viewModel.session.usedExample).assertTrue();
      expect(fixture.viewModel.session.pendingReport === undefined).assertTrue();
    });

    it('clears input without changing session source or image URI', 0, () => {
      const fixture = createFixture();
      const id = fixture.viewModel.session.sessionId;
      fixture.viewModel.updateText('error');
      fixture.viewModel.updateImageUri('photo://synthetic/retained');

      fixture.viewModel.clearInput();

      expect(fixture.viewModel.session.sessionId).assertEqual(id);
      expect(fixture.viewModel.session.sourceType).assertEqual(SourceType.TEXT);
      expect(fixture.viewModel.session.imageUri).assertEqual('photo://synthetic/retained');
      expect(fixture.viewModel.rawText).assertEqual('');
    });

    it('returns normalized DiagnosisInput while retaining the edited raw text', 0, () => {
      const fixture = createFixture();
      fixture.viewModel.updateText('  error  one\n  detail \n');

      const result = fixture.viewModel.validateCurrentInput();

      expect(result.success).assertTrue();
      expect(result.data?.rawText).assertEqual('error  one\n  detail');
      expect(fixture.viewModel.rawText).assertEqual('  error  one\n  detail \n');
      expect(fixture.viewModel.session.normalizedText).assertEqual('error  one\n  detail');
    });

    it('validation failure retains raw input session source and image URI', 0, () => {
      const fixture = createFixture();
      const id = fixture.viewModel.session.sessionId;
      fixture.viewModel.updateText('\t\n');
      fixture.viewModel.updateImageUri('photo://synthetic/retained');

      const result = fixture.viewModel.validateCurrentInput();

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_EMPTY);
      expect(fixture.viewModel.rawText).assertEqual('\t\n');
      expect(fixture.viewModel.session.sessionId).assertEqual(id);
      expect(fixture.viewModel.session.sourceType).assertEqual(SourceType.TEXT);
      expect(fixture.viewModel.session.imageUri).assertEqual('photo://synthetic/retained');
      expect(fixture.viewModel.inputError?.message).assertEqual('请输入错误信息。');
    });

    it('an overlong validation failure retains all 100001 edited characters and the session id', 0, () => {
      const fixture = createFixture();
      const id = fixture.viewModel.session.sessionId;
      const overlong = '界'.repeat(DIAGNOSIS_INPUT_MAX_CHARACTERS + 1);
      fixture.viewModel.updateText(overlong);

      const result = fixture.viewModel.validateCurrentInput();

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_TOO_LONG);
      expect(fixture.viewModel.rawText.length).assertEqual(100001);
      expect(fixture.viewModel.rawText).assertEqual(overlong);
      expect(fixture.viewModel.session.sessionId).assertEqual(id);
      expect(fixture.viewModel.remainingCharacters).assertEqual(0);
    });

    it('starts a new session and clears all previous transient state', 0, () => {
      const fixture = createFixture();
      fixture.viewModel.updateText('old');
      fixture.viewModel.updateImageUri('photo://synthetic/old');
      fixture.viewModel.useExample();

      expect(fixture.viewModel.startNewSession(SourceType.IMAGE)).assertTrue();

      expect(fixture.viewModel.session.sessionId).assertEqual('session-2');
      expect(fixture.viewModel.session.sourceType).assertEqual(SourceType.IMAGE);
      expect(fixture.viewModel.rawText).assertEqual('');
      expect(fixture.viewModel.session.imageUri === undefined).assertTrue();
      expect(fixture.viewModel.session.usedExample).assertFalse();
    });

    it('a disposed or stale ViewModel cannot update shared session state', 0, () => {
      const fixture = createFixture(['first', 'second']);
      const firstViewModel = fixture.viewModel;
      const logger = new HiLogService(new CapturingLogSink());
      const secondViewModel = new DiagnosisViewModel(
        fixture.store,
        new InputValidationService(logger),
        { sourceType: SourceType.TEXT, origin: RouteName.HOME }
      );
      firstViewModel.dispose();

      expect(firstViewModel.updateText('STALE')).assertFalse();
      expect(firstViewModel.startNewSession(SourceType.IMAGE)).assertFalse();
      expect(secondViewModel.rawText).assertEqual('');
      expect(fixture.store.currentSession?.sessionId).assertEqual('second');
    });
  });
}
