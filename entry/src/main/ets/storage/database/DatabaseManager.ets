import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import {
  DATABASE_NAME,
  DATABASE_VERSION,
  DatabaseSchemaStatement,
  V1_SCHEMA_STATEMENTS
} from '../../constants/DatabaseConstants';
import { ErrorCode } from '../../constants/ErrorCodes';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';
import {
  HiLogService,
  LogLevel,
  LogMetadataKey
} from '../../service/platform/HiLogService';

/** Minimal production boundary required to initialize and own an RDB store. */
export interface DatabaseStore {
  getVersion(): number;
  setVersion(version: number): void;
  beginTransaction(): void;
  executeSql(sql: string): Promise<void>;
  commit(): void;
  rollback(): void;
  close(): Promise<void>;
}

/** Injectable database opening boundary. Test fakes implement this exact interface. */
export interface DatabaseStoreProvider {
  open(databaseName: string): Promise<DatabaseStore>;
}

/** API 26 relationalStore adapter used by the production provider. */
class HarmonyDatabaseStore implements DatabaseStore {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  getVersion(): number {
    return this.store.version;
  }

  setVersion(version: number): void {
    this.store.version = version;
  }

  beginTransaction(): void {
    try {
      this.store.beginTransaction();
    } catch (_) {
      throw new Error('DATABASE_TRANSACTION_BEGIN_FAILED');
    }
  }

  async executeSql(sql: string): Promise<void> {
    try {
      await this.store.executeSql(sql);
    } catch (_) {
      throw new Error('DATABASE_SQL_EXECUTION_FAILED');
    }
  }

  commit(): void {
    try {
      this.store.commit();
    } catch (_) {
      throw new Error('DATABASE_TRANSACTION_COMMIT_FAILED');
    }
  }

  rollback(): void {
    try {
      this.store.rollBack();
    } catch (_) {
      throw new Error('DATABASE_TRANSACTION_ROLLBACK_FAILED');
    }
  }

  async close(): Promise<void> {
    try {
      await this.store.close();
    } catch (_) {
      throw new Error('DATABASE_CLOSE_FAILED');
    }
  }
}

/** Opens application-sandboxed S1 databases without exposing their paths. */
export class HarmonyDatabaseStoreProvider implements DatabaseStoreProvider {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async open(databaseName: string): Promise<DatabaseStore> {
    try {
      const store = await relationalStore.getRdbStore(this.context, {
        name: databaseName,
        securityLevel: relationalStore.SecurityLevel.S1
      });
      return new HarmonyDatabaseStore(store);
    } catch (_) {
      throw new Error('DATABASE_OPEN_FAILED');
    }
  }
}

/** Owns the V1 database lifecycle; report row operations deliberately live elsewhere. */
export class DatabaseManager {
  private provider: DatabaseStoreProvider;
  private logger: HiLogService;
  private databaseName: string;
  private store: DatabaseStore | undefined = undefined;

  constructor(
    provider: DatabaseStoreProvider,
    logger: HiLogService,
    databaseName: string = DATABASE_NAME
  ) {
    this.provider = provider;
    this.logger = logger;
    this.databaseName = databaseName;
  }

  async initialize(): Promise<AppResult<DatabaseStore>> {
    if (this.store !== undefined) {
      return createSuccessResult<DatabaseStore>(this.store);
    }

    let openedStore: DatabaseStore;
    try {
      openedStore = await this.provider.open(this.databaseName);
    } catch (_) {
      this.logFailure('open', 'database', ErrorCode.STORAGE_READ_FAILED);
      return createFailureResult<DatabaseStore>({
        code: ErrorCode.STORAGE_READ_FAILED,
        message: '数据库打开失败，请重试。',
        retryable: true,
        causeType: 'DATABASE_OPEN'
      });
    }

    let version: number;
    try {
      version = openedStore.getVersion();
    } catch (_) {
      await this.closeAfterFailure(openedStore);
      return this.migrationFailure('version_check', 'schema.version');
    }

    if (version === DATABASE_VERSION) {
      this.store = openedStore;
      this.logSuccess('reopen');
      return createSuccessResult<DatabaseStore>(openedStore);
    }
    if (version !== 0) {
      await this.closeAfterFailure(openedStore);
      return this.migrationFailure('version_check', 'schema.version');
    }

    const initialized = await this.initializeV1(openedStore);
    if (!initialized.success) {
      return initialized;
    }
    this.store = openedStore;
    this.logSuccess('create');
    return createSuccessResult<DatabaseStore>(openedStore);
  }

