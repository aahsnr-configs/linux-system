# Pyprland with PyPy: Analysis & Installation Guide

## Executive Summary

**Good News:** The markdown file's technical information is **mostly accurate**! PyPy 3.11 support is real, Pillow is compatible, and pyprland can run on PyPy. However, the installation method suggested in the markdown is **not optimal** for your use case.

**The Problem:** The markdown suggests creating a virtual environment manually, which won't put the `pypr` executable in `~/.local/bin` like `pipx install pyprland` does.

**The Solution:** Use `pipx` with the `--python` flag to install pyprland with PyPy while maintaining the same user experience as regular pipx.

---

## Verification of Markdown Claims

### ✅ PyPy Python 3.11 Support

- **Claim:** PyPy 7.3.20 (July 2025) has full Python 3.11 support
- **Verified:** TRUE - PyPy 7.3.20 was released on July 4, 2025
- **Current Status:** PyPy officially supports Python 2.7 and 3.11

### ✅ Pillow Compatibility with PyPy

- **Claim:** Pillow now supports PyPy3.11 with official wheels
- **Verified:** TRUE - Pillow 12.1.0 (latest, released Jan 2, 2026) has official PyPy3.11 wheels
- **Technical Note:** As of Pillow 11.0.0, PyAccess was removed because Pillow's C API is now _faster_ than PyAccess on PyPy

### ✅ Pyprland Requirements

- **Pyprland requires:** Python >= 3.11, aiofiles (optional), Pillow (optional)
- **PyPy supports:** Python 3.11
- **Conclusion:** All dependencies are compatible ✓

### ⚠️ Installation Method (ISSUE FOUND)

- **Markdown suggests:** Creating a venv manually with `pypy3 -m venv`
- **Problem:** This creates executables in the venv's bin directory, NOT in `~/.local/bin`
- **Your requirement:** You want `pypr` in `~/.local/bin` (like `pipx install pyprland`)

---

## Recommended Solution: Use pipx with PyPy

### Why This Is Better

1. **Matches your expected behavior:** Executable in `~/.local/bin`
2. **Maintains isolation:** Each package in its own venv (just like pipx)
3. **Easy management:** Use `pipx list`, `pipx upgrade`, `pipx uninstall`
4. **Standard approach:** pipx is designed exactly for this use case

### Prerequisites

1. **Install PyPy3:**

   ```bash
   # On Arch Linux
   sudo pacman -S pypy3

   # On Ubuntu/Debian
   sudo apt install pypy3

   # Or download from pypy.org
   ```

2. **Install pipx** (if not already installed):

   ```bash
   # Using your system Python
   python3 -m pip install --user pipx
   python3 -m pipx ensurepath

   # Restart your terminal after ensurepath
   ```

### Installation Command

```bash
# Install pyprland using PyPy3 as the interpreter
pipx install --python pypy3 pyprland
```

This will:

- Create a virtual environment at `~/.local/share/pipx/venvs/pyprland/` (or similar)
- Use PyPy3 as the Python interpreter for that venv
- Install pyprland and its dependencies in that venv
- Create a symlink to `pypr` in `~/.local/bin/`

### Verify Installation

```bash
# Check that pypr is in your PATH
which pypr
# Should show: /home/yourusername/.local/bin/pypr

# Check that it's using PyPy
head -n 1 $(which pypr)
# Should show something like: #!/home/yourusername/.local/share/pipx/venvs/pyprland/bin/pypy3

# Test running it
pypr --help
```

---

## Alternative: Manual Installation (If pipx Doesn't Work)

If for some reason pipx doesn't work with PyPy on your system, here's a manual approach that achieves the same result:

```bash
# 1. Create a dedicated PyPy venv for pyprland
mkdir -p ~/.local/share/pyprland-pypy
pypy3 -m venv ~/.local/share/pyprland-pypy

# 2. Install pyprland in that venv
~/.local/share/pyprland-pypy/bin/pip install pyprland

# 3. Create symlink in ~/.local/bin
mkdir -p ~/.local/bin
ln -sf ~/.local/share/pyprland-pypy/bin/pypr ~/.local/bin/pypr
ln -sf ~/.local/share/pyprland-pypy/bin/pypr-client ~/.local/bin/pypr-client

# 4. Ensure ~/.local/bin is in your PATH
# Add to ~/.bashrc or ~/.zshrc if not already present:
export PATH="$HOME/.local/bin:$PATH"
```

