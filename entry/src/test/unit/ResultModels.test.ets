import { describe, expect, it } from '@ohos/hypium';
import { createHttpStatusEntryFixture } from '../fixtures/ModelFixtures';

export default function resultModelsTest() {
  describe('ResultModels', () => {
    it('represents a static HTTP status entry with required arrays', 0, () => {
      const entry = createHttpStatusEntryFixture();

      expect(entry.code).assertEqual(404);
      expect(entry.name).assertEqual('Not Found');
      expect(entry.causes.length).assertEqual(0);
      expect(entry.steps.length).assertEqual(0);
    });
  });
}
