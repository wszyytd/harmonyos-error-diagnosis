import { DiagnosisReport } from '../model/DiagnosisModels';
import {
  createQuickDiagnosisFormData,
  QuickDiagnosisFormBindingData
} from './FormCardModels';

const ERROR_TYPE_LIMIT: number = 32;
const SUMMARY_LIMIT: number = 60;

export interface FormReportSummary {
  hasReport: boolean;
  errorType: string;
  summary: string;
  savedAtText: string;
}

function normalizeText(value: string, fallback: string, limit: number): string {
  const trimmed = value.trim();
  const normalized = trimmed.length === 0 ? fallback : trimmed;
  if (normalized.length <= limit) {
    return normalized;
  }
  return `${normalized.slice(0, limit - 1)}…`;
}

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function formatSavedAt(savedAt: number | undefined): string {
  if (savedAt === undefined || !Number.isFinite(savedAt) || savedAt < 0) {
    return '保存时间未知';
  }
  const date = new Date(savedAt);
  return `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())} ` +
    `${twoDigits(date.getHours())}:${twoDigits(date.getMinutes())}`;
}

export function createEmptyFormReportSummary(): FormReportSummary {
  return {
    hasReport: false,
    errorType: '暂无已保存报告',
    summary: '完成一次诊断并保存后显示',
    savedAtText: ''
  };
}

export function createFormReportSummary(report: DiagnosisReport): FormReportSummary {
  return {
    hasReport: true,
    errorType: normalizeText(report.errorType, '未分类错误', ERROR_TYPE_LIMIT),
    summary: normalizeText(report.summary, '暂无报告摘要', SUMMARY_LIMIT),
    savedAtText: formatSavedAt(report.savedAt)
  };
}

export function toFormSummaryBindingData(summary: FormReportSummary): QuickDiagnosisFormBindingData {
  const labels = createQuickDiagnosisFormData();
  return {
    appName: labels.appName,
    title: labels.title,
    description: labels.description,
    actionLabel: labels.actionLabel,
    privacyHint: labels.privacyHint,
    hasReport: summary.hasReport,
    errorType: summary.errorType,
    reportSummary: summary.summary,
    savedAtText: summary.savedAtText
  };
}
