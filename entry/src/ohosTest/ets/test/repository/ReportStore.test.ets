import { common, Want } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium';
import { DIAGNOSIS_REPORT_TABLE } from '../../../../main/ets/constants/DatabaseConstants';
import { ErrorCode } from '../../../../main/ets/constants/ErrorCodes';
import { DiagnosisReport, SourceType } from '../../../../main/ets/model/DiagnosisModels';
import { HiLogService } from '../../../../main/ets/service/platform/HiLogService';
import {
  DatabaseManager,
  HarmonyDatabaseStoreProvider
} from '../../../../main/ets/storage/database/DatabaseManager';
import { ReportStore } from '../../../../main/ets/storage/database/ReportStore';
import { CapturingLogSink } from '../../../../test/fakes/CapturingLogSink';
import {
  FakeReportDatabaseStore,
  ReportDatabaseFailureStage
} from '../../../../test/fakes/FakeReportDatabaseStore';

const TEST_DATABASE_NAME: string = 'error_diagnosis_t9_test.db';
const TEST_ABILITY_WANT: Want = {
  bundleName: 'com.example.errordiagnosis',
  abilityName: 'EntryAbility'
};

let appContext: common.Context;
let activeManager: DatabaseManager | undefined = undefined;

function report(id: string, savedAt: number): DiagnosisReport {
  return {
    id: id,
    errorType: 'ArkTSTypeMismatch',
    secondaryTags: ['ArkTS', 'synthetic'],
    summary: 'Synthetic report summary',
    evidence: ['Synthetic evidence'],
    possibleCauses: ['Synthetic cause'],
    steps: ['Synthetic step'],
    suggestions: ['Synthetic suggestion'],
    riskNotice: 'Synthetic risk notice',
    rawText: 'Synthetic compiler error text',
    sourceType: SourceType.TEXT,
    createdAt: 1700000000000,
    savedAt: savedAt,
    isFavorite: false,
    engineVersion: 'synthetic-rules-1'
  };
}

async function deleteTestDatabase(): Promise<void> {
  try {
    await relationalStore.deleteRdbStore(appContext, TEST_DATABASE_NAME);
  } catch (_) {
  }
}

function createManager(): DatabaseManager {
  return new DatabaseManager(
    new HarmonyDatabaseStoreProvider(appContext),
    new HiLogService(new CapturingLogSink()),
    TEST_DATABASE_NAME
  );
}

async function createStore(): Promise<ReportStore> {
  activeManager = createManager();
  const initialized = await activeManager.initialize();
  expect(initialized.success).assertTrue();
  return new ReportStore(initialized.data, new HiLogService(new CapturingLogSink()));
}

