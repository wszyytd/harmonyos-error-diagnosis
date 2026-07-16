import { describe, expect, it } from '@ohos/hypium';
import {
  beginFavoriteToggle,
  completeFavoriteToggle,
  FavoriteToggleTransition
} from '../../main/ets/components/common/FavoriteActionModels';

export default function favoriteActionModelsTest() {
  describe('FavoriteActionModels', () => {
    it('publishes the opposite favorite state as soon as a toggle begins', 0, () => {
      const favorite: FavoriteToggleTransition = beginFavoriteToggle(false);
      const unfavorite: FavoriteToggleTransition = beginFavoriteToggle(true);

      expect(favorite.previousValue).assertFalse();
      expect(favorite.pendingValue).assertTrue();
      expect(unfavorite.previousValue).assertTrue();
      expect(unfavorite.pendingValue).assertFalse();
    });

    it('keeps the pending state on success and rolls back on failure', 0, () => {
      const transition: FavoriteToggleTransition = beginFavoriteToggle(false);

      expect(completeFavoriteToggle(transition, true)).assertTrue();
      expect(completeFavoriteToggle(transition, false)).assertFalse();
    });
  });
}
