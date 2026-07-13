import homePageSmokeTest from './pages/HomePageSmoke.test';
import databaseManagerInstrumentTest from './repository/DatabaseManager.test';
import reportRepositoryInstrumentTest from './repository/ReportRepository.test';
import reportStoreInstrumentTest from './repository/ReportStore.test';

export default function testsuite() {
  homePageSmokeTest();
  databaseManagerInstrumentTest();
  reportRepositoryInstrumentTest();
  reportStoreInstrumentTest();
}
