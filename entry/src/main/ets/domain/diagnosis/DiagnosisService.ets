import { ErrorCode } from '../../constants/ErrorCodes';
import {
  MatchedDiagnosisRule,
  RuleMatcher,
  RuleMatchResult
} from './RuleMatcher';
import {
  DiagnosisInput,
  DiagnosisReport,
  DiagnosisRule,
  SourceType
} from '../../model/DiagnosisModels';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';
import {
  HiLogService,
  LogLevel,
  LogMetadataItem,
  LogMetadataKey
} from '../../service/platform/HiLogService';
import { IdGenerator } from '../../utils/IdGenerator';
import { TimeProvider } from '../../utils/TimeProvider';

export interface DiagnosisService {
  diagnose(input: DiagnosisInput, rules: Array<DiagnosisRule>): AppResult<DiagnosisReport>;
}

function diagnosisFailure(causeType: string): AppResult<DiagnosisReport> {
  return createFailureResult<DiagnosisReport>({
    code: ErrorCode.DIAGNOSIS_FAILED,
    message: '本地诊断暂时不可用，请稍后重试。',
    retryable: false,
    causeType: causeType
  });
}

function isValidInput(input: DiagnosisInput): boolean {
  return input.sessionId.trim().length > 0 && input.rawText.trim().length > 0 &&
    (input.sourceType === SourceType.TEXT || input.sourceType === SourceType.IMAGE);
}

function engineVersionOf(rules: Array<DiagnosisRule>): string | undefined {
  if (rules.length === 0 || rules[0].version.trim().length === 0) {
    return undefined;
  }
  const version = rules[0].version;
  for (let index: number = 1; index < rules.length; index++) {
    if (rules[index].version !== version) {
      return undefined;
    }
  }
  return version;
}

function secondaryTagsOf(matches: Array<MatchedDiagnosisRule>): Array<string> {
  const tags: Array<string> = [];
  for (let index: number = 0; index < matches.length; index++) {
    const tag = matches[index].rule.errorType;
    if (!tags.includes(tag)) {
      tags.push(tag);
    }
  }
  return tags;
}

function evidenceOf(matchResult: RuleMatchResult): Array<string> {
  const evidence: Array<string> = matchResult.primary.evidence.slice();
  for (let index: number = 0; index < matchResult.secondary.length; index++) {
    const secondaryEvidence = matchResult.secondary[index].evidence;
    for (let evidenceIndex: number = 0; evidenceIndex < secondaryEvidence.length; evidenceIndex++) {
      if (!evidence.includes(secondaryEvidence[evidenceIndex])) {
        evidence.push(secondaryEvidence[evidenceIndex]);
      }
    }
  }
  return evidence;
}

/** Pure local report generator. Resource loading and persistence stay outside this boundary. */
export class LocalDiagnosisService implements DiagnosisService {
  private matcher: RuleMatcher;
  private idGenerator: IdGenerator;
  private timeProvider: TimeProvider;
  private logger: HiLogService;

  constructor(
    matcher: RuleMatcher,
    idGenerator: IdGenerator,
    timeProvider: TimeProvider,
    logger: HiLogService
  ) {
    this.matcher = matcher;
    this.idGenerator = idGenerator;
    this.timeProvider = timeProvider;
    this.logger = logger;
  }

  diagnose(input: DiagnosisInput, rules: Array<DiagnosisRule>): AppResult<DiagnosisReport> {
    try {
      if (!isValidInput(input)) {
        return this.failure('INPUT_INVALID');
      }
      const engineVersion = engineVersionOf(rules);
      if (engineVersion === undefined) {
        return this.failure(rules.length === 0 ? 'RULE_SET_EMPTY' : 'RULE_VERSION_INVALID');
      }

      const matchResult = this.matcher.match(input.rawText, rules);
      if (!matchResult.success || matchResult.data === undefined) {
        return this.failure(matchResult.error?.causeType ?? 'RULE_MATCH_FAILED');
      }
      const reportId = this.idGenerator.nextId().trim();
      const createdAt = this.timeProvider.now();
      if (reportId.length === 0 || !Number.isFinite(createdAt) || !Number.isInteger(createdAt) || createdAt < 0) {
        return this.failure('REPORT_IDENTITY_INVALID');
      }

      const primaryRule = matchResult.data.primary.rule;
      const secondaryTags = secondaryTagsOf(matchResult.data.secondary);
      const report: DiagnosisReport = {
        id: reportId,
        errorType: primaryRule.errorType,
        summary: primaryRule.summaryTemplate,
        evidence: evidenceOf(matchResult.data),
        possibleCauses: primaryRule.causes.slice(),
        steps: primaryRule.steps.slice(),
        rawText: input.rawText,
        sourceType: input.sourceType,
        createdAt: createdAt,
        isFavorite: false,
        engineVersion: engineVersion
      };
      if (secondaryTags.length > 0) {
        report.secondaryTags = secondaryTags;
      }
      if (primaryRule.riskNotice !== undefined) {
        report.riskNotice = primaryRule.riskNotice;
      }

      this.logResult(LogLevel.INFO, 'success', engineVersion, 1 + matchResult.data.secondary.length,
        matchResult.data.usedFallback ? 'fallback' : 'specialized');
      return createSuccessResult<DiagnosisReport>(report);
    } catch (_) {
      return this.failure('DIAGNOSIS_INTERNAL');
    }
  }

  private failure(causeType: string): AppResult<DiagnosisReport> {
    this.logResult(LogLevel.ERROR, 'failure', undefined, 0, 'failed', ErrorCode.DIAGNOSIS_FAILED);
    return diagnosisFailure(causeType);
  }

  private logResult(
    level: LogLevel,
    result: string,
    version: string | undefined,
    matchedRuleCount: number,
    stage: string,
    errorCode?: string
  ): void {
    try {
      const metadata: Array<LogMetadataItem> = [
        { key: LogMetadataKey.STAGE, value: stage },
        { key: LogMetadataKey.RECORD_COUNT, value: matchedRuleCount }
      ];
      if (version !== undefined) {
        metadata.push({ key: LogMetadataKey.RULE_VERSION, value: version });
      }
      this.logger.log(level, {
        domain: 'diagnosis_engine',
        event: 'diagnosis_completed',
        result: result,
        errorCode: errorCode,
        metadata: metadata
      });
    } catch (_) {
      // Logging is best effort and must never alter the diagnosis result.
    }
  }
}
