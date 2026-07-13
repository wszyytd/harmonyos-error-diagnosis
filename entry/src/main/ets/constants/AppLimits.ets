/** Minimum number of characters accepted for a diagnosis input. */
export const DIAGNOSIS_INPUT_MIN_CHARACTERS: number = 1;

/** Maximum number of characters accepted for a diagnosis input. */
export const DIAGNOSIS_INPUT_MAX_CHARACTERS: number = 100000;

/** JSON inputs larger than this threshold must expose a processing state. */
export const JSON_LOADING_THRESHOLD_BYTES: number = 50 * 1024;

/** Maximum UTF-8 byte size accepted by the JSON validation tool. */
export const JSON_INPUT_MAX_BYTES: number = 2 * 1024 * 1024;

/** P0 maximum number of locally saved diagnosis reports. */
export const HISTORY_RECORD_LIMIT: number = 200;

/** Inclusive lower bound for an HTTP status code input. */
export const HTTP_STATUS_CODE_MIN: number = 100;

/** Inclusive upper bound for an HTTP status code input. */
export const HTTP_STATUS_CODE_MAX: number = 599;
