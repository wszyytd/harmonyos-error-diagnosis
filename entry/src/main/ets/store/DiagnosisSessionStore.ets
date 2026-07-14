import { DiagnosisReport, SourceType } from '../model/DiagnosisModels';
import { AppError } from '../model/ResultModels';
import { IdGenerator } from '../utils/IdGenerator';
import { TimeProvider } from '../utils/TimeProvider';

export interface DiagnosisSessionState {
  sessionId: string;
  sourceType: SourceType;
  rawText: string;
  normalizedText: string;
  imageUri?: string;
  pendingReport?: DiagnosisReport;
  createdAt: number;
  updatedAt: number;
  validationError?: AppError;
  usedExample: boolean;
}

function safeSourceType(sourceType: SourceType): SourceType {
  return sourceType === SourceType.IMAGE || sourceType === SourceType.TEXT ? sourceType : SourceType.TEXT;
}

function copyError(error: AppError): AppError {
  const copied: AppError = {
    code: error.code,
    message: error.message,
    retryable: error.retryable
  };
  if (error.causeType !== undefined) {
    copied.causeType = error.causeType;
  }
  if (error.correlationId !== undefined) {
    copied.correlationId = error.correlationId;
  }
  return copied;
}

function copyReport(report: DiagnosisReport): DiagnosisReport {
  const copied: DiagnosisReport = {
    id: report.id,
    errorType: report.errorType,
    summary: report.summary,
    evidence: report.evidence.slice(),
    possibleCauses: report.possibleCauses.slice(),
    steps: report.steps.slice(),
    rawText: report.rawText,
    sourceType: report.sourceType,
    createdAt: report.createdAt,
    isFavorite: report.isFavorite,
    engineVersion: report.engineVersion
  };
  if (report.secondaryTags !== undefined) {
    copied.secondaryTags = report.secondaryTags.slice();
  }
  if (report.suggestions !== undefined) {
    copied.suggestions = report.suggestions.slice();
  }
  if (report.riskNotice !== undefined) {
    copied.riskNotice = report.riskNotice;
  }
  if (report.savedAt !== undefined) {
    copied.savedAt = report.savedAt;
  }
  return copied;
}

export function copyDiagnosisSessionState(state: DiagnosisSessionState): DiagnosisSessionState {
  const copied: DiagnosisSessionState = {
    sessionId: state.sessionId,
    sourceType: state.sourceType,
    rawText: state.rawText,
    normalizedText: state.normalizedText,
    createdAt: state.createdAt,
    updatedAt: state.updatedAt,
    usedExample: state.usedExample
  };
  if (state.imageUri !== undefined) {
    copied.imageUri = state.imageUri;
  }
  if (state.pendingReport !== undefined) {
    copied.pendingReport = copyReport(state.pendingReport);
  }
  if (state.validationError !== undefined) {
    copied.validationError = copyError(state.validationError);
  }
  return copied;
}

/** Owns exactly one current, process-memory diagnosis session. */
@Observed
export class DiagnosisSessionStore {
  private idGenerator: IdGenerator;
  private timeProvider: TimeProvider;
  private currentValue?: DiagnosisSessionState;
  private fallbackSequence: number = 0;

  constructor(idGenerator: IdGenerator, timeProvider: TimeProvider) {
    this.idGenerator = idGenerator;
    this.timeProvider = timeProvider;
  }

  get currentSession(): DiagnosisSessionState | undefined {
    return this.currentValue === undefined ? undefined : copyDiagnosisSessionState(this.currentValue);
  }

  startNewSession(sourceType: SourceType): DiagnosisSessionState {
    const now = this.timeProvider.now();
    const sessionId = this.nextSessionId(now);
    this.currentValue = {
      sessionId: sessionId,
      sourceType: safeSourceType(sourceType),
      rawText: '',
      normalizedText: '',
      createdAt: now,
      updatedAt: now,
      usedExample: false
    };
    return copyDiagnosisSessionState(this.currentValue);
  }

  findCurrentSession(sessionId: string): DiagnosisSessionState | undefined {
    if (this.currentValue === undefined || sessionId.length === 0 || this.currentValue.sessionId !== sessionId) {
      return undefined;
    }
    return copyDiagnosisSessionState(this.currentValue);
  }

  updateRawText(rawText: string): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.rawText = rawText;
    this.currentValue.normalizedText = '';
    this.currentValue.validationError = undefined;
    this.touch();
    return true;
  }

  setImageUri(imageUri?: string): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.imageUri = imageUri === undefined || imageUri.length === 0 ? undefined : imageUri;
    this.touch();
    return true;
  }

  setValidationSuccess(normalizedText: string): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.normalizedText = normalizedText;
    this.currentValue.validationError = undefined;
    this.touch();
    return true;
  }

  setValidationFailure(error: AppError): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.normalizedText = '';
    this.currentValue.validationError = copyError(error);
    this.touch();
    return true;
  }

  markExampleUsed(): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.usedExample = true;
    this.touch();
    return true;
  }

  setPendingReport(report?: DiagnosisReport): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.pendingReport = report === undefined ? undefined : copyReport(report);
    this.touch();
    return true;
  }

  clearInput(): boolean {
    if (this.currentValue === undefined) {
      return false;
    }
    this.currentValue.rawText = '';
    this.currentValue.normalizedText = '';
    this.currentValue.validationError = undefined;
    this.currentValue.pendingReport = undefined;
    this.currentValue.usedExample = false;
    this.touch();
    return true;
  }

  private touch(): void {
    if (this.currentValue !== undefined) {
      this.currentValue.updatedAt = this.timeProvider.now();
    }
  }

  private nextSessionId(now: number): string {
    this.fallbackSequence++;
    const generated = this.idGenerator.nextId().trim();
    if (generated.length > 0 && generated !== this.currentValue?.sessionId) {
      return generated;
    }
    return `diagnosis-${now}-${this.fallbackSequence}`;
  }
}
