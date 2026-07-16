import {
  DatabaseQuerySpec,
  DatabaseResultSet,
  DatabaseStore,
  DatabaseUpdateValues,
  DatabaseValue,
  DatabaseValues
} from '../../main/ets/storage/database/DatabaseManager';

export enum ReportDatabaseFailureStage {
  NONE = 'NONE',
  INSERT = 'INSERT',
  QUERY = 'QUERY',
  DELETE = 'DELETE',
  UPDATE = 'UPDATE',
  RESULT_READ = 'RESULT_READ'
}

function valueAt(row: DatabaseValues, columnName: string): DatabaseValue {
  switch (columnName) {
    case 'id': return row.id;
    case 'error_type': return row.error_type;
    case 'secondary_tags_json': return row.secondary_tags_json;
    case 'summary': return row.summary;
    case 'evidence_json': return row.evidence_json;
    case 'causes_json': return row.causes_json;
    case 'steps_json': return row.steps_json;
    case 'suggestions_json': return row.suggestions_json;
    case 'risk_notice': return row.risk_notice;
    case 'raw_text': return row.raw_text;
    case 'source_type': return row.source_type;
    case 'created_at': return row.created_at;
    case 'saved_at': return row.saved_at;
    case 'is_favorite': return row.is_favorite;
    case 'engine_version': return row.engine_version;
    default: return undefined;
  }
}

export class FakeReportResultSet implements DatabaseResultSet {
  private rows: Array<DatabaseValues>;
  private position: number = -1;
  private failOnRead: boolean;
  closed: boolean = false;

  constructor(rows: Array<DatabaseValues>, failOnRead: boolean = false) {
    this.rows = rows;
    this.failOnRead = failOnRead;
  }

  goToNextRow(): boolean {
    if (this.failOnRead) {
      throw new Error('Synthetic result read failed with private row content');
    }
    this.position++;
    return this.position < this.rows.length;
  }

  getValue(columnName: string): DatabaseValue {
    if (this.failOnRead) {
      throw new Error('Synthetic result value failed at /data/private.db');
    }
    return valueAt(this.rows[this.position], columnName);
  }

  close(): void {
    this.closed = true;
  }
}

export class FakeReportDatabaseStore implements DatabaseStore {
  rows: Array<DatabaseValues> = [];
  lastQuery: DatabaseQuerySpec | undefined = undefined;
  lastResultSet: FakeReportResultSet | undefined = undefined;
  failureStage: ReportDatabaseFailureStage = ReportDatabaseFailureStage.NONE;
  version: number = 1;

  getVersion(): number {
    return this.version;
  }

  setVersion(version: number): void {
    this.version = version;
  }

  beginTransaction(): void {
  }

  executeSql(_sql: string): Promise<void> {
    return Promise.resolve();
  }

  commit(): void {
  }

  rollback(): void {
  }

  close(): Promise<void> {
    return Promise.resolve();
  }

  insert(_tableName: string, values: DatabaseValues): Promise<number> {
    if (this.failureStage === ReportDatabaseFailureStage.INSERT) {
      return Promise.reject(new Error('Synthetic insert failure with raw report text'));
    }
    this.rows.push(values);
    return Promise.resolve(this.rows.length);
  }

  query(spec: DatabaseQuerySpec, _columns: Array<string>): Promise<DatabaseResultSet> {
    if (this.failureStage === ReportDatabaseFailureStage.QUERY) {
      return Promise.reject(new Error('Synthetic query failure at /data/private.db'));
    }
    this.lastQuery = spec;
    let selected: Array<DatabaseValues> = this.rows.slice();
    if (spec.filterColumn !== undefined) {
      const filterColumn = spec.filterColumn;
      selected = selected.filter((row: DatabaseValues) => valueAt(row, filterColumn) === spec.filterValue);
    }
    if (spec.descendingColumn !== undefined) {
      const column = spec.descendingColumn;
      selected.sort((left: DatabaseValues, right: DatabaseValues): number =>
        (valueAt(right, column) as number) - (valueAt(left, column) as number));
    }
    const offset = spec.offset === undefined ? 0 : spec.offset;
    const end = spec.limit === undefined ? selected.length : offset + spec.limit;
    selected = selected.slice(offset, end);
    this.lastResultSet = new FakeReportResultSet(
      selected,
      this.failureStage === ReportDatabaseFailureStage.RESULT_READ
    );
    return Promise.resolve(this.lastResultSet);
  }

  delete(spec: DatabaseQuerySpec): Promise<number> {
    if (this.failureStage === ReportDatabaseFailureStage.DELETE) {
      return Promise.reject(new Error('Synthetic delete failure at /data/private.db'));
    }
    const before = this.rows.length;
    if (spec.filterColumn === undefined) {
      this.rows = [];
    } else {
      const filterColumn = spec.filterColumn;
      this.rows = this.rows.filter((row: DatabaseValues) =>
        valueAt(row, filterColumn) !== spec.filterValue);
    }
    return Promise.resolve(before - this.rows.length);
  }

  update(spec: DatabaseQuerySpec, values: DatabaseUpdateValues): Promise<number> {
    if (this.failureStage === ReportDatabaseFailureStage.UPDATE) {
      return Promise.reject(new Error('Synthetic update failure at /data/private.db'));
    }
    let count: number = 0;
    this.rows.forEach((row: DatabaseValues): void => {
      if (spec.filterColumn !== undefined && valueAt(row, spec.filterColumn) === spec.filterValue) {
        row.is_favorite = values.is_favorite;
        count++;
      }
    });
    return Promise.resolve(count);
  }
}
