import { ReportRepository } from '../repository/report/ReportRepository';
import { QuickDiagnosisFormBindingData } from './FormCardModels';
import {
  createEmptyFormReportSummary,
  createFormReportSummary,
  FormReportSummary,
  toFormSummaryBindingData
} from './FormSummaryModels';
import { FormSummaryRepository } from './FormSummaryRepository';

export interface FormUpdateGateway {
  update(formId: string, binding: QuickDiagnosisFormBindingData): Promise<void>;
}

export class FormCardRefreshService {
  private summaries: FormSummaryRepository;
  private gateway: FormUpdateGateway;
  private reports?: ReportRepository;

  constructor(
    summaries: FormSummaryRepository,
    gateway: FormUpdateGateway,
    reports?: ReportRepository
  ) {
    this.summaries = summaries;
    this.gateway = gateway;
    this.reports = reports;
  }

  async syncFromRecentReport(): Promise<boolean> {
    if (this.reports === undefined) {
      return false;
    }
    try {
      const recent = await this.reports.getRecent(1);
      if (!recent.success || recent.data === undefined) {
        return false;
      }
      const summary: FormReportSummary = recent.data.length === 0 ?
        createEmptyFormReportSummary() : createFormReportSummary(recent.data[0]);
      if (!await this.summaries.saveSummary(summary)) {
        return false;
      }
      await this.publishToAll(summary);
      return true;
    } catch (_) {
      return false;
    }
  }

  async registerAndPublish(formId: string): Promise<boolean> {
    if (!await this.summaries.addFormId(formId)) {
      return false;
    }
    return this.publishStored(formId);
  }

  async publishStored(formId: string): Promise<boolean> {
    if (formId.trim().length === 0) {
      return false;
    }
    const summary = await this.summaries.loadSummary();
    try {
      await this.gateway.update(formId, toFormSummaryBindingData(summary));
      return true;
    } catch (_) {
      return false;
    }
  }

  unregister(formId: string): Promise<boolean> {
    return this.summaries.removeFormId(formId);
  }

  private async publishToAll(summary: FormReportSummary): Promise<void> {
    const ids = await this.summaries.listFormIds();
    const binding = toFormSummaryBindingData(summary);
    for (let index: number = 0; index < ids.length; index++) {
      try {
        await this.gateway.update(ids[index], binding);
      } catch (_) {
      }
    }
  }
}
