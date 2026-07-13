import { describe, expect, it } from '@ohos/hypium';
import {
  CREATE_DIAGNOSIS_REPORT_TABLE_SQL,
  DATABASE_NAME,
  DATABASE_VERSION,
  DIAGNOSIS_REPORT_INDEXES,
  DIAGNOSIS_REPORT_TABLE,
  INDEX_DIAGNOSIS_REPORT_ERROR_TYPE,
  INDEX_DIAGNOSIS_REPORT_FAVORITE_SAVED_AT,
  INDEX_DIAGNOSIS_REPORT_SAVED_AT,
  V1_SCHEMA_STATEMENTS
} from '../../main/ets/constants/DatabaseConstants';

function normalized(sql: string): string {
  return sql.replace(/\s+/g, ' ').trim();
}

export default function databaseConstantsTest() {
  describe('DatabaseConstants', () => {
    it('uses stable V1 database table and index identifiers', 0, () => {
      expect(DATABASE_NAME).assertEqual('error_diagnosis.db');
      expect(DATABASE_VERSION).assertEqual(1);
      expect(DIAGNOSIS_REPORT_TABLE).assertEqual('diagnosis_report');
      expect(INDEX_DIAGNOSIS_REPORT_SAVED_AT).assertEqual('idx_diagnosis_report_saved_at');
      expect(INDEX_DIAGNOSIS_REPORT_ERROR_TYPE).assertEqual('idx_diagnosis_report_error_type');
      expect(INDEX_DIAGNOSIS_REPORT_FAVORITE_SAVED_AT)
        .assertEqual('idx_diagnosis_report_favorite_saved_at');
    });

    it('defines the complete detailed-design V1 report columns and constraints', 0, () => {
      const sql = normalized(CREATE_DIAGNOSIS_REPORT_TABLE_SQL);
      const requiredFragments: Array<string> = [
        'id TEXT PRIMARY KEY',
        'error_type TEXT NOT NULL',
        'secondary_tags_json TEXT NOT NULL',
        'summary TEXT NOT NULL',
        'evidence_json TEXT NOT NULL',
        'causes_json TEXT NOT NULL',
        'steps_json TEXT NOT NULL',
        'suggestions_json TEXT NOT NULL',
        'risk_notice TEXT',
        'raw_text TEXT NOT NULL',
        'source_type TEXT NOT NULL',
        'created_at INTEGER NOT NULL',
        'saved_at INTEGER NOT NULL',
        'is_favorite INTEGER NOT NULL DEFAULT 0',
        'engine_version TEXT NOT NULL'
      ];

      for (let index: number = 0; index < requiredFragments.length; index++) {
        expect(sql.includes(requiredFragments[index])).assertTrue();
      }
      expect(sql.includes('text_entity_tag')).assertFalse();
      expect(sql.includes('UNIQUE')).assertFalse();
    });

    it('defines only the three detailed-design indexes in V1 order', 0, () => {
      expect(DIAGNOSIS_REPORT_INDEXES.length).assertEqual(3);
      expect(normalized(DIAGNOSIS_REPORT_INDEXES[0].sql))
        .assertEqual('CREATE INDEX IF NOT EXISTS idx_diagnosis_report_saved_at ON diagnosis_report(saved_at DESC)');
      expect(normalized(DIAGNOSIS_REPORT_INDEXES[1].sql))
        .assertEqual('CREATE INDEX IF NOT EXISTS idx_diagnosis_report_error_type ON diagnosis_report(error_type)');
      expect(normalized(DIAGNOSIS_REPORT_INDEXES[2].sql)).assertEqual(
        'CREATE INDEX IF NOT EXISTS idx_diagnosis_report_favorite_saved_at ' +
        'ON diagnosis_report(is_favorite, saved_at DESC)'
      );
      expect(V1_SCHEMA_STATEMENTS.length).assertEqual(4);
    });
  });
}
