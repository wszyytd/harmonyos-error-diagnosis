import diagnosisRuleResource from '../../main/resources/rawfile/diagnosis_rules_v1.json';
import {
  DiagnosisInput,
  DiagnosisRule,
  SourceType
} from '../../main/ets/model/DiagnosisModels';

interface DiagnosisRuleResourceFixture {
  schemaName: string;
  schemaVersion: number;
  resourceVersion: string;
  rules: Array<DiagnosisRule>;
}

export interface DiagnosisClassificationFixture {
  name: string;
  text: string;
  errorType: string;
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

export function createDiagnosisRulesFixture(): Array<DiagnosisRule> {
  const resource: DiagnosisRuleResourceFixture = diagnosisRuleResource;
  return resource.rules.map((rule: DiagnosisRule): DiagnosisRule => copyRule(rule));
}

export function createRuleFixture(
  ruleId: string,
  errorType: string,
  priority: number,
  keywords: Array<string> = [],
  patterns: Array<string> = []
): DiagnosisRule {
  return {
    ruleId: ruleId,
    errorType: errorType,
    keywords: keywords.slice(),
    patterns: patterns.slice(),
    priority: priority,
    summaryTemplate: `${errorType}的安全摘要。`,
    causes: [`${errorType}的可能原因。`],
    steps: [`检查${errorType}的首个失败位置。`],
    riskNotice: `${errorType}仅供本地排查参考。`,
    version: '1.0.0'
  };
}

export function createFallbackRuleFixture(): DiagnosisRule {
  return createRuleFixture('generic_unclassified', '通用错误', 0);
}

export function createDiagnosisInputFixture(
  rawText: string,
  sourceType: SourceType = SourceType.TEXT
): DiagnosisInput {
  const input: DiagnosisInput = {
    sessionId: 'synthetic-session-t16',
    sourceType: sourceType,
    rawText: rawText,
    createdAt: 1700000000000
  };
  if (sourceType === SourceType.IMAGE) {
    input.imageUri = 'photo://synthetic/private-image';
  }
  return input;
}

export function createClassificationFixtures(): Array<DiagnosisClassificationFixture> {
  return [
    { name: 'JSON', text: 'SyntaxError: Unexpected token } in JSON.parse', errorType: 'JSON解析错误' },
    { name: 'HTTP 401', text: 'Request failed with 401 Unauthorized', errorType: 'HTTP认证错误' },
    { name: 'HTTP 403', text: 'Request failed with 403 Forbidden', errorType: 'HTTP权限错误' },
    { name: 'HTTP 404', text: 'Request failed with 404 Not Found', errorType: 'HTTP资源错误' },
    { name: 'HTTP 500', text: 'Request failed with 500 Internal Server Error', errorType: 'HTTP服务错误' },
    { name: 'HTTP 502', text: 'Request failed with 502 Bad Gateway', errorType: 'HTTP服务错误' },
    { name: 'HTTP 503', text: 'Request failed with 503 Service Unavailable', errorType: 'HTTP服务错误' },
    { name: 'timeout', text: 'Connection TIMED OUT while requesting data', errorType: '网络超时' },
    { name: 'permission', text: 'Permission denied: capability is not granted', errorType: '权限错误' },
    { name: 'null', text: 'Cannot read property name of undefined', errorType: '空值错误' },
    { name: 'ArkTS', text: 'ArkTS:ERROR arkts-no-type-query', errorType: 'ArkTS编译错误' },
    { name: 'Hvigor', text: 'hvigor ERROR: assembleHap BUILD FAILED', errorType: 'Hvigor构建错误' },
    { name: 'OHPM', text: 'ohpm ERROR: Fetch Pkg Info Failed 00608005', errorType: 'OHPM依赖错误' }
  ];
}
