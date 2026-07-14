import { describe, expect, it } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import {
  DiagnosisService,
  LocalDiagnosisService
} from '../../main/ets/domain/diagnosis/DiagnosisService';
import { RuleMatcher } from '../../main/ets/domain/diagnosis/RuleMatcher';
import { DiagnosisRule, SourceType } from '../../main/ets/model/DiagnosisModels';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { CapturingLogSink } from '../fakes/CapturingLogSink';
import { FakeTimeProvider, SequenceIdGenerator } from '../fakes/DiagnosisSessionFakes';
import {
  createClassificationFixtures,
  createDiagnosisInputFixture,
  createDiagnosisRulesFixture,
  createFallbackRuleFixture,
  createRuleFixture,
  DiagnosisClassificationFixture
} from '../fixtures/DiagnosisEngineFixtures';

const REPORT_TIME: number = 1700000001234;

function createService(
  sink: CapturingLogSink = new CapturingLogSink(),
  ids: Array<string> = ['synthetic-report-t16']
): DiagnosisService {
  return new LocalDiagnosisService(
    new RuleMatcher(),
    new SequenceIdGenerator(ids),
    new FakeTimeProvider(REPORT_TIME),
    new HiLogService(sink)
  );
}

export default function diagnosisServiceTest() {
  describe('LocalDiagnosisService', () => {
    const classifications = createClassificationFixtures();
    for (let index: number = 0; index < classifications.length; index++) {
      const fixture: DiagnosisClassificationFixture = classifications[index];
      it(`classifies the ${fixture.name} fixture`, 0, () => {
        const result = createService().diagnose(
          createDiagnosisInputFixture(fixture.text),
          createDiagnosisRulesFixture()
        );

        expect(result.success).assertTrue();
        expect(result.data?.errorType).assertEqual(fixture.errorType);
      });
    }

    it('creates primary and unique secondary tags from all specialized matches', 0, () => {
      const result = createService().diagnose(
        createDiagnosisInputFixture('ArkTS:ERROR BUILD FAILED undefined'),
        createDiagnosisRulesFixture()
      );

      expect(result.data?.errorType).assertEqual('ArkTS编译错误');
      expect(result.data?.secondaryTags?.join(',')).assertEqual('Hvigor构建错误,空值错误');
    });

    it('deduplicates secondary tags while retaining deterministic match order', 0, () => {
      const rules = [
        createRuleFixture('primary', '主要错误', 30, ['shared']),
        createRuleFixture('secondary-b', '重复标签', 20, ['shared']),
        createRuleFixture('secondary-a', '重复标签', 20, ['shared']),
        createRuleFixture('secondary-c', '其他标签', 10, ['shared']),
        createFallbackRuleFixture()
      ];
      const result = createService().diagnose(createDiagnosisInputFixture('shared'), rules);

      expect(result.data?.secondaryTags?.join(',')).assertEqual('重复标签,其他标签');
    });

    it('fills the complete core report from the primary rule', 0, () => {
      const result = createService().diagnose(
        createDiagnosisInputFixture('SyntaxError: Unexpected token } in JSON.parse'),
        createDiagnosisRulesFixture()
      );
      const report = result.data;

      expect(report?.id).assertEqual('synthetic-report-t16');
      expect((report?.summary ?? '').length > 0).assertTrue();
      expect((report?.evidence ?? []).length > 0).assertTrue();
      expect((report?.possibleCauses ?? []).length >= 2).assertTrue();
      expect((report?.steps ?? []).length >= 3).assertTrue();
      expect((report?.riskNotice ?? '').length > 0).assertTrue();
    });

    it('uses injected ID and Unix-millisecond time capabilities', 0, () => {
      const result = createService(new CapturingLogSink(), ['fixed-report-id']).diagnose(
        createDiagnosisInputFixture('timeout'),
        createDiagnosisRulesFixture()
      );

      expect(result.data?.id).assertEqual('fixed-report-id');
      expect(result.data?.createdAt).assertEqual(REPORT_TIME);
    });

    it('preserves normalized input and TEXT source without copying a session ID', 0, () => {
      const text = 'normalized\n  log structure';
      const result = createService().diagnose(
        createDiagnosisInputFixture(text),
        createDiagnosisRulesFixture()
      );

      expect(result.data?.rawText).assertEqual(text);
      expect(result.data?.sourceType).assertEqual(SourceType.TEXT);
      expect(JSON.stringify(result.data).includes('synthetic-session-t16')).assertFalse();
    });

    it('preserves IMAGE source but never copies imageUri into the report', 0, () => {
      const result = createService().diagnose(
        createDiagnosisInputFixture('permission denied', SourceType.IMAGE),
        createDiagnosisRulesFixture()
      );

      expect(result.data?.sourceType).assertEqual(SourceType.IMAGE);
      expect(JSON.stringify(result.data).includes('photo://')).assertFalse();
    });

    it('creates an unsaved non-favorite report with absent optional suggestions', 0, () => {
      const result = createService().diagnose(
        createDiagnosisInputFixture('404 Not Found'),
        createDiagnosisRulesFixture()
      );

      expect(result.data?.savedAt).assertUndefined();
      expect(result.data?.isFavorite).assertFalse();
      expect(result.data?.suggestions).assertUndefined();
    });

    it('writes the actual loaded rule version into engineVersion', 0, () => {
      const rules = createDiagnosisRulesFixture();
      const result = createService().diagnose(createDiagnosisInputFixture('timeout'), rules);

      expect(result.data?.engineVersion).assertEqual(rules[0].version);
    });

    it('returns a cautious successful generic report for an unknown error', 0, () => {
      const result = createService().diagnose(
        createDiagnosisInputFixture('synthetic unrecognized failure'),
        createDiagnosisRulesFixture()
      );

      expect(result.success).assertTrue();
      expect(result.data?.errorType).assertEqual('通用错误');
      expect(result.data?.summary.includes('不能确定')).assertTrue();
      expect(result.data?.riskNotice?.includes('不代表已经确定根因')).assertTrue();
    });

    it('returns isolated report arrays without changing caller rules', 0, () => {
      const rules = createDiagnosisRulesFixture();
      const originalCauseCount = rules[0].causes.length;
      const result = createService().diagnose(
        createDiagnosisInputFixture('JSON.parse failed'),
        rules
      );
      result.data?.possibleCauses.push('caller mutation');
      result.data?.steps.push('caller step');

      expect(rules[0].causes.length).assertEqual(originalCauseCount);
      expect(rules[0].causes.includes('caller mutation')).assertFalse();
    });

    it('keeps diagnosis content deterministic apart from injected identity and time', 0, () => {
      const rules = createDiagnosisRulesFixture();
      const service = createService(new CapturingLogSink(), ['report-one', 'report-two']);
      const first = service.diagnose(createDiagnosisInputFixture('timeout 404'), rules);
      const second = service.diagnose(createDiagnosisInputFixture('timeout 404'), rules.slice().reverse());

      expect(first.data?.errorType).assertEqual(second.data?.errorType);
      expect(first.data?.secondaryTags?.join(',')).assertEqual(second.data?.secondaryTags?.join(','));
      expect(first.data?.summary).assertEqual(second.data?.summary);
      expect(first.data?.evidence.join(',')).assertEqual(second.data?.evidence.join(','));
    });

    it('fails with DIAGNOSIS_FAILED when the generated report ID is empty', 0, () => {
      const result = createService(new CapturingLogSink(), ['   ']).diagnose(
        createDiagnosisInputFixture('timeout'),
        createDiagnosisRulesFixture()
      );

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('fails with DIAGNOSIS_FAILED when the generated time is invalid', 0, () => {
      const service = new LocalDiagnosisService(
        new RuleMatcher(),
        new SequenceIdGenerator(['report']),
        new FakeTimeProvider(-1),
        new HiLogService(new CapturingLogSink())
      );
      const result = service.diagnose(createDiagnosisInputFixture('timeout'), createDiagnosisRulesFixture());

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('fails when rules contain inconsistent engine versions', 0, () => {
      const rules = createDiagnosisRulesFixture();
      rules[1].version = '2.0.0';
      const result = createService().diagnose(createDiagnosisInputFixture('timeout'), rules);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
    });

    it('forwards empty and unusable rule-set failures safely', 0, () => {
      const result = createService().diagnose(createDiagnosisInputFixture('anything'), []);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.DIAGNOSIS_FAILED);
      expect(result.error?.message).assertEqual('本地诊断暂时不可用，请稍后重试。');
    });

    it('does not log raw text imageUri credentials or rule evidence', 0, () => {
      const sink = new CapturingLogSink();
      const raw = 'D:\\Users\\private\\project timeout token=SYNTHETIC_TOKEN ' +
        'password=SYNTHETIC_PASSWORD private@example.com 13800138000';
      createService(sink).diagnose(
        createDiagnosisInputFixture(raw, SourceType.IMAGE),
        createDiagnosisRulesFixture()
      );
      const serialized = JSON.stringify(sink.records);

      expect(sink.records.length > 0).assertTrue();
      expect(serialized.includes(raw)).assertFalse();
      expect(serialized.includes('SYNTHETIC_TOKEN')).assertFalse();
      expect(serialized.includes('SYNTHETIC_PASSWORD')).assertFalse();
      expect(serialized.includes('photo://')).assertFalse();
      expect(serialized.includes('private@example.com')).assertFalse();
      expect(serialized.includes('13800138000')).assertFalse();
      expect(serialized.includes('命中')).assertFalse();
    });

    it('keeps evidence short even when the original log is very long', 0, () => {
      const raw = `timeout ${'private log line\n'.repeat(1000)}`;
      const result = createService().diagnose(
        createDiagnosisInputFixture(raw),
        createDiagnosisRulesFixture()
      );
      const evidence = result.data?.evidence ?? [];

      expect(JSON.stringify(evidence).includes(raw)).assertFalse();
      expect(JSON.stringify(evidence).length < 500).assertTrue();
    });

    it('does not mutate the input or rules after a failed diagnosis', 0, () => {
      const input = createDiagnosisInputFixture('timeout', SourceType.IMAGE);
      const rules: Array<DiagnosisRule> = createDiagnosisRulesFixture();
      const beforeInput = JSON.stringify(input);
      const beforeRules = JSON.stringify(rules);
      createService(new CapturingLogSink(), ['']).diagnose(input, rules);

      expect(JSON.stringify(input)).assertEqual(beforeInput);
      expect(JSON.stringify(rules)).assertEqual(beforeRules);
    });
  });
}
