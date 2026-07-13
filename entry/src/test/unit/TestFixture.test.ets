import { describe, expect, it } from '@ohos/hypium';
import { createArktsTypeErrorFixture } from '../fixtures/TextFixtures';

export default function testFixtureTest() {
  describe('TestFixture', () => {
    it('creates a synthetic ArkTS error with stable metadata', 0, () => {
      const fixture = createArktsTypeErrorFixture();

      expect(fixture.id).assertEqual('arkts-type-mismatch');
      expect(fixture.source).assertEqual('synthetic');
      expect(fixture.content).assertContain('ArkTS:ERROR');
      expect(fixture.content).assertContain("Type 'string' is not assignable to type 'number'");
    });

    it('returns independent fixture instances', 0, () => {
      const first = createArktsTypeErrorFixture();
      const second = createArktsTypeErrorFixture();

      first.content = 'changed by one test';

      expect(second.content).assertContain('ArkTS:ERROR');
      expect(second.content === first.content).assertFalse();
    });
  });
}
