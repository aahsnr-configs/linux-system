#!/usr/bin/env python3
# ==============================================================================
# Script: build-hyprland.py
# Purpose: Idempotent build & install of latest stable Hyprland on openSUSE
#          Tumbleweed.  Automatically creates a Python virtual environment with
#          all required modules (rich, requests) and installs them.
#
# Usage   : ./build-hyprland.py [--force] [--verbose]
# ==============================================================================
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Union, List

# ---------------------------------------------------------------------------
# Virtual‑environment bootstrap
# ---------------------------------------------------------------------------
VENV_DIR = Path.home() / ".cache" / "hyprland-installer-venv"


def _bootstrap_venv() -> None:
    """Create venv, install dependencies, and re‑exec the script inside it."""
    if os.environ.get("HYPRLAND_INSTALLER_VENV") == "1":
        return

    print("🔧  Setting up virtual environment (one‑time step)...")
    if not VENV_DIR.exists():
        subprocess.run(
            [sys.executable, "-m", "venv", str(VENV_DIR)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    pip = VENV_DIR / "bin" / "pip"
    python = VENV_DIR / "bin" / "python"

    subprocess.run(
        [pip, "install", "--quiet", "rich", "requests"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    env = os.environ.copy()
    env["HYPRLAND_INSTALLER_VENV"] = "1"
    os.execve(str(python), [str(python), __file__] + sys.argv[1:], env)


_bootstrap_venv()

# ---------------------------------------------------------------------------
# Imports that require the virtual environment
# ---------------------------------------------------------------------------
import requests
from rich.console import Console
from rich.text import Text

console = Console()


# ---------------------------------------------------------------------------
# Main Installer Class
# ---------------------------------------------------------------------------
class HyprlandInstaller:
    REPO_OWNER = "hyprwm"
    REPO_NAME = "Hyprland"
    GITHUB_API = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}"
    BUILD_DIR = Path.home() / ".cache" / "hyprland-build"
    REPO_URL = f"https://github.com/{REPO_OWNER}/{REPO_NAME}"

    def __init__(self) -> None:
        self.force: bool = False
        self.verbose: bool = False
        self._parse_args()

    # ------------------------------------------------------------------
    # Argument parsing
    # ------------------------------------------------------------------
    def _parse_args(self) -> None:
        import argparse
        parser = argparse.ArgumentParser(
            description="Idempotent build & install of latest stable Hyprland."
        )
        parser.add_argument("-f", "--force", action="store_true",
                            help="Bypass version check and force a clean rebuild.")
        parser.add_argument("-v", "--verbose", action="store_true",
                            help="Enable debug messages (command output is always shown).")
        args, _ = parser.parse_known_args()
        self.force = args.force
        self.verbose = args.verbose

    # ------------------------------------------------------------------
    # Helper: run a command while streaming output live to the terminal
    # ------------------------------------------------------------------
    def _run_live(
        self,
        cmd: List[str],
        *,
        cwd: Optional[Path] = None,
        allow_input: bool = False,
    ) -> subprocess.CompletedProcess:
        """Execute *cmd*, printing stdout/stderr in real time."""
        if self.verbose:
            console.print(f"[dim]➜ {' '.join(cmd)}[/dim]")

        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            stdin=sys.stdin if allow_input else subprocess.DEVNULL,
        )

        out_lines: List[str] = []
        for line in proc.stdout:
            console.print(line, end="")
            out_lines.append(line)

        proc.wait()
        stdout = "".join(out_lines)
        if proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd, output=stdout)
        return subprocess.CompletedProcess(args=cmd, returncode=proc.returncode, stdout=stdout)

    # ------------------------------------------------------------------
    # Main entry point
    # ------------------------------------------------------------------
    def run(self) -> None:
        self._print_header()
        self._verify_sudo()

        # 1. Version information
        latest_tag = self._fetch_latest_version()
        if not latest_tag:
            console.print("❌  Failed to fetch latest release tag from GitHub.", style="red")
            sys.exit(1)

        installed = self._get_installed_version()
        console.print(f"🔖  Latest stable release: [bold green]{latest_tag}[/bold green]")
        if installed:
            console.print(f"📦  Currently installed: [bold green]v{installed}[/bold green]")
        else:
            console.print("📦  No existing Hyprland installation detected.")

        # 2. Idempotency check
        if self._skip_because_installed(latest_tag, installed):
            return

        # 3. Pre‑build countdown
        print()
        console.rule(f"🚀  Target version: [bold cyan]{latest_tag}[/bold cyan]")
        console.print("⏳  Build pipeline begins in [bold]5 seconds[/bold]... (Ctrl+C to cancel)")
        for i in range(5, 0, -1):
            console.print(f"  {i}...", end="\r")
            time.sleep(1)
        print()

        # 4. System preparation
        self._run_zypper_dup()
        self._install_build_dependencies()

        # 5. Build
        self._clean_build_dir()
        self._clone_and_checkout(latest_tag)
        self._compile_source()
        self._install_binary()

        # 6. Cleanup & finish
        self._clean_build_dir()
        print()
        console.rule(f"✅  [bold green]Hyprland {latest_tag} installed successfully![/bold green]")
        console.print("🔔  Restart your display manager or log out/in to apply changes.", style="italic")

    # ------------------------------------------------------------------
    # Header
    # ------------------------------------------------------------------
    def _print_header(self) -> None:
        banner = Text(
            r"""
        ╔═══════════════════════════════════════════════════╗
        ║             🦢  Hyprland Installer               ║
        ║     openSUSE Tumbleweed · idempotent build       ║
        ╚═══════════════════════════════════════════════════╝
        """,
            style="bold cyan",
        )
        console.print(banner)
        if self.force:
            console.print("⚡  [bold yellow]FORCE MODE[/bold yellow] – version check bypassed.")

    # ------------------------------------------------------------------
    # GitHub API
    # ------------------------------------------------------------------
    def _fetch_latest_version(self) -> Optional[str]:
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        with console.status("[bold]Querying GitHub API...[/bold]"):
            try:
                resp = requests.get(f"{self.GITHUB_API}/releases/latest", headers=headers, timeout=30)
                resp.raise_for_status()
                tag = resp.json().get("tag_name")
                return tag.strip() if tag else None
            except Exception as e:
                console.print(f"[red]GitHub API request failed: {e}[/red]")
                return None

    # ------------------------------------------------------------------
    # Installed version detection
    # ------------------------------------------------------------------
    def _get_installed_version(self) -> Optional[str]:
        import re
        if shutil.which("hyprland"):
            try:
                proc = subprocess.run(["hyprland", "--version"], capture_output=True, text=True, timeout=10)
                match = re.search(r"v?(\d+\.\d+\.\d+)", proc.stdout)
                if match:
                    return match.group(1)
            except Exception:
                pass
        if shutil.which("zypper"):
            try:
                proc = subprocess.run(["zypper", "search", "--installed-only", "hyprland"],
                                      capture_output=True, text=True, timeout=15)
                for line in proc.stdout.splitlines():
                    match = re.search(r"hyprland\s+\|\s+(\d+\.\d+\.\d+)", line)
                    if match:
                        return match.group(1)
            except Exception:
                pass
        return None

    @staticmethod
    def _normalize_version(ver: str) -> str:
        return ver.lstrip("v")

    def _versions_equal(self, tag: str, installed: str) -> bool:
        return self._normalize_version(tag) == self._normalize_version(installed)

    def _skip_because_installed(self, tag: str, installed: Optional[str]) -> bool:
        if self.force:
            return False
        if installed and self._versions_equal(tag, installed):
            console.print(f"✅  Target version ([bold green]{tag}[/bold green]) is already installed.")
            console.print("🏁  System is up‑to‑date. Idempotent exit.")
            sys.exit(0)
        return False

    def _verify_sudo(self) -> None:
        if not shutil.which("sudo"):
            console.print("❌  'sudo' not found. Please install sudo and retry.", style="red")
            sys.exit(1)

    # ------------------------------------------------------------------
    # zypper wrapper (conflict fallback)
    # ------------------------------------------------------------------
    def _run_zypper(self, subcommand: Union[str, List[str]], *, non_interactive: bool = True,
                    allow_fallback: bool = True) -> subprocess.CompletedProcess:
        if isinstance(subcommand, str):
            subcommand = subcommand.split()
        base = ["sudo", "zypper"]
        if non_interactive:
            base.append("--non-interactive")
        cmd = base + subcommand
        try:
            return self._run_live(cmd, allow_input=not non_interactive)
        except subprocess.CalledProcessError as e:
            if e.returncode == 4 and non_interactive and allow_fallback:
                console.print("⚠️  [bold yellow]Dependency resolver conflict (exit code 4).[/bold yellow] "
                              "Re‑running interactively so you can choose a resolution.")
                interactive_cmd = [arg for arg in cmd if arg != "--non-interactive"]
                return self._run_live(interactive_cmd, allow_input=True)
            raise

    # ------------------------------------------------------------------
    # System steps
    # ------------------------------------------------------------------
    def _run_zypper_dup(self) -> None:
        console.rule("🔄  System update")
        console.print("📡  Running [bold]sudo zypper dup[/bold] (this may take a while)...")
        self._run_zypper("dup")
        console.print("✅  [bold green]System update completed.[/bold green]")

    def _install_build_dependencies(self) -> None:
        console.rule("🧱  Build dependencies")
        console.print("📦  Installing [bold]zypper si -d hyprland[/bold]...")
        self._run_zypper("si -d hyprland")
        console.print("✅  [bold green]Build dependencies installed.[/bold green]")

    # ------------------------------------------------------------------
    # Build directory
    # ------------------------------------------------------------------
    def _clean_build_dir(self) -> None:
        if self.BUILD_DIR.exists():
            console.print(f"🧹  Cleaning build directory: {self.BUILD_DIR}")
            shutil.rmtree(self.BUILD_DIR, ignore_errors=True)
        self.BUILD_DIR.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # Source checkout
    # ------------------------------------------------------------------
    def _clone_and_checkout(self, tag: str) -> None:
        console.rule("📥  Source checkout")
        console.print(f"🐙  Cloning [bold]{self.REPO_URL}[/bold]...")
        self._run_live(["git", "clone", "--recursive", self.REPO_URL, self.REPO_NAME], cwd=self.BUILD_DIR)
        repo_path = self.BUILD_DIR / self.REPO_NAME
        console.print(f"🏷   Checking out tag [bold cyan]{tag}[/bold cyan]")
        self._run_live(["git", "checkout", "--quiet", tag], cwd=repo_path)
        self._run_live(["git", "submodule", "update", "--init", "--recursive", "--quiet"], cwd=repo_path)

    # ------------------------------------------------------------------
    # Compilation & installation
    # ------------------------------------------------------------------
    def _compile_source(self) -> None:
        console.rule("🛠   Compilation")
        console.print("🏗   Running [bold]make -j22 all[/bold]...")
        self._run_live(["make", "--no-print-directory", "-j22", "all"], cwd=self.BUILD_DIR / self.REPO_NAME)

    def _install_binary(self) -> None:
        console.rule("📦  Installation")
        console.print("💾  Running [bold]sudo make install[/bold]...")
        self._run_live(["sudo", "make", "--no-print-directory", "install"], cwd=self.BUILD_DIR / self.REPO_NAME)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    try:
        HyprlandInstaller().run()
    except KeyboardInterrupt:
        console.print("\n\n🚫  Operation cancelled by user.", style="yellow")
        sys.exit(130)
    except Exception as exc:
        console.print(f"\n\n❌  Unhandled exception: {exc}", style="red")
        sys.exit(1)