  async close(): Promise<AppResult<void>> {
    if (this.store === undefined) {
      return createSuccessResult<void>(undefined);
    }
    const closingStore = this.store;
    this.store = undefined;
    try {
      await closingStore.close();
      return createSuccessResult<void>(undefined);
    } catch (_) {
      this.logFailure('close', 'database', ErrorCode.STORAGE_WRITE_FAILED);
      return createFailureResult<void>({
        code: ErrorCode.STORAGE_WRITE_FAILED,
        message: '数据库关闭失败。',
        retryable: true,
        causeType: 'DATABASE_CLOSE'
      });
    }
  }

  private async initializeV1(openedStore: DatabaseStore): Promise<AppResult<DatabaseStore>> {
    let currentIdentifier: string = 'transaction';
    let transactionStarted: boolean = false;
    try {
      openedStore.beginTransaction();
      transactionStarted = true;
      for (let index: number = 0; index < V1_SCHEMA_STATEMENTS.length; index++) {
        const statement: DatabaseSchemaStatement = V1_SCHEMA_STATEMENTS[index];
        currentIdentifier = statement.identifier;
        await openedStore.executeSql(statement.sql);
      }
      currentIdentifier = 'schema.version';
      openedStore.setVersion(DATABASE_VERSION);
      openedStore.commit();
      transactionStarted = false;
      if (openedStore.getVersion() !== DATABASE_VERSION) {
        await this.closeAfterFailure(openedStore);
        return this.migrationFailure('version_verify', currentIdentifier);
      }
      return createSuccessResult<DatabaseStore>(openedStore);
    } catch (_) {
      if (transactionStarted) {
        try {
          openedStore.rollback();
        } catch (_) {
        }
      }
      await this.closeAfterFailure(openedStore);
      return this.migrationFailure('initialize', currentIdentifier);
    }
  }

  private async closeAfterFailure(store: DatabaseStore): Promise<void> {
    try {
      await store.close();
    } catch (_) {
      this.logFailure('cleanup', 'database', ErrorCode.STORAGE_WRITE_FAILED);
    }
  }

  private migrationFailure(stage: string, identifier: string): AppResult<DatabaseStore> {
    this.logFailure(stage, identifier, ErrorCode.STORAGE_MIGRATION_FAILED);
    return createFailureResult<DatabaseStore>({
      code: ErrorCode.STORAGE_MIGRATION_FAILED,
      message: '数据库结构初始化失败，请重试。',
      retryable: true,
      causeType: 'DATABASE_SCHEMA'
    });
  }

  private logSuccess(stage: string): void {
    this.logger.log(LogLevel.INFO, {
      domain: 'database',
      event: 'database_initialized',
      result: 'success',
      metadata: [
        { key: LogMetadataKey.STAGE, value: stage },
        { key: LogMetadataKey.RESOURCE_NAME, value: 'schema.v1' }
      ]
    });
  }

  private logFailure(stage: string, identifier: string, code: ErrorCode): void {
    this.logger.log(LogLevel.ERROR, {
      domain: 'database',
      event: 'database_failed',
      result: 'failure',
      errorCode: code,
      metadata: [
        { key: LogMetadataKey.STAGE, value: stage },
        { key: LogMetadataKey.RESOURCE_NAME, value: identifier }
      ]
    });
  }
}
