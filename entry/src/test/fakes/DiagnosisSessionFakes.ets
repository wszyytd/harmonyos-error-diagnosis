import { IdGenerator } from '../../main/ets/utils/IdGenerator';
import { TimeProvider } from '../../main/ets/utils/TimeProvider';

export class SequenceIdGenerator implements IdGenerator {
  private ids: Array<string>;
  private index: number = 0;

  constructor(ids: Array<string>) {
    this.ids = ids.slice();
  }

  nextId(): string {
    const id = this.ids[this.index] ?? `synthetic-session-${this.index}`;
    this.index++;
    return id;
  }
}

export class FakeTimeProvider implements TimeProvider {
  value: number;

  constructor(value: number) {
    this.value = value;
  }

  now(): number {
    return this.value;
  }
}
