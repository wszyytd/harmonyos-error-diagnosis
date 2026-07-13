export interface SyntheticTextFixture {
  readonly id: string;
  readonly source: string;
  content: string;
}

export function createArktsTypeErrorFixture(): SyntheticTextFixture {
  return {
    id: 'arkts-type-mismatch',
    source: 'synthetic',
    content: "ArkTS:ERROR Type 'string' is not assignable to type 'number'"
  };
}
