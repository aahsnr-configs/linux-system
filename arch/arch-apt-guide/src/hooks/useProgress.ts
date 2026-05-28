import { useState, useEffect, useCallback } from "react";
import { ProgressState, TaskState } from "../types";

const STORAGE_KEY = "gentoo-apt-guide-progress-v3"; // Changed key to reset old boolean state

export const useProgress = () => {
  const [progress, setProgress] = useState<ProgressState>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      return saved ? JSON.parse(saved) : {};
    } catch (error) {
      console.error("Failed to read progress from localStorage", error);
      return {};
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
    } catch (error) {
      console.error("Failed to save progress to localStorage", error);
    }
  }, [progress]);

  const registerTask = useCallback((id: string) => {
    setProgress((prev) => {
      if (id in prev) return prev;
      return { ...prev, [id]: 0 }; // Default to TODO (0)
    });
  }, []);

  const cycleTask = useCallback((id: string) => {
    setProgress((prev) => {
      const current = prev[id] || 0;
      const next: TaskState = ((current + 1) % 3) as TaskState; // 0 -> 1 -> 2 -> 0
      return { ...prev, [id]: next };
    });
  }, []);

  const getTaskState = useCallback(
    (id: string): TaskState => {
      return progress[id] ?? 0;
    },
    [progress],
  );

  // Calculate progress: 2 points for DONE, 1 point for IN PROGRESS
  const totalTasks = Object.keys(progress).length;
  const earnedPoints = Object.values(progress).reduce(
    (sum, state) => sum + state,
    0,
  );
  const totalPossiblePoints = totalTasks * 2;

  const percentage =
    totalPossiblePoints === 0
      ? 0
      : Math.round((earnedPoints / totalPossiblePoints) * 100);

  return {
    progress,
    getTaskState,
    cycleTask,
    registerTask,
    percentage,
    totalTasks,
    earnedPoints,
  };
};
