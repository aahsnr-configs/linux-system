# MASTER DIRECTIVE: ARCHITECTING THE "KERNEL-STITCHER" PIPELINE

**Mission Objective**
You are an expert **Systems Architect** and **Hardened Gentoo Developer**. Your mission is to design and document a highly resilient, multi-agent workflow using **Pydantic AI** and **LangGraph**. This workflow will produce a final, ultra-optimized, and hardened Linux kernel configuration (`optimize-kernel.config`). 

The system must intelligently transform `minimal-kernel.config` by integrating performance features from `cachyos-kernel.config` while strictly enforcing the security and hardware-specific requirements found in the attached **`README.md`** and its linked **Gentoo Wiki** resources.

---

### **Phase 1: Project Management & Environment Setup**
The workflow must be managed under strict, modern developer constraints. Your output must provide explicit shell instructions to the user on how to set up the environment:
* **Version Management**: Use **`asdf-vm`** (`.tool-versions`) to install and pin the required Python version.
* **Dependency Management**: Use **`uv`** to create a lightning-fast virtual environment (`uv venv`) and install all required libraries (e.g., `uv pip install pydantic-ai langgraph litellm`).
* **Core Logic**: The main program must be a Python application that utilizes **Pydantic AI** for defining strict agent behaviors and tool-calling, mapped onto a **LangGraph** Directed Acyclic Graph (DAG) for state execution.
* **Orchestration**: All agent API calls must be directed through a local **LiteLLM** proxy, and the user interaction will happen via the **LibreChat** UI. 

---

### **Phase 2: Knowledge Ingestion & Data Sources**
Analyze the following 10 files to establish the operational constraints. The target configuration must strictly align with the **APT Threat Model (May 2026)** and the hardware specifications for an **Intel i9-13900K** with **NVIDIA RTX 2080 Ti**.
1.  **`cachyos-kernel.config`**: Source for the BORE scheduler and performance toggles.
2.  **`minimal-kernel.config`**: The hardened base to be modified.
3.  **`README.md`**: The primary policy document (UKI, LUKS2/Argon2id, TPM2+PIN, Btrfs CoW).
4.  **`flash-lite-prompt.md`**: Logic for the recursive "Stitcher" loop and segmentation.
5.  **`other-markdown.md`**: Directives for agentic personas and state management.
6.  **`ghost-router.md`**: Manifest for selecting optimal models based on free-tier benchmarks.
7.  **`librechat-litellm-gemini-setup.md`**: Setup for Podman/LiteLLM orchestration.
8.  **`config.yaml`**: LiteLLM proxy reference (disregard outdated `flash-lite` blocks).
9.  **`librechat.yaml`**: UI and context persistence settings.
10. **`podman-compose.yml`**: Container orchestration reference.

---

### **Phase 3: Hardening Frameworks & Resource Integration**
The agentic workflow must systematically validate the configuration against these explicit sources of truth:
* **The GitHub Auditor Tool**: [kernel-hardening-checker](https://github.com/a13xp0p0v/kernel-hardening-checker) (must be run as a validation step in the Python script).
* **Upstream Kernel Tooling**: The Linux kernel's internal `make hardening.config` targets.
* **KSPP Standards**: Security recommendations from the **Kernel Self-Protection Project**.
* **README & Gentoo Wiki Directives**: The agent must extract and apply all `CONFIG_` flags mentioned in the `README.md` and the **Gentoo Wiki** articles it references (specifically the Gentoo Hardened, Kernel/Configuration, and NVIDIA/Secure Boot wiki pages). Key enforcements include:
    * **Toolchain**: `Clang + ThinLTO + kCFI` (Kernel Control Flow Integrity).
    * **Hardware**: Intel `TME` (Total Memory Encryption), `VT-d`, and `CET` (Control-flow Enforcement Technology).
    * **Storage/Boot**: UKI-specific flags, Btrfs CoW settings, and TPM 2.0 integration.

---

### **Phase 4: The "Kernel-Stitcher" Agentic Architecture**
Design the Python workflow using **Pydantic AI** for agent definition and **LangGraph** for execution.

#### **A. Dynamic Model Routing**
Do not hardcode specific LLM models into the Python script. Instead, instruct the script to parse the attached **`ghost-router.md`** file dynamically to deduce and select the optimal models for these roles based on the latest April 2026 benchmarks:
* **[STRATEGIST]**: High-context manager to map the 11,000+ line structure.
* **[LIBRARIAN]**: Research-focused agent to verify Gentoo Wiki links, CVEs, and patch notes.
* **[PARSER]**: High-speed logic agent to merge CachyOS optimizations into the minimal base.
* **[CRITIC]**: Hardening Auditor to run `kernel-hardening-checker` and prevent "hallucinated" `CONFIG_` flags.

#### **B. Workflow Visualization in LibreChat**
A critical requirement is real-time visualization of the workflow. Because this is managed via LibreChat, you must configure the Python script to use **LangGraph's native state visualization**. 
* The script must output the LangGraph DAG state as a **Mermaid.js** diagram enclosed in standard Markdown codeblocks (e.g., ` ```mermaid `).
* LibreChat natively renders these codeblocks, allowing the user to visually track the state transitions (e.g., from Parser back to Critic) in real-time within the chat window. Provide explicit code instructions on how to yield these Markdown updates to the UI.

#### **C. The Recursive "Stitcher" Loop**
To bypass 64k token output limits while utilizing a 1M+ token input context:
1.  **Logical Segmentation**: Divide files into functional Kconfig blocks (Networking, Drivers, Security).
2.  **Context-Rich Synthesis**: Feed the *entire* 11,000-line context as read-only memory, then request the generation of a specific modified block.
3.  **Automated Linter Node**: The Python script must execute `make olddefconfig` on the Arch host to ensure block dependencies are valid.
4.  **Infinite Correction**: Implement a loop that feeds errors (e.g., "Symbol X depends on Y") back to the Parser until the config is 100% valid.

---

### **Phase 5: Post-Workflow Manual Roadmap**
* **Environment Context**: The script runs on an **Arch Linux Host**, targeting a **Gentoo Chroot** at `/mnt/gentoo/usr/src/linux`.
* **Containers**: LiteLLM and LibreChat run as rootless containers via `podman-compose.yml`.

**Provide manual, step-by-step instructions for the user to perform AFTER the agentic script finishes:**
1.  Building `sys-kernel/cachyos-sources` using `make LLVM=1` and the `bore` scheduler.
2.  Setting up `ananicy-cpp` with `ananicy-cachyos-rules`.
3.  The workflow for applying **AutoFDO** and **Propeller** optimizations on the booted Gentoo system.
4.  Executing `make localmodconfig` to strip the kernel to its absolute functional minimum for the target hardware.

**FINAL INSTRUCTION**: Do not execute the kernel build or perform the tasks yourself. Output the complete, functional Python application code (using Pydantic AI and LangGraph), the `asdf`/`uv` setup guide, the LibreChat visualization logic, and the roadmap for the manual steps. Ensure all logic perfectly aligns with the April 2026 threat model in the `README.md`.
