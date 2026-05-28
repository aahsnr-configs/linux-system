import React from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import CodeBlock from "./CodeBlock";
import { TaskState } from "../types";

interface MarkdownRendererProps {
  sectionId: string;
  content: string;
  getTaskState: (id: string) => TaskState;
  cycleTask: (id: string) => void;
  registerTask: (id: string) => void;
}

// Helper to extract plain text from ReactMarkdown children for stable IDs
const extractText = (children: React.ReactNode): string => {
  if (typeof children === "string") return children;
  if (Array.isArray(children)) return children.map(extractText).join("");
  if (React.isValidElement(children))
    return extractText((children.props as any)?.children);
  return "";
};

const StatusButton: React.FC<{
  taskId: string;
  state: TaskState;
  onClick: () => void;
}> = ({ taskId, state, onClick }) => {
  const config = {
    0: { icon: "○", className: "status-todo", title: "TODO" },
    1: { icon: "◔", className: "status-progress", title: "IN PROGRESS" },
    2: { icon: "●", className: "status-done", title: "DONE" },
  }[state];

  return (
    <button
      className={`status-btn ${config.className}`}
      onClick={onClick}
      title={config.title}
    >
      {config.icon}
    </button>
  );
};

const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({
  sectionId,
  content,
  getTaskState,
  cycleTask,
  registerTask,
}) => {
  const createHeadingRenderer = (level: "h2" | "h3") => {
    const HeadingComponent: React.FC<{ children: React.ReactNode }> = ({
      children,
    }) => {
      const text = extractText(children);
      const taskId = `${sectionId}-${text
        .toLowerCase()
        .replace(/[^\w]+/g, "-")
        .replace(/-+$/, "")}`;

      registerTask(taskId);
      const state = getTaskState(taskId);

      const Tag = level as "h2" | "h3";

      return (
        <div className="task-heading">
          <StatusButton
            taskId={taskId}
            state={state}
            onClick={() => cycleTask(taskId)}
          />
          <Tag>{children}</Tag>
        </div>
      );
    };
    return HeadingComponent;
  };

  return (
    <div className="markdown-body compact-mode">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          h2: createHeadingRenderer("h2"),
          h3: createHeadingRenderer("h3"),
          code({ node, inline, className, children, ...props }) {
            const match = /language-(\w+)/.exec(className || "");
            if (!inline && match) {
              return (
                <CodeBlock
                  language={match[1]}
                  value={String(children).replace(/\n$/, "")}
                />
              );
            }
            if (!inline && String(children).includes("\n")) {
              return (
                <CodeBlock
                  language="text"
                  value={String(children).replace(/\n$/, "")}
                />
              );
            }
            return (
              <code className={className} {...props}>
                {children}
              </code>
            );
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
};

export default MarkdownRenderer;
