import { describe, expect, it } from '@ohos/hypium';
import {
  DIAGNOSIS_INPUT_MAX_CHARACTERS,
  DIAGNOSIS_INPUT_MIN_CHARACTERS,
  HISTORY_RECORD_LIMIT,
  HTTP_STATUS_CODE_MAX,
  HTTP_STATUS_CODE_MIN,
  JSON_INPUT_MAX_BYTES,
  JSON_LOADING_THRESHOLD_BYTES
} from '../../main/ets/constants/AppLimits';

export default function appLimitsTest() {
  describe('AppLimits', () => {
    it('matches the documented diagnosis text boundaries', 0, () => {
      expect(DIAGNOSIS_INPUT_MIN_CHARACTERS).assertEqual(1);
      expect(DIAGNOSIS_INPUT_MAX_CHARACTERS).assertEqual(100000);
    });

    it('matches the documented JSON byte boundaries', 0, () => {
      expect(JSON_LOADING_THRESHOLD_BYTES).assertEqual(50 * 1024);
      expect(JSON_INPUT_MAX_BYTES).assertEqual(2 * 1024 * 1024);
    });

    it('matches the documented history and HTTP ranges', 0, () => {
      expect(HISTORY_RECORD_LIMIT).assertEqual(200);
      expect(HTTP_STATUS_CODE_MIN).assertEqual(100);
      expect(HTTP_STATUS_CODE_MAX).assertEqual(599);
    });
  });
}
