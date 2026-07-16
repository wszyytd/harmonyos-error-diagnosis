import { describe, expect, it } from '@ohos/hypium';
import { createFormReportSummary } from '../../main/ets/form/FormSummaryModels';
import { FormSummaryRepository } from '../../main/ets/form/FormSummaryRepository';
import {
  InMemoryPreferencesState,
  InMemoryPreferencesStore
} from '../fakes/InMemoryPreferencesStore';
import { createReportFixture } from '../fixtures/ReportFixtures';

export default function formSummaryRepositoryTest() {
  describe('FormSummaryRepository', () => {
    it('returns a safe empty summary before the first save', 0, async () => {
      const repository = new FormSummaryRepository(
        new InMemoryPreferencesStore(new InMemoryPreferencesState())
      );

      const summary = await repository.loadSummary();

      expect(summary.hasReport).assertFalse();
      expect(summary.errorType).assertEqual('暂无已保存报告');
    });

    it('persists a summary across repository instances', 0, async () => {
      const state = new InMemoryPreferencesState();
      const first = new FormSummaryRepository(new InMemoryPreferencesStore(state));
      const expected = createFormReportSummary(createReportFixture('snapshot-report', 1, 1700000000000));

      expect(await first.saveSummary(expected)).assertTrue();
      const loaded = await new FormSummaryRepository(new InMemoryPreferencesStore(state)).loadSummary();

      expect(loaded.hasReport).assertTrue();
      expect(loaded.errorType).assertEqual(expected.errorType);
      expect(loaded.summary).assertEqual(expected.summary);
      expect(loaded.savedAtText).assertEqual(expected.savedAtText);
    });

    it('deduplicates and removes persistent Form identifiers', 0, async () => {
      const repository = new FormSummaryRepository(
        new InMemoryPreferencesStore(new InMemoryPreferencesState())
      );

      expect(await repository.addFormId('form-1')).assertTrue();
      expect(await repository.addFormId('form-1')).assertTrue();
      expect(await repository.addFormId('form-2')).assertTrue();
      expect((await repository.listFormIds()).join(',')).assertEqual('form-1,form-2');
      expect(await repository.removeFormId('form-1')).assertTrue();
      expect((await repository.listFormIds()).join(',')).assertEqual('form-2');
    });

    it('rejects blank Form identifiers without changing storage', 0, async () => {
      const repository = new FormSummaryRepository(
        new InMemoryPreferencesStore(new InMemoryPreferencesState())
      );

      expect(await repository.addFormId('  ')).assertFalse();
      expect(await repository.removeFormId('')).assertFalse();
      expect((await repository.listFormIds()).length).assertEqual(0);
    });

    it('falls back safely for damaged JSON and storage failures', 0, async () => {
      const state = new InMemoryPreferencesState();
      const store = new InMemoryPreferencesStore(state);
      store.seed('form.summary.snapshot', '{damaged');
      store.seed('form.instance.ids', '[1,2]');
      const damaged = new FormSummaryRepository(store);
      const failing = new FormSummaryRepository(new InMemoryPreferencesStore(state, true, true));

      expect((await damaged.loadSummary()).hasReport).assertFalse();
      expect((await damaged.listFormIds()).length).assertEqual(0);
      expect((await failing.loadSummary()).hasReport).assertFalse();
      expect(await failing.saveSummary(createFormReportSummary(createReportFixture()))).assertFalse();
    });
  });
}
