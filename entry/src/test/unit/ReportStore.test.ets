import { describe, expect, it } from '@ohos/hypium';
import { DIAGNOSIS_REPORT_TABLE } from '../../main/ets/constants/DatabaseConstants';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { DiagnosisReport, SourceType } from '../../main/ets/model/DiagnosisModels';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { ReportStore } from '../../main/ets/storage/database/ReportStore';
import { CapturingLogSink } from '../fakes/CapturingLogSink';
import {
  FakeReportDatabaseStore,
  ReportDatabaseFailureStage
} from '../fakes/FakeReportDatabaseStore';

function report(id: string = 'synthetic-report-store-001', savedAt: number = 1700000001000): DiagnosisReport {
  return {
    id: id,
    errorType: 'ArkTSTypeMismatch',
    secondaryTags: ['ArkTS'],
    summary: 'Synthetic summary',
    evidence: ['Synthetic evidence'],
    possibleCauses: ['Synthetic cause'],
    steps: ['Synthetic step'],
    suggestions: [],
    rawText: 'Synthetic raw report text',
    sourceType: SourceType.TEXT,
    createdAt: 1700000000000,
    savedAt: savedAt,
    isFavorite: false,
    engineVersion: 'synthetic-rules-1'
  };
}

function store(database: FakeReportDatabaseStore, sink: CapturingLogSink = new CapturingLogSink()): ReportStore {
  return new ReportStore(database, new HiLogService(sink));
}

export default function reportStoreTest() {
  describe('ReportStore', () => {
    it('inserts one serialized report without applying duplicate policy', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const result = await store(database).insert(report());

      expect(result.success).assertTrue();
      expect(result.data).assertEqual(1);
      expect(database.rows.length).assertEqual(1);
      expect(database.rows[0].id).assertEqual('synthetic-report-store-001');
    });

    it('reads one report by id and closes its result set', 0, async () => {
      const database = new FakeReportDatabaseStore();
      await store(database).insert(report());
      const result = await store(database).getById('synthetic-report-store-001');

      expect(result.success).assertTrue();
      expect(result.data?.id).assertEqual('synthetic-report-store-001');
      expect(database.lastQuery?.filterColumn).assertEqual('id');
      expect(database.lastResultSet?.closed).assertTrue();
    });

    it('returns REPORT_NOT_FOUND and closes an empty result set', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const result = await store(database).getById('synthetic-missing');

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.REPORT_NOT_FOUND);
      expect(database.lastResultSet?.closed).assertTrue();
    });

    it('lists reports using saved time descending offset and limit', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const reportStore = store(database);
      await reportStore.insert(report('synthetic-old', 1700000001000));
      await reportStore.insert(report('synthetic-middle', 1700000002000));
      await reportStore.insert(report('synthetic-new', 1700000003000));

      const result = await reportStore.list(1, 1);

      expect(result.success).assertTrue();
      expect(result.data?.length).assertEqual(1);
      expect(result.data?.[0].id).assertEqual('synthetic-middle');
      expect(database.lastQuery?.descendingColumn).assertEqual('saved_at');
      expect(database.lastQuery?.offset).assertEqual(1);
      expect(database.lastQuery?.limit).assertEqual(1);
      expect(database.lastResultSet?.closed).assertTrue();
    });

    it('deletes an existing report and reports false for a missing report', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const reportStore = store(database);
      await reportStore.insert(report());

      expect((await reportStore.deleteById('synthetic-report-store-001')).data).assertTrue();
      expect((await reportStore.deleteById('synthetic-report-store-001')).data).assertFalse();
    });

    it('clears all reports and returns the affected row count', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const reportStore = store(database);
      await reportStore.insert(report('synthetic-one'));
      await reportStore.insert(report('synthetic-two'));

      const result = await reportStore.clearAll();

      expect(result.success).assertTrue();
      expect(result.data).assertEqual(2);
      expect(database.rows.length).assertEqual(0);
    });

    it('persists favorite changes and reports a missing record', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const reportStore = store(database);
      await reportStore.insert(report());

      expect((await reportStore.updateFavorite('synthetic-report-store-001', true)).data).assertTrue();
      expect((await reportStore.getById('synthetic-report-store-001')).data?.isFavorite).assertTrue();
      expect((await reportStore.updateFavorite('synthetic-report-store-001', false)).data).assertTrue();
      expect((await reportStore.getById('synthetic-report-store-001')).data?.isFavorite).assertFalse();
      expect((await reportStore.updateFavorite('synthetic-missing', true)).data).assertFalse();
    });

    it('maps insert query and delete platform failures to existing storage codes', 0, async () => {
      const database = new FakeReportDatabaseStore();
      database.failureStage = ReportDatabaseFailureStage.INSERT;
      expect((await store(database).insert(report())).error?.code).assertEqual(ErrorCode.STORAGE_WRITE_FAILED);
      database.failureStage = ReportDatabaseFailureStage.QUERY;
      expect((await store(database).list(0, 10)).error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      database.failureStage = ReportDatabaseFailureStage.DELETE;
      expect((await store(database).clearAll()).error?.code).assertEqual(ErrorCode.STORAGE_DELETE_FAILED);
    });

    it('maps an unavailable database by operation without returning data', 0, async () => {
      const reportStore = new ReportStore(undefined, new HiLogService(new CapturingLogSink()));

      expect((await reportStore.insert(report())).error?.code).assertEqual(ErrorCode.STORAGE_WRITE_FAILED);
      expect((await reportStore.getById('synthetic-id')).error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      expect((await reportStore.deleteById('synthetic-id')).error?.code).assertEqual(ErrorCode.STORAGE_DELETE_FAILED);
    });

    it('maps a corrupted row to DATA_PARSE_FAILED closes the result and logs no content', 0, async () => {
      const database = new FakeReportDatabaseStore();
      const sink = new CapturingLogSink();
      await store(database).insert(report());
      database.rows[0].evidence_json = '["private-sensitive-evidence"';
      database.rows[0].raw_text = 'PRIVATE_RAW_TEXT_SHOULD_NOT_APPEAR';

      const result = await store(database, sink).getById('synthetic-report-store-001');
      const logs = JSON.stringify(sink.records);

      expect(result.error?.code).assertEqual(ErrorCode.DATA_PARSE_FAILED);
      expect(database.lastResultSet?.closed).assertTrue();
      expect(logs.includes('PRIVATE_RAW_TEXT_SHOULD_NOT_APPEAR')).assertFalse();
      expect(logs.includes('private-sensitive-evidence')).assertFalse();
      expect(logs.includes(DIAGNOSIS_REPORT_TABLE)).assertFalse();
    });

    it('closes the result set when row access itself fails', 0, async () => {
      const database = new FakeReportDatabaseStore();
      await store(database).insert(report());
      database.failureStage = ReportDatabaseFailureStage.RESULT_READ;

      const result = await store(database).list(0, 10);

      expect(result.error?.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
      expect(database.lastResultSet?.closed).assertTrue();
    });
  });
}
