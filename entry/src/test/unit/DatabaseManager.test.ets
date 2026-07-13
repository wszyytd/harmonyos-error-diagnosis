import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { DATABASE_VERSION, V1_SCHEMA_STATEMENTS } from '../../main/ets/constants/DatabaseConstants';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { DatabaseManager } from '../../main/ets/storage/database/DatabaseManager';
import { CapturingLogSink } from '../fakes/CapturingLogSink';
import {
  FakeDatabaseState,
  FakeDatabaseStoreProvider,
  SyntheticDatabaseFailureStage
} from '../fakes/FakeDatabaseStore';

function createManager(
  state: FakeDatabaseState,
  failureStage: SyntheticDatabaseFailureStage = SyntheticDatabaseFailureStage.NONE,
  sink: CapturingLogSink = new CapturingLogSink()
): DatabaseManager {
  return new DatabaseManager(
    new FakeDatabaseStoreProvider(state, failureStage),
    new HiLogService(sink)
  );
}

export default function databaseManagerTest() {
  describe('DatabaseManager', () => {
    it('initializes V1 atomically and returns a usable store', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const result = await createManager(state).initialize();

      expect(result.success).assertTrue();
      expect(result.data !== undefined).assertTrue();
      expect(result.data?.getVersion()).assertEqual(DATABASE_VERSION);
      expect(state.committedSql.length).assertEqual(V1_SCHEMA_STATEMENTS.length);
      expect(state.rollbackCount).assertEqual(0);
    });

    it('returns the initialized store without reopening or recreating schema', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const manager = createManager(state);
      const first = await manager.initialize();
      const second = await manager.initialize();

      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
      expect(first.data === second.data).assertTrue();
      expect(state.openCount).assertEqual(1);
      expect(state.committedSql.length).assertEqual(V1_SCHEMA_STATEMENTS.length);
    });

    it('reopens an existing V1 database without reexecuting schema', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const provider = new FakeDatabaseStoreProvider(state);
      const first = new DatabaseManager(provider, new HiLogService(new CapturingLogSink()));
      const second = new DatabaseManager(provider, new HiLogService(new CapturingLogSink()));
      await first.initialize();
      await first.close();
      const reopened = await second.initialize();

      expect(reopened.success).assertTrue();
      expect(reopened.data?.getVersion()).assertEqual(DATABASE_VERSION);
      expect(state.openCount).assertEqual(2);
      expect(state.committedSql.length).assertEqual(V1_SCHEMA_STATEMENTS.length);
    });

    it('maps database opening failure without exposing a store', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const sink = new CapturingLogSink();
      const result = await createManager(state, SyntheticDatabaseFailureStage.OPEN, sink).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      expect(JSON.stringify(sink.records).includes('/data/private.db')).assertFalse();
    });

    it('rolls back and maps table creation failure', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const result = await createManager(state, SyntheticDatabaseFailureStage.TABLE).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
      expect(state.committedSql.length).assertEqual(0);
      expect(state.rollbackCount).assertEqual(1);
      expect(state.closeCount).assertEqual(1);
    });

    it('rolls back and maps index creation failure', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const result = await createManager(state, SyntheticDatabaseFailureStage.INDEX).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
      expect(state.committedSql.length).assertEqual(0);
      expect(state.version).assertEqual(0);
    });

    it('rolls back and maps version initialization failure', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const result = await createManager(state, SyntheticDatabaseFailureStage.VERSION).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
      expect(state.committedSql.length).assertEqual(0);
      expect(state.version).assertEqual(0);
    });

    it('rejects unsupported versions and closes the unusable store', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      state.version = 2;
      const result = await createManager(state).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
      expect(state.closeCount).assertEqual(1);
      expect(state.committedSql.length).assertEqual(0);
    });

    it('logs only stable identifiers and never SQL paths or row content', 0, async (): Promise<void> => {
      const state = new FakeDatabaseState();
      const sink = new CapturingLogSink();
      await createManager(state, SyntheticDatabaseFailureStage.INDEX, sink).initialize();
      const serialized = JSON.stringify(sink.records);

      expect(serialized.includes('idx_diagnosis_report_saved_at')).assertTrue();
      expect(serialized.includes('CREATE INDEX')).assertFalse();
      expect(serialized.includes('/data/')).assertFalse();
      expect(serialized.includes('raw_text')).assertFalse();
      expect(serialized.includes('SYNTHETIC_TOKEN')).assertFalse();
    });
  });
}
