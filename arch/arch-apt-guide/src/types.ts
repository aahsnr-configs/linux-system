// src/types.ts

export interface Section {
  id: string;
  title: string;
  content: string;
}

// 0 = TODO, 1 = IN PROGRESS, 2 = DONE
export type TaskState = 0 | 1 | 2;

// Tracks the state of tasks.
// Keys are generated from section ID + heading text (e.g., "2-verify-drives")
export interface ProgressState {
  [key: string]: TaskState;
}
