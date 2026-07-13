import homePageSmokeTest from './pages/HomePageSmoke.test';
import databaseManagerInstrumentTest from './repository/DatabaseManager.test';
import reportStoreInstrumentTest from './repository/ReportStore.test';

export default function testsuite() {
  homePageSmokeTest();
  databaseManagerInstrumentTest();
  reportStoreInstrumentTest();
}
