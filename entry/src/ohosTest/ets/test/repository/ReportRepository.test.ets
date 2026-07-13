import { common, Want } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium';
import { HISTORY_RECORD_LIMIT } from '../../../../main/ets/constants/AppLimits';
import { DiagnosisReport } from '../../../../main/ets/model/DiagnosisModels';
import { LocalReportRepository } from '../../../../main/ets/repository/report/LocalReportRepository';
import { TimeSource } from '../../../../main/ets/repository/report/ReportRepository';
import { HiLogService } from '../../../../main/ets/service/platform/HiLogService';
import {
  DatabaseManager,
  HarmonyDatabaseStoreProvider
} from '../../../../main/ets/storage/database/DatabaseManager';
import { ReportStore } from '../../../../main/ets/storage/database/ReportStore';
import { CapturingLogSink } from '../../../../test/fakes/CapturingLogSink';
import { createReportFixture } from '../../../../test/fixtures/ReportFixtures';

const TEST_DATABASE_NAME: string = 'error_diagnosis_t10_test.db';
const TEST_ABILITY_WANT: Want = {
  bundleName: 'com.example.errordiagnosis',
  abilityName: 'EntryAbility'
};

class IncrementingTimeSource implements TimeSource {
  private timestamp: number;

  constructor(timestamp: number) {
    this.timestamp = timestamp;
  }

  now(): number {
    const current = this.timestamp;
    this.timestamp++;
    return current;
  }
}

let appContext: common.Context;
let activeManager: DatabaseManager | undefined = undefined;
let timeSource: IncrementingTimeSource;

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

async function createRepository(): Promise<LocalReportRepository> {
  activeManager = createManager();
  const initialized = await activeManager.initialize();
  expect(initialized.success).assertTrue();
  const store = new ReportStore(initialized.data, new HiLogService(new CapturingLogSink()));
  return new LocalReportRepository(store, timeSource, new HiLogService(new CapturingLogSink()));
}

export default function reportRepositoryInstrumentTest() {
  describe('ReportRepositoryInstrument', () => {
    beforeEach(async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility(TEST_ABILITY_WANT);
      appContext = (await delegator.getCurrentTopAbility()).context;
      activeManager = undefined;
      timeSource = new IncrementingTimeSource(1700000010000);
      await deleteTestDatabase();
    });

    afterEach(async (): Promise<void> => {
      if (activeManager !== undefined) {
        await activeManager.close();
        activeManager = undefined;
      }
      await deleteTestDatabase();
    });

    it('saves and reads one report using the real database', 0, async (): Promise<void> => {
      const repository = await createRepository();
      const input = createReportFixture('synthetic-t10-save', 1700000000000);

      const saved = await repository.save(input);
      const restored = await repository.getById(input.id);

      expect(saved.success).assertTrue();
      expect(saved.data?.savedAt).assertEqual(1700000010000);
      expect(restored.data?.id).assertEqual(input.id);
      expect(restored.data?.rawText).assertEqual(input.rawText);
    });

    it('keeps one row and the original savedAt after duplicate save', 0, async (): Promise<void> => {
      const repository = await createRepository();
      const input = createReportFixture('synthetic-t10-duplicate');

      const first = await repository.save(input);
      const second = await repository.save(input);
      const listed = await repository.list(0, 10);

      expect(first.data?.savedAt).assertEqual(second.data?.savedAt);
      expect(listed.data?.length).assertEqual(1);
    });

    it('returns reports descending and exposes the latest three', 0, async (): Promise<void> => {
      const repository = await createRepository();
      for (let index: number = 0; index < 5; index++) {
        await repository.save(createReportFixture(`synthetic-t10-order-${index}`));
      }

      const listed = await repository.list(1, 2);
      const recent = await repository.getRecent(3);

      expect(listed.data?.map((item: DiagnosisReport) => item.id).join(','))
        .assertEqual('synthetic-t10-order-3,synthetic-t10-order-2');
      expect(recent.data?.map((item: DiagnosisReport) => item.id).join(','))
        .assertEqual('synthetic-t10-order-4,synthetic-t10-order-3,synthetic-t10-order-2');
    });

    it('deletes one report and clears the remaining reports', 0, async (): Promise<void> => {
      const repository = await createRepository();
      await repository.save(createReportFixture('synthetic-t10-delete'));
      await repository.save(createReportFixture('synthetic-t10-clear'));

      expect((await repository.deleteById('synthetic-t10-delete')).data).assertTrue();
      expect((await repository.clearAll()).data).assertEqual(1);
      expect((await repository.list(0, 10)).data?.length).assertEqual(0);
    });

    it('automatically restores 201 saved reports to the newest 200', 0, async (): Promise<void> => {
      const repository = await createRepository();
      for (let index: number = 0; index <= HISTORY_RECORD_LIMIT; index++) {
        const saved = await repository.save(createReportFixture(`synthetic-t10-limit-${index}`));
        expect(saved.success).assertTrue();
      }

      const listed = await repository.list(0, HISTORY_RECORD_LIMIT);

      expect(listed.data?.length).assertEqual(HISTORY_RECORD_LIMIT);
      expect(listed.data?.[0].id).assertEqual('synthetic-t10-limit-200');
      expect(listed.data?.some((item: DiagnosisReport) => item.id === 'synthetic-t10-limit-0')).assertFalse();
    });

    it('keeps repository data after closing and reopening the database', 0, async (): Promise<void> => {
      let repository = await createRepository();
      await repository.save(createReportFixture('synthetic-t10-reopen'));
      await activeManager?.close();

      repository = await createRepository();

      expect((await repository.getById('synthetic-t10-reopen')).success).assertTrue();
    });
  });
}
