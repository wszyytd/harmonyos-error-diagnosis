/** Read-only HTTP status metadata loaded from a bundled resource. */
export interface HttpStatusEntry {
  code: number;
  name: string;
  category: string;
  description: string;
  causes: Array<string>;
  steps: Array<string>;
}
