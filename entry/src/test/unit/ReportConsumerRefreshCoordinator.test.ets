import { describe, expect, it } from '@ohos/hypium';
import {
  ReportConsumerRefreshCoordinator
} from '../../main/ets/form/ReportConsumerRefreshCoordinator';

export default function reportConsumerRefreshCoordinatorTest() {
  describe('ReportConsumerRefreshCoordinator', () => {
    it('refreshes home and Form while returning the home result', 0, async () => {
      let homeCount: number = 0;
      let formCount: number = 0;
      const coordinator = new ReportConsumerRefreshCoordinator(
        async (): Promise<boolean> => {
          homeCount++;
          return true;
        },
        async (): Promise<boolean> => {
          formCount++;
          return false;
        }
      );

      expect(await coordinator.refresh()).assertTrue();
      expect(homeCount).assertEqual(1);
      expect(formCount).assertEqual(1);
    });

    it('contains Form refresh exceptions after refreshing home', 0, async () => {
      const coordinator = new ReportConsumerRefreshCoordinator(
        async (): Promise<boolean> => true,
        async (): Promise<boolean> => {
          throw new Error('Synthetic Form refresh failure');
        }
      );

      expect(await coordinator.refresh()).assertTrue();
    });

    it('still refreshes Form when home refresh fails', 0, async () => {
      let formCount: number = 0;
      const coordinator = new ReportConsumerRefreshCoordinator(
        async (): Promise<boolean> => {
          throw new Error('Synthetic home refresh failure');
        },
        async (): Promise<boolean> => {
          formCount++;
          return true;
        }
      );

      expect(await coordinator.refresh()).assertFalse();
      expect(formCount).assertEqual(1);
    });
  });
}
