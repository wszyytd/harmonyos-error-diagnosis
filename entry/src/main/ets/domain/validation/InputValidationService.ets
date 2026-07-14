import {
  DIAGNOSIS_INPUT_MAX_CHARACTERS,
  DIAGNOSIS_INPUT_MIN_CHARACTERS
} from '../../constants/AppLimits';
import { ErrorCode } from '../../constants/ErrorCodes';
import {
  AppError,
  AppResult,
  createFailureResult,
  createSuccessResult
} from '../../model/ResultModels';
import {
  HiLogService,
  LogLevel,
  LogMetadataKey
} from '../../service/platform/HiLogService';

export const DIAGNOSIS_CHARACTER_COUNTING_UNIT: string = 'UTF16_CODE_UNIT';

export interface ValidatedDiagnosisText {
  normalizedText: string;
  characterCount: number;
  countingUnit: string;
}

function inputError(code: ErrorCode): AppError {
  if (code === ErrorCode.VAL_INPUT_EMPTY) {
    return {
      code: code,
      message: '请输入错误信息。',
      retryable: false,
      causeType: 'DIAGNOSIS_INPUT_EMPTY'
    };
  }
  return {
    code: code,
    message: '错误信息最多支持 100,000 个字符，请缩短后重试。',
    retryable: false,
    causeType: 'DIAGNOSIS_INPUT_TOO_LONG'
  };
}

function lengthRange(characterCount: number): string {
  if (characterCount < DIAGNOSIS_INPUT_MIN_CHARACTERS) {
    return 'empty';
  }
  if (characterCount > DIAGNOSIS_INPUT_MAX_CHARACTERS) {
    return 'over-limit';
  }
  return 'within-limit';
}

/** Pure input normalization and validation boundary for later diagnosis orchestration. */
export class InputValidationService {
  private logger: HiLogService;

  constructor(logger: HiLogService) {
    this.logger = logger;
  }

  validateDiagnosisText(rawText: string): AppResult<ValidatedDiagnosisText> {
    const normalizedText = rawText.trim();
    const characterCount = normalizedText.length;
    if (characterCount < DIAGNOSIS_INPUT_MIN_CHARACTERS) {
      const error = inputError(ErrorCode.VAL_INPUT_EMPTY);
      this.logValidation(characterCount, error.code);
      return createFailureResult<ValidatedDiagnosisText>(error);
    }
    if (characterCount > DIAGNOSIS_INPUT_MAX_CHARACTERS) {
      const error = inputError(ErrorCode.VAL_INPUT_TOO_LONG);
      this.logValidation(characterCount, error.code);
      return createFailureResult<ValidatedDiagnosisText>(error);
    }
    this.logValidation(characterCount);
    return createSuccessResult<ValidatedDiagnosisText>({
      normalizedText: normalizedText,
      characterCount: characterCount,
      countingUnit: DIAGNOSIS_CHARACTER_COUNTING_UNIT
    });
  }

  private logValidation(characterCount: number, errorCode?: string): void {
    this.logger.log(errorCode === undefined ? LogLevel.INFO : LogLevel.WARN, {
      domain: 'diagnosis_validation',
      event: 'input_validated',
      result: errorCode === undefined ? 'success' : 'rejected',
      errorCode: errorCode,
      metadata: [
        { key: LogMetadataKey.STAGE, value: 'input-validation' },
        { key: LogMetadataKey.RECORD_COUNT, value: characterCount },
        { key: LogMetadataKey.TEXT_LENGTH_RANGE, value: lengthRange(characterCount) }
      ]
    });
  }
}
