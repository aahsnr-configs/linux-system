import React, { useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { Copy, Check } from "lucide-react";

interface CodeBlockProps {
  language: string;
  value: string;
}

// Custom Catppuccin Macchiato theme mapping for react-syntax-highlighter
const catppuccinMacchiato = {
  hljs: { background: "#1e2030", color: "#cad3f8" }, // Mantle base
  "hljs-keyword": { color: "#c6a0f6" }, // Mauve
  "hljs-built_in": { color: "#8bd5ca" }, // Teal
  "hljs-type": { color: "#eed49f" }, // Yellow
  "hljs-literal": { color: "#f5a97f" }, // Peach
  "hljs-number": { color: "#f5a97f" }, // Peach
  "hljs-operator": { color: "#91d7e3" }, // Sky
  "hljs-punctuation": { color: "#939ab7" }, // Overlay2
  "hljs-property": { color: "#8aadf4" }, // Blue
  "hljs-regexp": { color: "#f5bde6" }, // Pink
  "hljs-string": { color: "#a6da95" }, // Green
  "hljs-char.escape": { color: "#a6da95" }, // Green
  "hljs-subst": { color: "#cad3f8" }, // Text
  "hljs-symbol": { color: "#f5a97f" }, // Peach
  "hljs-variable": { color: "#f4dbd6" }, // Rosewater
  "hljs-selector-class": { color: "#eed49f" }, // Yellow
  "hljs-selector-tag": { color: "#c6a0f6" }, // Mauve
  "hljs-selector-id": { color: "#8aadf4" }, // Blue
  "hljs-comment": { color: "#6e738d", fontStyle: "italic" }, // Overlay0
  "hljs-meta": { color: "#f0c6c6" }, // Flamingo
  "hljs-attr": { color: "#8aadf4" }, // Blue
  "hljs-attribute": { color: "#a6da95" }, // Green
  "hljs-name": { color: "#8aadf4" }, // Blue
  "hljs-tag": { color: "#f0c6c6" }, // Flamingo
  "hljs-title": { color: "#8bd5ca" }, // Teal
  "hljs-title.class_": { color: "#eed49f" }, // Yellow
  "hljs-title.function_": { color: "#8aadf4" }, // Blue
  "hljs-params": { color: "#cad3f8" }, // Text
  "hljs-addition": { color: "#a6da95" }, // Green
  "hljs-deletion": { color: "#ed8796" }, // Red
};

const CodeBlock: React.FC<CodeBlockProps> = ({ language, value }) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000); // Reset after 2 seconds
    } catch (err) {
      console.error("Failed to copy text: ", err);
    }
  };

  return (
    <div className="code-block-wrapper">
      <div className="code-block-header">
        <span>{language || "text"}</span>
        <button className="copy-button" onClick={handleCopy}>
          {copied ? (
            <span
              style={{
                display: "flex",
                alignItems: "center",
                gap: "0.3rem",
                color: "var(--ctp-green)",
              }}
            >
              <Check size={12} /> Copied
            </span>
          ) : (
            <span
              style={{ display: "flex", alignItems: "center", gap: "0.3rem" }}
            >
              <Copy size={12} /> Copy
            </span>
          )}
        </button>
      </div>
      <SyntaxHighlighter
        language={language || "text"}
        style={catppuccinMacchiato}
        customStyle={{
          margin: 0,
          padding: "1.25rem",
          background: "#1e2030", // Mantle
          fontSize: "0.9rem",
          borderRadius: "0 0 8px 8px",
        }}
        showLineNumbers={false}
        wrapLongLines={true}
      >
        {value}
      </SyntaxHighlighter>
    </div>
  );
};

export default CodeBlock;