export default function reportStoreInstrumentTest() {
  describe('ReportStoreInstrument', () => {
    beforeEach(async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility(TEST_ABILITY_WANT);
      appContext = (await delegator.getCurrentTopAbility()).context;
      activeManager = undefined;
      await deleteTestDatabase();
    });

    afterEach(async (): Promise<void> => {
      if (activeManager !== undefined) {
        await activeManager.close();
        activeManager = undefined;
      }
      await deleteTestDatabase();
    });

    it('inserts and reads every report field by id', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      const expected = report('synthetic-t9-full', 1700000001000);

      expect((await reportStore.insert(expected)).success).assertTrue();
      const restored = await reportStore.getById(expected.id);

      expect(restored.success).assertTrue();
      expect(restored.data?.id).assertEqual(expected.id);
      expect(restored.data?.errorType).assertEqual(expected.errorType);
      expect(JSON.stringify(restored.data?.secondaryTags)).assertEqual(JSON.stringify(expected.secondaryTags));
      expect(restored.data?.summary).assertEqual(expected.summary);
      expect(JSON.stringify(restored.data?.evidence)).assertEqual(JSON.stringify(expected.evidence));
      expect(JSON.stringify(restored.data?.possibleCauses)).assertEqual(JSON.stringify(expected.possibleCauses));
      expect(JSON.stringify(restored.data?.steps)).assertEqual(JSON.stringify(expected.steps));
      expect(JSON.stringify(restored.data?.suggestions)).assertEqual(JSON.stringify(expected.suggestions));
      expect(restored.data?.riskNotice).assertEqual(expected.riskNotice);
      expect(restored.data?.rawText).assertEqual(expected.rawText);
      expect(restored.data?.sourceType).assertEqual(expected.sourceType);
      expect(restored.data?.createdAt).assertEqual(expected.createdAt);
      expect(restored.data?.savedAt).assertEqual(expected.savedAt);
      expect(restored.data?.isFavorite).assertEqual(expected.isFavorite);
      expect(restored.data?.engineVersion).assertEqual(expected.engineVersion);
    });

    it('lists multiple reports by saved time descending', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      await reportStore.insert(report('synthetic-old', 1700000001000));
      await reportStore.insert(report('synthetic-new', 1700000003000));
      await reportStore.insert(report('synthetic-middle', 1700000002000));

      const result = await reportStore.list(0, 10);

      expect(result.success).assertTrue();
      expect(result.data?.map((item: DiagnosisReport) => item.id).join(','))
        .assertEqual('synthetic-new,synthetic-middle,synthetic-old');
    });

    it('applies offset and limit at the database query boundary', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      await reportStore.insert(report('synthetic-one', 1700000001000));
      await reportStore.insert(report('synthetic-two', 1700000002000));
      await reportStore.insert(report('synthetic-three', 1700000003000));

      const result = await reportStore.list(1, 1);

      expect(result.data?.length).assertEqual(1);
      expect(result.data?.[0].id).assertEqual('synthetic-two');
    });

    it('deletes an existing report', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      await reportStore.insert(report('synthetic-delete', 1700000001000));

      expect((await reportStore.deleteById('synthetic-delete')).data).assertTrue();
      expect((await reportStore.getById('synthetic-delete')).error?.code)
        .assertEqual(ErrorCode.REPORT_NOT_FOUND);
    });

    it('returns false when deleting a report that does not exist', 0, async (): Promise<void> => {
      const reportStore = await createStore();

      const result = await reportStore.deleteById('synthetic-missing');

      expect(result.success).assertTrue();
      expect(result.data).assertFalse();
    });

    it('clears every report and returns the deleted count', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      await reportStore.insert(report('synthetic-clear-one', 1700000001000));
      await reportStore.insert(report('synthetic-clear-two', 1700000002000));

      expect((await reportStore.clearAll()).data).assertEqual(2);
      expect((await reportStore.list(0, 10)).data?.length).assertEqual(0);
    });

    it('persists a report after closing and reopening the database', 0, async (): Promise<void> => {
      let reportStore = await createStore();
      await reportStore.insert(report('synthetic-reopen', 1700000001000));
      await activeManager?.close();

      activeManager = createManager();
      const reopened = await activeManager.initialize();
      reportStore = new ReportStore(reopened.data, new HiLogService(new CapturingLogSink()));

      expect((await reportStore.getById('synthetic-reopen')).success).assertTrue();
    });

    it('round trips special characters Unicode and empty arrays in the real database', 0,
      async (): Promise<void> => {
        const reportStore = await createStore();
        const special = report('synthetic-special', 1700000001000);
        special.secondaryTags = [];
        special.evidence = [];
        special.possibleCauses = [];
        special.steps = [];
        special.suggestions = [];
        special.riskNotice = undefined;
        special.summary = '中文 "摘要" \\ slash\nnext 😀';
        special.rawText = 'ArkTS 中文错误\nD:\\synthetic\\path';

        await reportStore.insert(special);
        const restored = await reportStore.getById(special.id);

        expect(restored.data?.summary).assertEqual(special.summary);
        expect(restored.data?.rawText).assertEqual(special.rawText);
        expect(JSON.stringify(restored.data?.evidence)).assertEqual('[]');
        expect(restored.data?.riskNotice === undefined).assertTrue();
      });

    it('maps an artificially corrupted JSON row to DATA_PARSE_FAILED', 0, async (): Promise<void> => {
      const reportStore = await createStore();
      await reportStore.insert(report('synthetic-corrupt', 1700000001000));
      const rawStore = await relationalStore.getRdbStore(appContext, {
        name: TEST_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      });
      try {
        await rawStore.executeSql(
          `UPDATE ${DIAGNOSIS_REPORT_TABLE} SET evidence_json = ? WHERE id = ?`,
          ['["synthetic-corrupt"', 'synthetic-corrupt']
        );
      } finally {
        await rawStore.close();
      }

      const result = await reportStore.getById('synthetic-corrupt');

      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
    });

    it('maps injected write query and delete failures without platform details', 0, async (): Promise<void> => {
      const fake = new FakeReportDatabaseStore();
      const reportStore = new ReportStore(fake, new HiLogService(new CapturingLogSink()));
      fake.failureStage = ReportDatabaseFailureStage.INSERT;
      expect((await reportStore.insert(report('synthetic-failure', 1700000001000))).error?.code)
        .assertEqual(ErrorCode.STORAGE_WRITE_FAILED);
      fake.failureStage = ReportDatabaseFailureStage.QUERY;
      expect((await reportStore.list(0, 10)).error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      fake.failureStage = ReportDatabaseFailureStage.DELETE;
      expect((await reportStore.clearAll()).error?.code).assertEqual(ErrorCode.STORAGE_DELETE_FAILED);
    });

    it('closes result sets on successful and failed device-test reads', 0, async (): Promise<void> => {
      const fake = new FakeReportDatabaseStore();
      const reportStore = new ReportStore(fake, new HiLogService(new CapturingLogSink()));
      await reportStore.insert(report('synthetic-cursor', 1700000001000));
      await reportStore.list(0, 10);
      expect(fake.lastResultSet?.closed).assertTrue();

      fake.failureStage = ReportDatabaseFailureStage.RESULT_READ;
      expect((await reportStore.list(0, 10)).error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      expect(fake.lastResultSet?.closed).assertTrue();
    });
  });
}
