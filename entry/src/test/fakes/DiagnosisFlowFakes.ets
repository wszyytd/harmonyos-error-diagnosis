import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import {
  DiagnosisInput,
  DiagnosisReport,
  DiagnosisRule
} from '../../main/ets/model/DiagnosisModels';
import { DiagnosisService } from '../../main/ets/domain/diagnosis/DiagnosisService';
import {
  AppResult,
  createFailureResult,
  createSuccessResult,
  HttpStatusEntry
} from '../../main/ets/model/ResultModels';
import { StaticContentRepository } from '../../main/ets/repository/static/StaticContentRepository';

function copyRules(rules: Array<DiagnosisRule>): Array<DiagnosisRule> {
  return rules.map((rule: DiagnosisRule): DiagnosisRule => {
    const copy: DiagnosisRule = {
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
      copy.riskNotice = rule.riskNotice;
    }
    return copy;
  });
}

export class SuccessfulStaticContentRepository implements StaticContentRepository {
  loadRulesCount: number = 0;
  private rules: Array<DiagnosisRule>;

  constructor(rules: Array<DiagnosisRule>) {
    this.rules = copyRules(rules);
  }

  loadDiagnosisRules(): Promise<AppResult<Array<DiagnosisRule>>> {
    this.loadRulesCount++;
    return Promise.resolve(createSuccessResult<Array<DiagnosisRule>>(copyRules(this.rules)));
  }

  getHttpStatus(_code: number): Promise<AppResult<HttpStatusEntry>> {
    return Promise.resolve(createFailureResult<HttpStatusEntry>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供 HTTP 状态资料。',
      retryable: false
    }));
  }

  getPrivacyText(): Promise<AppResult<string>> {
    return Promise.resolve(createFailureResult<string>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供隐私文本。',
      retryable: false
    }));
  }
}

export class FailingStaticContentRepository implements StaticContentRepository {
  loadRulesCount: number = 0;

  loadDiagnosisRules(): Promise<AppResult<Array<DiagnosisRule>>> {
    this.loadRulesCount++;
    return Promise.resolve(createFailureResult<Array<DiagnosisRule>>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '内置诊断规则暂时不可用。',
      retryable: true,
      causeType: 'SYNTHETIC_RULE_FAILURE'
    }));
  }

  getHttpStatus(_code: number): Promise<AppResult<HttpStatusEntry>> {
    return Promise.resolve(createFailureResult<HttpStatusEntry>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供 HTTP 状态资料。',
      retryable: false
    }));
  }

  getPrivacyText(): Promise<AppResult<string>> {
    return Promise.resolve(createFailureResult<string>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供隐私文本。',
      retryable: false
    }));
  }
}

export class ControlledStaticContentRepository implements StaticContentRepository {
  loadRulesCount: number = 0;
  private completion?: (result: AppResult<Array<DiagnosisRule>>) => void;

  loadDiagnosisRules(): Promise<AppResult<Array<DiagnosisRule>>> {
    this.loadRulesCount++;
    return new Promise<AppResult<Array<DiagnosisRule>>>((resolve) => {
      this.completion = resolve;
    });
  }

  succeed(rules: Array<DiagnosisRule>): void {
    this.completion?.(createSuccessResult<Array<DiagnosisRule>>(copyRules(rules)));
  }

  getHttpStatus(_code: number): Promise<AppResult<HttpStatusEntry>> {
    return Promise.resolve(createFailureResult<HttpStatusEntry>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供 HTTP 状态资料。',
      retryable: false
    }));
  }

  getPrivacyText(): Promise<AppResult<string>> {
    return Promise.resolve(createFailureResult<string>({
      code: ErrorCode.RULE_RESOURCE_FAILED,
      message: '测试替身不提供隐私文本。',
      retryable: false
    }));
  }
}

export class FailingDiagnosisService implements DiagnosisService {
  diagnoseCount: number = 0;

  diagnose(_input: DiagnosisInput, _rules: Array<DiagnosisRule>): AppResult<DiagnosisReport> {
    this.diagnoseCount++;
    return createFailureResult<DiagnosisReport>({
      code: ErrorCode.DIAGNOSIS_FAILED,
      message: '本地诊断暂时不可用，请稍后重试。',
      retryable: true,
      causeType: 'SYNTHETIC_ENGINE_FAILURE'
    });
  }
}
