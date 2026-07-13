import { NavigationStack, RoutePathInfo } from '../../main/ets/router/AppRouter';

export class FakeNavigationStack implements NavigationStack {
  readonly paths: Array<RoutePathInfo> = [];
  clearCount: number = 0;
  popCount: number = 0;

  pushPath(info: RoutePathInfo): void {
    this.paths.push(info);
  }

  pop(): void {
    if (this.paths.length > 0) {
      this.paths.pop();
    }
    this.popCount++;
  }

  popToName(name: string): number {
    for (let index = this.paths.length - 1; index >= 0; index--) {
      if (this.paths[index].name === name) {
        this.paths.splice(index + 1);
        return index;
      }
    }
    return -1;
  }

  clear(): void {
    this.paths.splice(0);
    this.clearCount++;
  }

  getAllPathName(): Array<string> {
    const names: Array<string> = [];
    this.paths.forEach((path: RoutePathInfo): void => {
      names.push(path.name);
    });
    return names;
  }
}
