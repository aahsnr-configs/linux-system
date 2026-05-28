import React, { useState, useEffect } from "react";
import Sidebar from "./components/Sidebar";
import MarkdownRenderer from "./components/MarkdownRenderer";
import { Section } from "./types";
import { useProgress } from "./hooks/useProgress";

const App: React.FC = () => {
  const [sections, setSections] = useState<Section[]>([]);
  const [activeSectionId, setActiveSectionId] = useState<string>("0");
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const {
    getTaskState,
    cycleTask,
    registerTask,
    percentage,
    totalTasks,
    earnedPoints,
  } = useProgress();

  useEffect(() => {
    const fetchGuide = async () => {
      try {
        const response = await fetch("/guide.md");
        if (!response.ok)
          throw new Error(`Failed to fetch guide.md: ${response.statusText}`);
        const text = await response.text();
        const parsedSections = parseMarkdown(text);
        setSections(parsedSections);
        if (parsedSections.length > 0) setActiveSectionId(parsedSections[0].id);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "An unknown error occurred",
        );
      } finally {
        setIsLoading(false);
      }
    };
    fetchGuide();
  }, []);

  const parseMarkdown = (md: string): Section[] => {
    const lines = md.split("\n");
    const parsed: Section[] = [];
    let currentSection: Section | null = null;

    for (const line of lines) {
      const headerMatch = line.match(/^## (\d+)\s+—\s+(.*)/);
      if (headerMatch) {
        if (currentSection) parsed.push(currentSection);
        currentSection = {
          id: headerMatch[1],
          title: `${headerMatch[1]} — ${headerMatch[2].trim()}`,
          content: line + "\n",
        };
      } else if (currentSection) {
        currentSection.content += line + "\n";
      } else {
        if (!currentSection) {
          currentSection = {
            id: "0",
            title: "0 — Architecture & Threat Model",
            content: line + "\n",
          };
        } else {
          currentSection.content += line + "\n";
        }
      }
    }
    if (currentSection) parsed.push(currentSection);
    return parsed;
  };

  if (isLoading)
    return (
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          height: "100vh",
          backgroundColor: "#24273a",
          color: "#cad3f8",
        }}
      >
        <p>Loading Guide...</p>
      </div>
    );
  if (error)
    return (
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          height: "100vh",
          backgroundColor: "#24273a",
          color: "#ed8796",
        }}
      >
        <p>Error: {error}</p>
      </div>
    );

  const activeSection = sections.find((s) => s.id === activeSectionId);

  return (
    <div className="app-container">
      <Sidebar
        sections={sections}
        activeSectionId={activeSectionId}
        onSetActive={setActiveSectionId}
        percentage={percentage}
        totalTasks={totalTasks}
        earnedPoints={earnedPoints}
      />
      <main className="main-content">
        {activeSection ? (
          <MarkdownRenderer
            key={activeSection.id}
            sectionId={activeSection.id}
            content={activeSection.content}
            getTaskState={getTaskState}
            cycleTask={cycleTask}
            registerTask={registerTask}
          />
        ) : (
          <p>Select a section from the sidebar to begin.</p>
        )}
      </main>
    </div>
  );
};

export default App;
