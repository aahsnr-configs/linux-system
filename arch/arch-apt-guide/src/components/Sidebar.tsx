import React from "react";
import { BookOpen, CheckCircle2, Circle } from "lucide-react";
import { Section } from "../types";

interface SidebarProps {
  sections: Section[];
  activeSectionId: string;
  onSetActive: (id: string) => void;
  percentage: number;
  earnedPoints: number;
  totalTasks: number;
}

const Sidebar: React.FC<SidebarProps> = ({
  sections,
  activeSectionId,
  onSetActive,
  percentage,
  earnedPoints,
  totalTasks,
}) => {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
            marginBottom: "0.25rem",
          }}
        >
          <BookOpen size={16} style={{ color: "var(--ctp-mauve)" }} />
          <span className="sidebar-title">Gentoo APT Guide</span>
        </div>
        <p className="sidebar-subtitle">Nation-State Hardening</p>
      </div>

      <div className="progress-container">
        <div className="progress-label">
          <span>Progress</span>
          <span>{percentage}%</span>
        </div>
        <div className="progress-bar-bg">
          <div
            className="progress-bar-fill"
            style={{ width: `${percentage}%` }}
          />
        </div>
        <div
          style={{
            marginTop: "0.25rem",
            fontSize: "0.7rem",
            color: "var(--ctp-subtext0)",
          }}
        >
          {earnedPoints} / {totalTasks * 2} points ({totalTasks} tasks)
        </div>
      </div>

      <ul className="nav-list">
        {sections.map((section) => {
          const isActive = section.id === activeSectionId;
          return (
            <li
              key={section.id}
              className={`nav-item ${isActive ? "active" : ""}`}
              onClick={() => onSetActive(section.id)}
            >
              <div
                style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}
              >
                {isActive ? (
                  <CheckCircle2
                    size={12}
                    style={{ flexShrink: 0, color: "var(--ctp-blue)" }}
                  />
                ) : (
                  <Circle
                    size={12}
                    style={{ flexShrink: 0, color: "var(--ctp-surface2)" }}
                  />
                )}
                <span
                  style={{
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                    whiteSpace: "nowrap",
                    fontSize: "0.8rem",
                  }}
                >
                  {section.title}
                </span>
              </div>
            </li>
          );
        })}
      </ul>
    </aside>
  );
};

export default Sidebar;
