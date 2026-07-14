import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { RuleMatcher } from '../../main/ets/domain/diagnosis/RuleMatcher';
import { DiagnosisRule } from '../../main/ets/model/DiagnosisModels';
import {
  createFallbackRuleFixture,
  createRuleFixture
} from '../fixtures/DiagnosisEngineFixtures';

function rulesWithFallback(...rules: Array<DiagnosisRule>): Array<DiagnosisRule> {
  return rules.concat([createFallbackRuleFixture()]);
}

export default function ruleMatcherTest() {
  describe('RuleMatcher', () => {
    it('matches keywords without case sensitivity', 0, () => {
      const matcher = new RuleMatcher();
      const result = matcher.match('REQUEST TIMEOUT', rulesWithFallback(
        createRuleFixture('timeout', '网络超时', 10, ['Timeout'])
      ));

      expect(result.success).assertTrue();
      expect(result.data?.primary.rule.ruleId).assertEqual('timeout');
    });

    it('matches regular expressions without case sensitivity', 0, () => {
      const result = new RuleMatcher().match('code abc-42 failed', rulesWithFallback(
        createRuleFixture('pattern', '模式错误', 10, [], ['ABC-[0-9]+'])
      ));

      expect(result.data?.primary.rule.ruleId).assertEqual('pattern');
    });

    it('records separate keyword and pattern evidence without raw excerpts', 0, () => {
      const raw = 'PRIVATE timeout 408 token=SYNTHETIC_SECRET';
      const result = new RuleMatcher().match(raw, rulesWithFallback(
        createRuleFixture('timeout', '网络超时', 10, ['timeout'], ['\\b408\\b'])
      ));
      const evidence = result.data?.primary.evidence ?? [];

      expect(evidence.length).assertEqual(2);
      expect(JSON.stringify(evidence).includes(raw)).assertFalse();
      expect(JSON.stringify(evidence).includes('SYNTHETIC_SECRET')).assertFalse();
    });

    it('deduplicates repeated keyword evidence for one rule', 0, () => {
      const result = new RuleMatcher().match('timeout timeout', rulesWithFallback(
        createRuleFixture('timeout', '网络超时', 10, ['timeout', 'TIMEOUT'])
      ));

      expect(result.data?.primary.evidence.length).assertEqual(1);
    });

    it('selects the highest numeric priority as primary', 0, () => {
      const result = new RuleMatcher().match('shared', rulesWithFallback(
        createRuleFixture('low', '低优先级', 10, ['shared']),
        createRuleFixture('high', '高优先级', 20, ['shared'])
      ));

      expect(result.data?.primary.rule.ruleId).assertEqual('high');
      expect(result.data?.secondary[0].rule.ruleId).assertEqual('low');
    });

    it('uses ruleId ascending as the same-priority tie breaker', 0, () => {
      const result = new RuleMatcher().match('shared', rulesWithFallback(
        createRuleFixture('z-rule', 'Z', 10, ['shared']),
        createRuleFixture('a-rule', 'A', 10, ['shared'])
      ));

      expect(result.data?.primary.rule.ruleId).assertEqual('a-rule');
    });

    it('is independent from the incoming rule array order', 0, () => {
      const a = createRuleFixture('a-rule', 'A', 10, ['shared']);
      const b = createRuleFixture('b-rule', 'B', 20, ['shared']);
      const matcher = new RuleMatcher();
      const first = matcher.match('shared', rulesWithFallback(a, b));
      const second = matcher.match('shared', rulesWithFallback(b, a));

      expect(first.data?.primary.rule.ruleId).assertEqual(second.data?.primary.rule.ruleId);
      expect(first.data?.secondary[0].rule.ruleId).assertEqual(second.data?.secondary[0].rule.ruleId);
    });

    it('keeps all specialized matches in deterministic secondary order', 0, () => {
      const result = new RuleMatcher().match('shared', rulesWithFallback(
        createRuleFixture('primary', 'P', 30, ['shared']),
        createRuleFixture('secondary-b', 'B', 20, ['shared']),
        createRuleFixture('secondary-a', 'A', 20, ['shared'])
      ));

      expect(result.data?.secondary.map((item) => item.rule.ruleId).join(','))
        .assertEqual('secondary-a,secondary-b');
    });

    it('uses the generic fallback only when no specialized rule matches', 0, () => {
      const result = new RuleMatcher().match('unrecognized synthetic failure', rulesWithFallback(
        createRuleFixture('known', '已知错误', 10, ['known'])
      ));

      expect(result.data?.primary.rule.ruleId).assertEqual('generic_unclassified');
      expect(result.data?.usedFallback).assertTrue();
      expect(result.data?.secondary.length).assertEqual(0);
    });

    it('excludes the generic fallback when a specialized rule matches', 0, () => {
      const result = new RuleMatcher().match('known issue', rulesWithFallback(
        createRuleFixture('known', '已知错误', 10, ['known'])
      ));

      expect(result.data?.usedFallback).assertFalse();
      expect(JSON.stringify(result.data).includes('generic_unclassified')).assertFalse();
    });

    it('fails safely for an empty rule set', 0, () => {
      const result = new RuleMatcher().match('anything', []);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('fails safely when no rule and no generic fallback can produce a report', 0, () => {
      const result = new RuleMatcher().match('opaque failure', [
        createRuleFixture('known', '已知错误', 10, ['known'])
      ]);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('still returns a specialized match when an isolated fallback is absent', 0, () => {
      const result = new RuleMatcher().match('known', [
        createRuleFixture('known', '已知错误', 10, ['known'])
      ]);

      expect(result.success).assertTrue();
      expect(result.data?.primary.rule.ruleId).assertEqual('known');
      expect(result.data?.usedFallback).assertFalse();
    });

    it('fails safely when more than one generic fallback exists', 0, () => {
      const duplicate = createFallbackRuleFixture();
      const result = new RuleMatcher().match('unknown', [createFallbackRuleFixture(), duplicate]);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('maps an invalid regular expression to the stable diagnosis error', 0, () => {
      const result = new RuleMatcher().match('anything', rulesWithFallback(
        createRuleFixture('broken', '损坏规则', 10, [], ['['])
      ));

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('returns isolated rule collections', 0, () => {
      const source = createRuleFixture('known', '已知错误', 10, ['known']);
      const result = new RuleMatcher().match('known', rulesWithFallback(source));
      result.data?.primary.rule.causes.push('caller mutation');

      expect(source.causes.includes('caller mutation')).assertFalse();
    });

    it('does not let one returned match pollute a later match', 0, () => {
      const matcher = new RuleMatcher();
      const rules = rulesWithFallback(createRuleFixture('known', '已知错误', 10, ['known']));
      const first = matcher.match('known', rules);
      first.data?.primary.evidence.push('caller mutation');
      const second = matcher.match('known', rules);

      expect(second.data?.primary.evidence.includes('caller mutation')).assertFalse();
    });
  });
}
