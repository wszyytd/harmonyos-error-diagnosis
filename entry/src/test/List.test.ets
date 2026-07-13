import appLimitsTest from './unit/AppLimits.test';
import diagnosisModelsTest from './unit/DiagnosisModels.test';
import resultModelsTest from './unit/ResultModels.test';
import settingsModelsTest from './unit/SettingsModels.test';
import testFixtureTest from './unit/TestFixture.test';

export default function testsuite() {
  appLimitsTest();
  diagnosisModelsTest();
  resultModelsTest();
  settingsModelsTest();
  testFixtureTest();
}
