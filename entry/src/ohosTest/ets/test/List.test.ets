import homePageSmokeTest from './pages/HomePageSmoke.test';
import databaseManagerInstrumentTest from './repository/DatabaseManager.test';

export default function testsuite() {
  homePageSmokeTest();
  databaseManagerInstrumentTest();
}
