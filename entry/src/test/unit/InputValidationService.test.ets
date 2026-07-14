import { describe, expect, it } from '@ohos/hypium';
import { DIAGNOSIS_INPUT_MAX_CHARACTERS } from '../../main/ets/constants/AppLimits';
import { ErrorCode } from '../../main/ets/constants/ErrorCodes';
import { InputValidationService } from '../../main/ets/domain/validation/InputValidationService';
import { HiLogService } from '../../main/ets/service/platform/HiLogService';
import { CapturingLogSink } from '../fakes/CapturingLogSink';

function createService(sink: CapturingLogSink = new CapturingLogSink()): InputValidationService {
  return new InputValidationService(new HiLogService(sink));
}

export default function inputValidationServiceTest() {
  describe('InputValidationService', () => {
    it('rejects an empty string with the stable empty-input error', 0, () => {
      const result = createService().validateDiagnosisText('');

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_EMPTY);
      expect(result.error?.message).assertEqual('请输入错误信息。');
    });

    it('rejects spaces without changing the supplied text', 0, () => {
      const raw = '     ';
      const result = createService().validateDiagnosisText(raw);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_EMPTY);
      expect(raw).assertEqual('     ');
    });

    it('rejects tabs newlines and carriage returns as all-whitespace input', 0, () => {
      const result = createService().validateDiagnosisText('\t\n\r\n\t');

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_EMPTY);
    });

    it('accepts exactly one normalized UTF-16 code unit', 0, () => {
      const result = createService().validateDiagnosisText(' A ');

      expect(result.success).assertTrue();
      expect(result.data?.normalizedText).assertEqual('A');
      expect(result.data?.characterCount).assertEqual(1);
    });

    it('accepts exactly 100000 normalized UTF-16 code units', 0, () => {
      const text = 'A'.repeat(DIAGNOSIS_INPUT_MAX_CHARACTERS);
      const result = createService().validateDiagnosisText(text);

      expect(result.success).assertTrue();
      expect(result.data?.characterCount).assertEqual(100000);
    });

    it('rejects 100001 normalized UTF-16 code units and returns the length error', 0, () => {
      const text = 'A'.repeat(DIAGNOSIS_INPUT_MAX_CHARACTERS + 1);
      const result = createService().validateDiagnosisText(text);

      expect(result.success).assertFalse();
      expect(result.error?.code).assertEqual(ErrorCode.VAL_INPUT_TOO_LONG);
      expect(result.error?.message.includes('100,000')).assertTrue();
    });

    it('removes only leading and trailing whitespace at submission', 0, () => {
      const result = createService().validateDiagnosisText('  error message \n');

      expect(result.success).assertTrue();
      expect(result.data?.normalizedText).assertEqual('error message');
    });

    it('preserves internal spaces newlines and indentation', 0, () => {
      const raw = ' \nline  one\n    indented\tvalue\n ';
      const result = createService().validateDiagnosisText(raw);

      expect(result.success).assertTrue();
      expect(result.data?.normalizedText).assertEqual('line  one\n    indented\tvalue');
    });

    it('uses ArkTS string UTF-16 counting for Chinese English newlines and emoji', 0, () => {
      const result = createService().validateDiagnosisText('中A\n😀');

      expect(result.success).assertTrue();
      expect(result.data?.characterCount).assertEqual(5);
      expect(result.data?.countingUnit).assertEqual('UTF16_CODE_UNIT');
    });

    it('logs only safe stage count range and error code metadata', 0, () => {
      const sink = new CapturingLogSink();
      const raw = 'PRIVATE_INPUT Token=secret photo://private/image';
      createService(sink).validateDiagnosisText(raw);
      const serialized = JSON.stringify(sink.records);

      expect(sink.records.length).assertEqual(1);
      expect(serialized.includes(raw)).assertFalse();
      expect(serialized.includes('photo://private/image')).assertFalse();
      expect(serialized.includes('secret')).assertFalse();
      expect(sink.records[0].metadata.some((item) => item.key === 'recordCount')).assertTrue();
    });
  });
}
