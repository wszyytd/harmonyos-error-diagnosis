import { common, Want } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium';
import {
  CREATE_DIAGNOSIS_REPORT_TABLE_SQL,
  DATABASE_VERSION,
  DIAGNOSIS_REPORT_INDEXES,
  DIAGNOSIS_REPORT_TABLE
} from '../../../../main/ets/constants/DatabaseConstants';
import { ErrorCode } from '../../../../main/ets/constants/ErrorCodes';
import { HiLogService } from '../../../../main/ets/service/platform/HiLogService';
import {
  DatabaseManager,
  HarmonyDatabaseStoreProvider
} from '../../../../main/ets/storage/database/DatabaseManager';
import { CapturingLogSink } from '../../../../test/fakes/CapturingLogSink';
import {
  FakeDatabaseState,
  FakeDatabaseStoreProvider,
  SyntheticDatabaseFailureStage
} from '../../../../test/fakes/FakeDatabaseStore';

const TEST_DATABASE_NAME: string = 'error_diagnosis_t8_test.db';
const TEST_ABILITY_WANT: Want = {
  bundleName: 'com.example.errordiagnosis',
  abilityName: 'EntryAbility'
};

interface ColumnInfo {
  name: string;
  type: string;
  notNull: number;
  defaultValue?: string;
  primaryKey: number;
}

interface ExpectedColumn {
  name: string;
  type: string;
  notNull: number;
  defaultValue?: string;
  primaryKey: number;
}

let appContext: common.Context;
let activeManager: DatabaseManager | undefined = undefined;

async function deleteTestDatabase(): Promise<void> {
  try {
    await relationalStore.deleteRdbStore(appContext, TEST_DATABASE_NAME);
  } catch (_) {
  }
}

async function openTestStore(): Promise<relationalStore.RdbStore> {
  return relationalStore.getRdbStore(appContext, {
    name: TEST_DATABASE_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  });
}

function createRealManager(): DatabaseManager {
  return new DatabaseManager(
    new HarmonyDatabaseStoreProvider(appContext),
    new HiLogService(new CapturingLogSink()),
    TEST_DATABASE_NAME
  );
}

function createFakeManager(
  stage: SyntheticDatabaseFailureStage,
  sink: CapturingLogSink = new CapturingLogSink()
): DatabaseManager {
  return new DatabaseManager(
    new FakeDatabaseStoreProvider(new FakeDatabaseState(), stage),
    new HiLogService(sink),
    TEST_DATABASE_NAME
  );
}

async function readColumns(store: relationalStore.RdbStore): Promise<Array<ColumnInfo>> {
  const resultSet = await store.querySql(`PRAGMA table_info('${DIAGNOSIS_REPORT_TABLE}')`);
  const columns: Array<ColumnInfo> = [];
  try {
    while (resultSet.goToNextRow()) {
      const defaultIndex = resultSet.getColumnIndex('dflt_value');
      const column: ColumnInfo = {
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        type: resultSet.getString(resultSet.getColumnIndex('type')),
        notNull: resultSet.getLong(resultSet.getColumnIndex('notnull')),
        primaryKey: resultSet.getLong(resultSet.getColumnIndex('pk'))
      };
      if (!resultSet.isColumnNull(defaultIndex)) {
        column.defaultValue = resultSet.getString(defaultIndex);
      }
      columns.push(column);
    }
  } finally {
    resultSet.close();
  }
  return columns;
}

function findColumn(columns: Array<ColumnInfo>, name: string): ColumnInfo | undefined {
  for (let index: number = 0; index < columns.length; index++) {
    if (columns[index].name === name) {
      return columns[index];
    }
  }
  return undefined;
}

function assertColumn(actual: ColumnInfo | undefined, expected: ExpectedColumn): void {
  expect(actual !== undefined).assertTrue();
  expect(actual?.type).assertEqual(expected.type);
  expect(actual?.notNull).assertEqual(expected.notNull);
  expect(actual?.defaultValue).assertEqual(expected.defaultValue);
  expect(actual?.primaryKey).assertEqual(expected.primaryKey);
}

function normalized(sql: string): string {
  return sql
    .replace(/CREATE INDEX IF NOT EXISTS/g, 'CREATE INDEX')
    .replace(/\s+/g, ' ')
    .trim();
}

