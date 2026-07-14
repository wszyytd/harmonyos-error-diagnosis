/** Replaceable identifier source used by in-memory diagnosis sessions. */
export interface IdGenerator {
  nextId(): string;
}

let sessionSequence: number = 0;

/** Process-local generator. It creates opaque IDs without reading user or device data. */
export class SystemIdGenerator implements IdGenerator {
  nextId(): string {
    sessionSequence++;
    return `diagnosis-${Date.now()}-${sessionSequence}`;
  }
}