---

## Performance Expectations

Based on the markdown's analysis (which is reasonable):

### Likely Benefits:

- **Faster plugin execution** - PyPy's JIT optimizes Python code
- **Better async performance** - PyPy handles asyncio well
- **Warm-up period needed** - First run will be slower

### Potential Limitations:

- **JIT warmup time** - Initial startup slower until hot paths are optimized
- **Memory overhead** - PyPy uses more memory initially for JIT compilation
- **Real bottleneck** - If pyprland spends most time waiting for Hyprland IPC, PyPy gains may be minimal

### Reality Check:

Pyprland is an IPC-based plugin manager that mostly _waits_ for events from Hyprland. The performance gains from PyPy may be **modest** in practice, since the bottleneck is likely not Python execution but waiting for window manager events.

**Recommendation:** Try it and benchmark! Use regular Python first, then PyPy, and compare:

- Startup time
- Memory usage
- Responsiveness

---

## Troubleshooting

### If `pipx install --python pypy3 pyprland` fails:

1. **Verify PyPy is accessible:**

   ```bash
   which pypy3
   pypy3 --version
   ```

2. **Try with full path:**

   ```bash
   pipx install --python /usr/bin/pypy3 pyprland
   ```

3. **Check pipx version:**
   ```bash
   pipx --version
   # Need at least 0.16.0 for good --python support
   ```

### If pypr doesn't work after installation:

1. **Check PATH:**

   ```bash
   echo $PATH | grep -o "$HOME/.local/bin"
   ```

2. **Verify symlink:**

   ```bash
   ls -la ~/.local/bin/pypr
   ```

3. **Test directly:**
   ```bash
   ~/.local/bin/pypr --help
   ```

---

## Comparison: Regular Python vs PyPy Installation

| Aspect              | Regular Python          | PyPy                                   |
| ------------------- | ----------------------- | -------------------------------------- |
| Installation        | `pipx install pyprland` | `pipx install --python pypy3 pyprland` |
| Executable location | `~/.local/bin/pypr`     | `~/.local/bin/pypr`                    |
| Startup time        | Fast (CPython)          | Slower initially (JIT warmup)          |
| Runtime speed       | Good                    | Potentially faster (JIT optimized)     |
| Memory usage        | Lower                   | Higher (JIT overhead)                  |
| Compatibility       | 100%                    | 99%+ (very high)                       |

---

## Final Recommendation

**Use pipx with PyPy:**

```bash
pipx install --python pypy3 pyprland
```

This gives you:

- ✅ Executable in `~/.local/bin` (as desired)
- ✅ Isolated environment (best practice)
- ✅ Easy to manage (pipx commands)
- ✅ Easy to revert (just `pipx uninstall pyprland` and reinstall normally)

**But be realistic about performance gains:**

- Pyprland is event-driven and I/O-bound
- PyPy benefits are likely modest for this use case
- Worth trying, but don't expect dramatic speedup

---

## Bonus: How to Benchmark

If you want to test the performance difference:

```bash
# Install both versions
pipx install pyprland                          # Regular Python
pipx install --python pypy3 pyprland --suffix="-pypy"  # PyPy version

# Now you have both:
# - pypr (regular Python)
# - pypr-pypy (PyPy version)

# Test startup time
time pypr --help
time pypr-pypy --help

# Test in real usage
# (Use one for a day, then the other, and compare subjectively)
```

---

## Conclusion

The markdown's technical analysis is **solid and accurate**. However, for your specific goal (getting `pypr` in `~/.local/bin`), use **pipx with the --python flag** instead of manually creating a venv. This is the standard, clean approach that gives you exactly what you want.

**TL;DR:**

```bash
pipx install --python pypy3 pyprland
```

That's it! Simple, clean, and achieves your goal.