export default function databaseManagerInstrumentTest() {
  describe('DatabaseManagerInstrument', () => {
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

    it('creates the exact V1 report schema in an empty isolated database', 0, async (): Promise<void> => {
      activeManager = createRealManager();
      const initialized = await activeManager.initialize();
      const store = await openTestStore();
      try {
        const columns = await readColumns(store);
        const expected: Array<ExpectedColumn> = [
          { name: 'id', type: 'TEXT', notNull: 0, primaryKey: 1 },
          { name: 'error_type', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'secondary_tags_json', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'summary', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'evidence_json', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'causes_json', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'steps_json', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'suggestions_json', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'risk_notice', type: 'TEXT', notNull: 0, primaryKey: 0 },
          { name: 'raw_text', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'source_type', type: 'TEXT', notNull: 1, primaryKey: 0 },
          { name: 'created_at', type: 'INTEGER', notNull: 1, primaryKey: 0 },
          { name: 'saved_at', type: 'INTEGER', notNull: 1, primaryKey: 0 },
          { name: 'is_favorite', type: 'INTEGER', notNull: 1, defaultValue: '0', primaryKey: 0 },
          { name: 'engine_version', type: 'TEXT', notNull: 1, primaryKey: 0 }
        ];

        expect(initialized.success).assertTrue();
        expect(columns.length).assertEqual(expected.length);
        for (let index: number = 0; index < expected.length; index++) {
          assertColumn(findColumn(columns, expected[index].name), expected[index]);
        }
        expect(store.version).assertEqual(DATABASE_VERSION);
        expect(normalized(CREATE_DIAGNOSIS_REPORT_TABLE_SQL).includes('text_entity_tag')).assertFalse();
      } finally {
        await store.close();
      }
    });

    it('creates exactly the three V1 indexes with designed ordering', 0, async (): Promise<void> => {
      activeManager = createRealManager();
      await activeManager.initialize();
      const store = await openTestStore();
      const resultSet = await store.querySql(
        `SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = '${DIAGNOSIS_REPORT_TABLE}' ` +
        `AND name NOT LIKE 'sqlite_autoindex%' ORDER BY name`
      );
      const actualSql: Array<string> = [];
      try {
        while (resultSet.goToNextRow()) {
          actualSql.push(normalized(resultSet.getString(resultSet.getColumnIndex('sql'))));
        }
      } finally {
        resultSet.close();
        await store.close();
      }

      expect(actualSql.length).assertEqual(DIAGNOSIS_REPORT_INDEXES.length);
      for (let index: number = 0; index < DIAGNOSIS_REPORT_INDEXES.length; index++) {
        expect(actualSql.includes(normalized(DIAGNOSIS_REPORT_INDEXES[index].sql))).assertTrue();
      }
    });

    it('repeated initialization reuses the same initialized store', 0, async (): Promise<void> => {
      activeManager = createRealManager();
      const first = await activeManager.initialize();
      const second = await activeManager.initialize();

      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
      expect(first.data === second.data).assertTrue();
    });

    it('closes and reopens the same V1 database with a new manager', 0, async (): Promise<void> => {
      activeManager = createRealManager();
      const first = await activeManager.initialize();
      await activeManager.close();
      activeManager = createRealManager();
      const reopened = await activeManager.initialize();

      expect(first.success).assertTrue();
      expect(reopened.success).assertTrue();
      expect(reopened.data?.getVersion()).assertEqual(DATABASE_VERSION);
    });

    it('maps an injected database open failure and returns no store', 0, async (): Promise<void> => {
      const result = await createFakeManager(SyntheticDatabaseFailureStage.OPEN).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
    });

    it('maps an injected table creation failure and returns no store', 0, async (): Promise<void> => {
      const result = await createFakeManager(SyntheticDatabaseFailureStage.TABLE).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
    });

    it('maps an injected index creation failure and returns no store', 0, async (): Promise<void> => {
      const result = await createFakeManager(SyntheticDatabaseFailureStage.INDEX).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
    });

    it('maps an injected version initialization failure and returns no store', 0, async (): Promise<void> => {
      const result = await createFakeManager(SyntheticDatabaseFailureStage.VERSION).initialize();

      expect(result.success).assertFalse();
      expect(result.data === undefined).assertTrue();
      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_MIGRATION_FAILED);
    });

    it('keeps failure logs free of database paths full SQL and row content', 0, async (): Promise<void> => {
      const sink = new CapturingLogSink();
      const result = await createFakeManager(SyntheticDatabaseFailureStage.INDEX, sink).initialize();
      const serialized = JSON.stringify(sink.records);

      expect(result.success).assertFalse();
      expect(serialized.includes('CREATE INDEX')).assertFalse();
      expect(serialized.includes('/data/')).assertFalse();
      expect(serialized.includes('raw_text')).assertFalse();
      expect(serialized.includes('error_diagnosis_t8_test.db')).assertFalse();
    });
  });
}
