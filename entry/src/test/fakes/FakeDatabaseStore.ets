import {
  DatabaseStore,
  DatabaseStoreProvider
} from '../../main/ets/storage/database/DatabaseManager';

export enum SyntheticDatabaseFailureStage {
  NONE = 'NONE',
  OPEN = 'OPEN',
  TABLE = 'TABLE',
  INDEX = 'INDEX',
  VERSION = 'VERSION'
}

/** Shared synthetic backend used to model persistence across store instances. */
export class FakeDatabaseState {
  version: number = 0;
  committedSql: Array<string> = [];
  openCount: number = 0;
  closeCount: number = 0;
  rollbackCount: number = 0;
}

export class FakeDatabaseStore implements DatabaseStore {
  private state: FakeDatabaseState;
  private failureStage: SyntheticDatabaseFailureStage;
  private pendingSql: Array<string> = [];
  private pendingVersion: number | undefined = undefined;

  constructor(state: FakeDatabaseState, failureStage: SyntheticDatabaseFailureStage) {
    this.state = state;
    this.failureStage = failureStage;
  }

  getVersion(): number {
    return this.state.version;
  }

  setVersion(version: number): void {
    if (this.failureStage === SyntheticDatabaseFailureStage.VERSION) {
      throw new Error('Synthetic database version failure at /data/private.db');
    }
    this.pendingVersion = version;
  }

  beginTransaction(): void {
    this.pendingSql = [];
    this.pendingVersion = undefined;
  }

  executeSql(sql: string): Promise<void> {
    if (this.failureStage === SyntheticDatabaseFailureStage.TABLE && sql.includes('CREATE TABLE')) {
      return Promise.reject(new Error('Synthetic table failure with raw SQL: ' + sql));
    }
    if (this.failureStage === SyntheticDatabaseFailureStage.INDEX && sql.includes('CREATE INDEX')) {
      return Promise.reject(new Error('Synthetic index failure with raw SQL: ' + sql));
    }
    this.pendingSql.push(sql);
    return Promise.resolve();
  }

  commit(): void {
    for (let index: number = 0; index < this.pendingSql.length; index++) {
      this.state.committedSql.push(this.pendingSql[index]);
    }
    if (this.pendingVersion !== undefined) {
      this.state.version = this.pendingVersion;
    }
    this.pendingSql = [];
    this.pendingVersion = undefined;
  }

  rollback(): void {
    this.pendingSql = [];
    this.pendingVersion = undefined;
    this.state.rollbackCount++;
  }

  close(): Promise<void> {
    this.state.closeCount++;
    return Promise.resolve();
  }
}

export class FakeDatabaseStoreProvider implements DatabaseStoreProvider {
  private state: FakeDatabaseState;
  private failureStage: SyntheticDatabaseFailureStage;

  constructor(
    state: FakeDatabaseState,
    failureStage: SyntheticDatabaseFailureStage = SyntheticDatabaseFailureStage.NONE
  ) {
    this.state = state;
    this.failureStage = failureStage;
  }

  open(_databaseName: string): Promise<DatabaseStore> {
    this.state.openCount++;
    if (this.failureStage === SyntheticDatabaseFailureStage.OPEN) {
      return Promise.reject(new Error('Synthetic open failure at /data/private.db'));
    }
    return Promise.resolve(new FakeDatabaseStore(this.state, this.failureStage));
  }
}
