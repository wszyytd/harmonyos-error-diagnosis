import { ErrorCode } from '../../constants/ErrorCodes';
import { DiagnosisRule } from '../../model/DiagnosisModels';
import {
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';

const GENERIC_FALLBACK_RULE_ID: string = 'generic_unclassified';

export interface MatchedDiagnosisRule {
  rule: DiagnosisRule;
  evidence: Array<string>;
}

export interface RuleMatchResult {
  primary: MatchedDiagnosisRule;
  secondary: Array<MatchedDiagnosisRule>;
  usedFallback: boolean;
}

function copyRule(rule: DiagnosisRule): DiagnosisRule {
  const copied: DiagnosisRule = {
    ruleId: rule.ruleId,
    errorType: rule.errorType,
    keywords: rule.keywords.slice(),
    patterns: rule.patterns.slice(),
    priority: rule.priority,
    summaryTemplate: rule.summaryTemplate,
    causes: rule.causes.slice(),
    steps: rule.steps.slice(),
    version: rule.version
  };
  if (rule.riskNotice !== undefined) {
    copied.riskNotice = rule.riskNotice;
  }
  return copied;
}

function copyMatch(match: MatchedDiagnosisRule): MatchedDiagnosisRule {
  return {
    rule: copyRule(match.rule),
    evidence: match.evidence.slice()
  };
}

function diagnosisFailure(causeType: string): AppResult<RuleMatchResult> {
  return createFailureResult<RuleMatchResult>({
    code: ErrorCode.DIAGNOSIS_FAILED,
    message: '本地诊断暂时不可用，请稍后重试。',
    retryable: false,
    causeType: causeType
  });
}

function compareMatches(left: MatchedDiagnosisRule, right: MatchedDiagnosisRule): number {
  if (left.rule.priority !== right.rule.priority) {
    return right.rule.priority - left.rule.priority;
  }
  if (left.rule.ruleId < right.rule.ruleId) {
    return -1;
  }
  if (left.rule.ruleId > right.rule.ruleId) {
    return 1;
  }
  return 0;
}

function hasKeyword(text: string, keywords: Array<string>): boolean {
  const normalizedText = text.toLowerCase();
  for (let index: number = 0; index < keywords.length; index++) {
    if (normalizedText.includes(keywords[index].toLowerCase())) {
      return true;
    }
  }
  return false;
}

function hasPattern(text: string, patterns: Array<string>): boolean {
  for (let index: number = 0; index < patterns.length; index++) {
    const expression = new RegExp(patterns[index], 'i');
    if (expression.test(text)) {
      return true;
    }
  }
  return false;
}

function isFallbackRule(rule: DiagnosisRule): boolean {
  return rule.ruleId === GENERIC_FALLBACK_RULE_ID &&
    rule.keywords.length === 0 && rule.patterns.length === 0;
}

/** Pure, deterministic matcher for already validated local rule resources. */
export class RuleMatcher {
  match(text: string, rules: Array<DiagnosisRule>): AppResult<RuleMatchResult> {
    if (rules.length === 0) {
      return diagnosisFailure('RULE_SET_EMPTY');
    }

    try {
      const specializedMatches: Array<MatchedDiagnosisRule> = [];
      const fallbackRules: Array<DiagnosisRule> = [];
      for (let index: number = 0; index < rules.length; index++) {
        const rule = rules[index];
        if (isFallbackRule(rule)) {
          fallbackRules.push(rule);
          continue;
        }
        if (rule.keywords.length === 0 && rule.patterns.length === 0) {
          return diagnosisFailure('RULE_SET_INVALID');
        }

        const keywordMatched = hasKeyword(text, rule.keywords);
        const patternMatched = hasPattern(text, rule.patterns);
        if (!keywordMatched && !patternMatched) {
          continue;
        }
        const evidence: Array<string> = [];
        if (keywordMatched) {
          evidence.push(`规则 ${rule.ruleId}：关键词信号命中`);
        }
        if (patternMatched) {
          evidence.push(`规则 ${rule.ruleId}：模式信号命中`);
        }
        specializedMatches.push({
          rule: copyRule(rule),
          evidence: evidence
        });
      }

      if (fallbackRules.length > 1) {
        return diagnosisFailure('FALLBACK_RULE_INVALID');
      }
      if (specializedMatches.length === 0) {
        if (fallbackRules.length !== 1) {
          return diagnosisFailure('FALLBACK_RULE_INVALID');
        }
        return createSuccessResult<RuleMatchResult>({
          primary: {
            rule: copyRule(fallbackRules[0]),
            evidence: ['未发现当前规则版本可识别的专用错误信号']
          },
          secondary: [],
          usedFallback: true
        });
      }

      specializedMatches.sort(compareMatches);
      return createSuccessResult<RuleMatchResult>({
        primary: copyMatch(specializedMatches[0]),
        secondary: specializedMatches.slice(1).map(
          (match: MatchedDiagnosisRule): MatchedDiagnosisRule => copyMatch(match)
        ),
        usedFallback: false
      });
    } catch (_) {
      return diagnosisFailure('RULE_MATCH_FAILED');
    }
  }
}
