import { describe, expect, it } from '@ohos/hypium';
import { SourceType } from '../../main/ets/model/DiagnosisModels';
import { AppRouter } from '../../main/ets/router/AppRouter';
import { RouteName } from '../../main/ets/router/RouteNames';
import { DiagnosisRouteParams } from '../../main/ets/router/RouteModels';
import { FakeNavigationStack } from '../fakes/FakeNavigationStack';

export default function appRouterTest() {
  describe('AppRouter', () => {
    it('opens diagnosis tools and history through one router', 0, () => {
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);

      expect(router.openDiagnosis({
        sourceType: SourceType.TEXT,
        origin: RouteName.HOME
      }).success).assertTrue();
      router.back();
      expect(router.openTools({ origin: RouteName.HOME }).success).assertTrue();
      router.back();
      expect(router.openHistorySettings({ origin: RouteName.HOME }).success).assertTrue();

      expect(stack.paths.length).assertEqual(1);
      expect(stack.paths[0].name).assertEqual(RouteName.HISTORY_SETTINGS);
    });

    it('opens privacy from history and returns to history', 0, () => {
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);
      router.openHistorySettings({ origin: RouteName.HOME });
      router.openPrivacy({ origin: RouteName.HISTORY_SETTINGS });

      expect(stack.paths.length).assertEqual(2);
      expect(stack.paths[1].name).assertEqual(RouteName.PRIVACY);

      router.back();
      expect(stack.paths.length).assertEqual(1);
      expect(stack.paths[0].name).assertEqual(RouteName.HISTORY_SETTINGS);
    });

    it('keeps the source page when invalid report parameters are requested', 0, () => {
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);
      router.openDiagnosis({
        sourceType: SourceType.TEXT,
        origin: RouteName.HOME
      });

      const result = router.openReport({
        sessionId: 'session-1',
        reportId: 'report-1',
        origin: RouteName.DIAGNOSIS
      });

      expect(result.success).assertFalse();
      expect(stack.paths.length).assertEqual(1);
      expect(stack.paths[0].name).assertEqual(RouteName.DIAGNOSIS);
    });

    it('clears the stack for unknown routes', 0, () => {
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);
      router.openTools({ origin: RouteName.HOME });

      const result = router.navigate('not-registered');

      expect(result.success).assertFalse();
      expect(stack.paths.length).assertEqual(0);
      expect(stack.clearCount).assertEqual(1);
    });

    it('does not push the same navigation operation twice', 0, () => {
      const stack = new FakeNavigationStack();
      const router = new AppRouter(stack);
      const params: DiagnosisRouteParams = {
        sourceType: SourceType.IMAGE,
        origin: RouteName.HOME
      };

      router.openDiagnosis(params);
      router.openDiagnosis(params);

      expect(stack.paths.length).assertEqual(1);
    });
  });
}
