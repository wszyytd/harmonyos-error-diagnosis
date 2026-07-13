import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  LogLevel,
  LogRecord,
  LogSink
} from './HiLogService';

const DOMAIN: number = 0x0000;
const TAG: string = 'AppState';

/** Emits only records already filtered by HiLogService. */
export class HarmonyHiLogSink implements LogSink {
  write(record: LogRecord): void {
    const serialized = JSON.stringify(record);
    if (record.level === LogLevel.ERROR) {
      hilog.error(DOMAIN, TAG, '%{public}s', serialized);
    } else if (record.level === LogLevel.WARN) {
      hilog.warn(DOMAIN, TAG, '%{public}s', serialized);
    } else if (record.level === LogLevel.DEBUG) {
      hilog.debug(DOMAIN, TAG, '%{public}s', serialized);
    } else {
      hilog.info(DOMAIN, TAG, '%{public}s', serialized);
    }
  }
}
