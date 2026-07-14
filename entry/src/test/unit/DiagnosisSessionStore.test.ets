import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { DiagnosisReport, SourceType } from '../../main/ets/model/DiagnosisModels';
import { DiagnosisSessionStore } from '../../main/ets/store/DiagnosisSessionStore';
import { SystemIdGenerator } from '../../main/ets/utils/IdGenerator';
import { FakeTimeProvider, SequenceIdGenerator } from '../fakes/DiagnosisSessionFakes';
import { createReportFixture } from '../fixtures/ReportFixtures';

function createStore(ids: Array<string> = ['session-1', 'session-2']): DiagnosisSessionStore {
  return new DiagnosisSessionStore(new SequenceIdGenerator(ids), new FakeTimeProvider(1000));
}

export default function diagnosisSessionStoreTest() {
  describe('DiagnosisSessionStore', () => {
    it('creates TEXT and IMAGE sessions with non-empty unique identifiers', 0, () => {
      const store = createStore();
      const textSession = store.startNewSession(SourceType.TEXT);
      const imageSession = store.startNewSession(SourceType.IMAGE);

      expect(textSession.sessionId.length > 0).assertTrue();
      expect(imageSession.sessionId.length > 0).assertTrue();
      expect(textSession.sessionId === imageSession.sessionId).assertFalse();
      expect(textSession.sourceType).assertEqual(SourceType.TEXT);
      expect(imageSession.sourceType).assertEqual(SourceType.IMAGE);
    });

    it('supports an injected deterministic identifier and time provider', 0, () => {
      const store = createStore(['fixed-session']);

      const state = store.startNewSession(SourceType.TEXT);

      expect(state.sessionId).assertEqual('fixed-session');
      expect(state.createdAt).assertEqual(1000);
      expect(state.updatedAt).assertEqual(1000);
    });

    it('the default generator produces distinct non-empty session identifiers', 0, () => {
      const generator = new SystemIdGenerator();

      const first = generator.nextId();
      const second = generator.nextId();

      expect(first.length > 0).assertTrue();
      expect(second.length > 0).assertTrue();
      expect(first === second).assertFalse();
    });

    it('updates raw text without normalizing the user edited value', 0, () => {
      const store = createStore();
      store.startNewSession(SourceType.TEXT);

      store.updateRawText('  error\n  detail  ');

      expect(store.currentSession?.rawText).assertEqual('  error\n  detail  ');
      expect(store.currentSession?.normalizedText).assertEqual('');
    });

    it('clears text but keeps the current session source and image URI', 0, () => {
      const store = createStore();
      const original = store.startNewSession(SourceType.IMAGE);
      store.setImageUri('photo://synthetic/current');
      store.updateRawText('error');
      store.setValidationFailure({
        code: ErrorCode.VAL_INPUT_TOO_LONG,
        message: 'safe error',
        retryable: false
      });
      store.markExampleUsed();

      store.clearInput();

      const state = store.currentSession;
      expect(state?.sessionId).assertEqual(original.sessionId);
      expect(state?.sourceType).assertEqual(SourceType.IMAGE);
      expect(state?.imageUri).assertEqual('photo://synthetic/current');
      expect(state?.rawText).assertEqual('');
      expect(state?.validationError === undefined).assertTrue();
      expect(state?.usedExample).assertFalse();
    });

    it('starting a new session clears text image error example and pending report', 0, () => {
      const store = createStore();
      store.startNewSession(SourceType.IMAGE);
      store.updateRawText('old text');
      store.setImageUri('photo://synthetic/old');
      store.markExampleUsed();
      store.setValidationFailure({ code: ErrorCode.VAL_INPUT_EMPTY, message: 'safe', retryable: false });
      store.setPendingReport(createReportFixture('pending-report', 1, 2));

      const next = store.startNewSession(SourceType.TEXT);

      expect(next.rawText).assertEqual('');
      expect(next.normalizedText).assertEqual('');
      expect(next.imageUri === undefined).assertTrue();
      expect(next.validationError === undefined).assertTrue();
      expect(next.pendingReport === undefined).assertTrue();
      expect(next.usedExample).assertFalse();
    });

    it('restores only the current real in-memory session by exact identifier', 0, () => {
      const store = createStore();
      const created = store.startNewSession(SourceType.TEXT);
      store.updateRawText('retained');

      expect(store.findCurrentSession(created.sessionId)?.rawText).assertEqual('retained');
      expect(store.findCurrentSession('missing-session') === undefined).assertTrue();
      expect(store.findCurrentSession('  ') === undefined).assertTrue();
    });

    it('safely falls back to TEXT for an illegal source value', 0, () => {
      const store = createStore();

      const state = store.startNewSession('INVALID' as SourceType);

      expect(state.sourceType).assertEqual(SourceType.TEXT);
    });

    it('returns isolated state errors and pending report arrays', 0, () => {
      const store = createStore();
      store.startNewSession(SourceType.TEXT);
      store.setValidationFailure({ code: ErrorCode.VAL_INPUT_EMPTY, message: 'safe', retryable: false });
      store.setPendingReport(createReportFixture('isolated-report', 1, 2));

      const exposed = store.currentSession;
      if (exposed !== undefined && exposed.pendingReport !== undefined && exposed.validationError !== undefined) {
        exposed.rawText = 'MUTATED';
        exposed.validationError.message = 'MUTATED';
        exposed.pendingReport.steps.push('MUTATED');
      }
      const actual = store.currentSession;

      expect(actual?.rawText).assertEqual('');
      expect(actual?.validationError?.message).assertEqual('safe');
      expect(actual?.pendingReport?.steps.includes('MUTATED')).assertFalse();
    });

    it('copies a supplied report so later caller mutation cannot enter the session', 0, () => {
      const store = createStore();
      store.startNewSession(SourceType.TEXT);
      const report: DiagnosisReport = createReportFixture('copied-report', 1, 2);
      store.setPendingReport(report);

      report.steps.push('MUTATED_AFTER_SET');

      expect(store.currentSession?.pendingReport?.steps.includes('MUTATED_AFTER_SET')).assertFalse();
    });
  });
}
