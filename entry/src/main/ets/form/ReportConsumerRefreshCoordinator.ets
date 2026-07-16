export type ReportConsumerRefreshAction = () => Promise<boolean>;

/** Refreshes app and Form projections without coupling their failure outcomes. */
export class ReportConsumerRefreshCoordinator {
  private refreshHome: ReportConsumerRefreshAction;
  private refreshForm: ReportConsumerRefreshAction;

  constructor(
    refreshHome: ReportConsumerRefreshAction,
    refreshForm: ReportConsumerRefreshAction
  ) {
    this.refreshHome = refreshHome;
    this.refreshForm = refreshForm;
  }

  async refresh(): Promise<boolean> {
    let homeResult: boolean = false;
    try {
      homeResult = await this.refreshHome();
    } catch (_) {
      homeResult = false;
    }
    try {
      await this.refreshForm();
    } catch (_) {
    }
    return homeResult;
  }
}
