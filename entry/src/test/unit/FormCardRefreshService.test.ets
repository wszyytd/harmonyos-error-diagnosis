import { describe, expect, it } from '@ohos/hypium';
import { createFailureResult, createSuccessResult } from '../../main/ets/model/ResultModels';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import {
  FormCardRefreshService,
  FormUpdateGateway
} from '../../main/ets/form/FormCardRefreshService';
import { QuickDiagnosisFormBindingData } from '../../main/ets/form/FormCardModels';
import { createFormReportSummary } from '../../main/ets/form/FormSummaryModels';
import { FormSummaryRepository } from '../../main/ets/form/FormSummaryRepository';
import {
  InMemoryPreferencesState,
  InMemoryPreferencesStore
} from '../fakes/InMemoryPreferencesStore';
import { FakeReportRepository } from '../fakes/FakeReportRepository';
import { createReportFixture } from '../fixtures/ReportFixtures';

class FakeFormUpdateGateway implements FormUpdateGateway {
  updatedIds: Array<string> = [];
  bindings: Array<QuickDiagnosisFormBindingData> = [];
  failingId?: string;

  update(formId: string, binding: QuickDiagnosisFormBindingData): Promise<void> {
    this.updatedIds.push(formId);
    this.bindings.push(binding);
    if (formId === this.failingId) {
      return Promise.reject(new Error('Synthetic Form update failure'));
    }
    return Promise.resolve();
  }
}

function createSummaryRepository(): FormSummaryRepository {
  return new FormSummaryRepository(
    new InMemoryPreferencesStore(new InMemoryPreferencesState())
  );
}

export default function formCardRefreshServiceTest() {
  describe('FormCardRefreshService', () => {
    it('publishes the latest saved report to every registered Form', 0, async () => {
      const reports = new FakeReportRepository();
      const summaryRepository = createSummaryRepository();
      const gateway = new FakeFormUpdateGateway();
      reports.recentResult = createSuccessResult([
        createReportFixture('latest-report', 1, 300),
        createReportFixture('older-report', 1, 200)
      ]);
      await summaryRepository.addFormId('form-1');
      await summaryRepository.addFormId('form-2');
      const service = new FormCardRefreshService(summaryRepository, gateway, reports);

      expect(await service.syncFromRecentReport()).assertTrue();

      expect(reports.recentLimit).assertEqual(1);
      expect((await summaryRepository.loadSummary()).hasReport).assertTrue();
      expect(gateway.updatedIds.join(',')).assertEqual('form-1,form-2');
      expect(gateway.bindings[0].errorType).assertEqual('ArkTSTypeMismatch');
      expect(gateway.bindings[0].hasReport).assertTrue();
    });

    it('publishes the empty state after history is cleared', 0, async () => {
      const reports = new FakeReportRepository();
      const summaryRepository = createSummaryRepository();
      const gateway = new FakeFormUpdateGateway();
      await summaryRepository.saveSummary(
        createFormReportSummary(createReportFixture('old-report', 1, 2))
      );
      await summaryRepository.addFormId('form-empty');
      reports.recentResult = createSuccessResult([]);
      const service = new FormCardRefreshService(summaryRepository, gateway, reports);

      expect(await service.syncFromRecentReport()).assertTrue();
      expect((await summaryRepository.loadSummary()).hasReport).assertFalse();
      expect(gateway.bindings[0].errorType).assertEqual('暂无已保存报告');
    });

    it('keeps the stored snapshot when recent reports cannot be read', 0, async () => {
      const reports = new FakeReportRepository();
      const summaryRepository = createSummaryRepository();
      const gateway = new FakeFormUpdateGateway();
      await summaryRepository.saveSummary(
        createFormReportSummary(createReportFixture('retained-report', 1, 2))
      );
      reports.recentResult = createFailureResult({
        code: ErrorCode.STORAGE_READ_FAILED,
        message: 'Synthetic private failure',
        retryable: true
      });
      const service = new FormCardRefreshService(summaryRepository, gateway, reports);

      expect(await service.syncFromRecentReport()).assertFalse();
      expect((await summaryRepository.loadSummary()).hasReport).assertTrue();
      expect(gateway.updatedIds.length).assertEqual(0);
    });

    it('continues updating remaining Forms when one host update fails', 0, async () => {
      const reports = new FakeReportRepository();
      const summaryRepository = createSummaryRepository();
      const gateway = new FakeFormUpdateGateway();
      gateway.failingId = 'form-1';
      reports.recentResult = createSuccessResult([createReportFixture('latest', 1, 2)]);
      await summaryRepository.addFormId('form-1');
      await summaryRepository.addFormId('form-2');
      const service = new FormCardRefreshService(summaryRepository, gateway, reports);

      expect(await service.syncFromRecentReport()).assertTrue();
      expect(gateway.updatedIds.join(',')).assertEqual('form-1,form-2');
    });

    it('registers publishes and removes one Form identifier', 0, async () => {
      const summaryRepository = createSummaryRepository();
      const gateway = new FakeFormUpdateGateway();
      const service = new FormCardRefreshService(summaryRepository, gateway);

      expect(await service.registerAndPublish('form-new')).assertTrue();
      expect(gateway.updatedIds[0]).assertEqual('form-new');
      expect(gateway.bindings[0].hasReport).assertFalse();
      expect((await summaryRepository.listFormIds()).join(',')).assertEqual('form-new');
      expect(await service.unregister('form-new')).assertTrue();
      expect((await summaryRepository.listFormIds()).length).assertEqual(0);
    });
  });
}
