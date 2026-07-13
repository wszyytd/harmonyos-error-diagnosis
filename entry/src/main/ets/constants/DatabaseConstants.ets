/** Production database identifier for P0 diagnosis reports. */
export const DATABASE_NAME: string = 'error_diagnosis.db';

/** relationalStore schema version defined by detailed design section 8. */
export const DATABASE_VERSION: number = 1;

export const DIAGNOSIS_REPORT_TABLE: string = 'diagnosis_report';

/** Stable V1 column order used by report queries and row mapping. */
export const DIAGNOSIS_REPORT_COLUMNS: Array<string> = [
  'id',
  'error_type',
  'secondary_tags_json',
  'summary',
  'evidence_json',
  'causes_json',
  'steps_json',
  'suggestions_json',
  'risk_notice',
  'raw_text',
  'source_type',
  'created_at',
  'saved_at',
  'is_favorite',
  'engine_version'
];

export const INDEX_DIAGNOSIS_REPORT_SAVED_AT: string = 'idx_diagnosis_report_saved_at';
export const INDEX_DIAGNOSIS_REPORT_ERROR_TYPE: string = 'idx_diagnosis_report_error_type';
export const INDEX_DIAGNOSIS_REPORT_FAVORITE_SAVED_AT: string =
  'idx_diagnosis_report_favorite_saved_at';

/** Complete V1 report table. Serialization and row access belong to T9. */
export const CREATE_DIAGNOSIS_REPORT_TABLE_SQL: string = `
CREATE TABLE IF NOT EXISTS diagnosis_report (
  id TEXT PRIMARY KEY,
  error_type TEXT NOT NULL,
  secondary_tags_json TEXT NOT NULL,
  summary TEXT NOT NULL,
  evidence_json TEXT NOT NULL,
  causes_json TEXT NOT NULL,
  steps_json TEXT NOT NULL,
  suggestions_json TEXT NOT NULL,
  risk_notice TEXT,
  raw_text TEXT NOT NULL,
  source_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  saved_at INTEGER NOT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  engine_version TEXT NOT NULL
)
`;

export interface DatabaseSchemaStatement {
  identifier: string;
  sql: string;
}

export const DIAGNOSIS_REPORT_INDEXES: Array<DatabaseSchemaStatement> = [
  {
    identifier: INDEX_DIAGNOSIS_REPORT_SAVED_AT,
    sql: `CREATE INDEX IF NOT EXISTS ${INDEX_DIAGNOSIS_REPORT_SAVED_AT} ` +
      `ON ${DIAGNOSIS_REPORT_TABLE}(saved_at DESC)`
  },
  {
    identifier: INDEX_DIAGNOSIS_REPORT_ERROR_TYPE,
    sql: `CREATE INDEX IF NOT EXISTS ${INDEX_DIAGNOSIS_REPORT_ERROR_TYPE} ` +
      `ON ${DIAGNOSIS_REPORT_TABLE}(error_type)`
  },
  {
    identifier: INDEX_DIAGNOSIS_REPORT_FAVORITE_SAVED_AT,
    sql: `CREATE INDEX IF NOT EXISTS ${INDEX_DIAGNOSIS_REPORT_FAVORITE_SAVED_AT} ` +
      `ON ${DIAGNOSIS_REPORT_TABLE}(is_favorite, saved_at DESC)`
  }
];

/** Ordered, transactionally applied V1 schema operations. */
export const V1_SCHEMA_STATEMENTS: Array<DatabaseSchemaStatement> = [
  {
    identifier: DIAGNOSIS_REPORT_TABLE,
    sql: CREATE_DIAGNOSIS_REPORT_TABLE_SQL
  },
  DIAGNOSIS_REPORT_INDEXES[0],
  DIAGNOSIS_REPORT_INDEXES[1],
  DIAGNOSIS_REPORT_INDEXES[2]
];
