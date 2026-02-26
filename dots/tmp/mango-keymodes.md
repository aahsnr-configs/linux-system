Now let me cross-reference with the full wiki to make sure I have a complete picture before making any decisions.Now I have the full picture. Let me carefully audit everything before writing the changes.

**Key findings from the audit:**

1. **There's an existing bug in your config.** After `keymode=guiapps` on line 29, there is no `keymode=default` reset. Per the wiki — _"set keymode before bind, then the bind will apply to the keymode"_ — this means every single bind below line 29 (TUI apps, all Noctalia, Focus, Move, Resize, etc.) is currently being registered inside the `guiapps` keymode. This is a silent bug that needs fixing as part of this change.

2. **Available free SUPER+letter slots:** T, L, N, M, H, J, K, O, P, R, U, Z. The most semantically appropriate picks for the 4 keymodes are:
   - TUI apps → **SUPER,T** (T = Terminal/TUI)
   - Noctalia Launchers & Menu → **SUPER,L** (L = Launchers)
   - Noctalia Core Interface → **SUPER,N** (N = Noctalia, the shell's core identity)
   - Noctalia Misc → **SUPER,M** (M = Misc)

3. **`SUPER,Escape`** was bound to sessionMenu in Core Interface. Since Escape exits the keymode, inside `noctalia_core` sessionMenu maps to `X` instead (which was already a sessionMenu bind in your original Misc section, so the muscle memory is consistent).

---

Here are only the changes needed. Replace/remove each section as shown:

**1. Fix the bug — add `keymode=default` after the guiapps block (after line 34):**

```conf
bind=NONE,E,spawn_shell,emacsclient -c -a 'emacs'

keymode=default   # ← ADD THIS LINE
```

---

**2. Replace the TUI Applications section (remove the 3 individual SUPER binds, replace with a keymode):**

Remove:

```conf
bind=SUPER,Y,spawn,kitty -e yazi
bind=SUPER,B,spawn,kitty -e btop
bind=SUPER,E,spawn,kitty -e nvim
```

Replace with:

```conf
# Enter tuiapps keymode
bind=SUPER,T,setkeymode,tuiapps

keymode=tuiapps
bind=NONE,Escape,setkeymode,default
bind=NONE,Y,spawn,kitty -e yazi
bind=NONE,B,spawn,kitty -e btop
bind=NONE,E,spawn,kitty -e nvim

keymode=default
```

---

**3. Replace the Noctalia Launchers and Menu section (SUPER,D stays untouched as a direct bind in Essentials):**

Remove:

```conf
bind=SUPER,V,spawn,qs -c noctalia-shell ipc call launcher clipboard
bind=SUPER,W,spawn,qs -c noctalia-shell ipc call launcher windows
bind=SUPER,Period,spawn,qs -c noctalia-shell ipc call launcher command
bind=SUPER+SHIFT,Period,spawn,qs -c noctalia-shell ipc call launcher emoji
```

Replace with:

```conf
# Enter noctalia_launchers keymode
bind=SUPER,L,setkeymode,noctalia_launchers

keymode=noctalia_launchers
bind=NONE,Escape,setkeymode,default
bind=NONE,D,spawn,qs -c noctalia-shell ipc call launcher toggle
bind=NONE,V,spawn,qs -c noctalia-shell ipc call launcher clipboard
bind=NONE,W,spawn,qs -c noctalia-shell ipc call launcher windows
bind=NONE,Period,spawn,qs -c noctalia-shell ipc call launcher command
bind=SHIFT,Period,spawn,qs -c noctalia-shell ipc call launcher emoji

keymode=default
```

---

**4. Replace the Noctalia Core Interface section:**

Remove:

```conf
bind=SUPER,C,spawn,qs -c noctalia-shell ipc call controlCenter toggle
bind=SUPER,Comma,spawn,qs -c noctalia-shell ipc call settings toggle
bind=SUPER,A,spawn,qs -c noctalia-shell ipc call calendar toggle
bind=SUPER,I,spawn,qs -c noctalia-shell ipc call systemMonitor toggle
bind=SUPER,Escape,spawn,qs -c noctalia-shell ipc call sessionMenu toggle
```

Replace with:

```conf
# Enter noctalia_core keymode
bind=SUPER,N,setkeymode,noctalia_core

keymode=noctalia_core
bind=NONE,Escape,setkeymode,default
bind=NONE,C,spawn,qs -c noctalia-shell ipc call controlCenter toggle
bind=NONE,Comma,spawn,qs -c noctalia-shell ipc call settings toggle
bind=NONE,A,spawn,qs -c noctalia-shell ipc call calendar toggle
bind=NONE,I,spawn,qs -c noctalia-shell ipc call systemMonitor toggle
bind=NONE,X,spawn,qs -c noctalia-shell ipc call sessionMenu toggle

keymode=default
```

> Note: `SUPER,Escape` → `X` inside the keymode because Escape is taken for mode exit. `X` is consistent with how your original Misc section already used it for sessionMenu.

---

**5. Replace the Noctalia Misc section:**

Remove:

```conf
bind=SUPER+SHIFT,I,spawn,qs -c noctalia-shell ipc call idleInhibitor toggle
bind=SUPER+SHIFT,K,spawn,qs -c noctalia-shell ipc call lockScreen lock
bind=SUPER+SHIFT,P,spawn,qs -c noctalia-shell ipc call powerProfile cycle
bind=SUPER,X,spawn,qs -c noctalia-shell ipc call sessionMenu toggle
bind=SUPER+SHIFT,X,spawn,qs -c noctalia-shell ipc call sessionMenu lockAndSuspend
```

Replace with:

```conf
# Enter noctalia_misc keymode
bind=SUPER,M,setkeymode,noctalia_misc

keymode=noctalia_misc
bind=NONE,Escape,setkeymode,default
bind=NONE,I,spawn,qs -c noctalia-shell ipc call idleInhibitor toggle
bind=NONE,K,spawn,qs -c noctalia-shell ipc call lockScreen lock
bind=NONE,P,spawn,qs -c noctalia-shell ipc call powerProfile cycle
bind=NONE,X,spawn,qs -c noctalia-shell ipc call sessionMenu toggle
bind=SHIFT,X,spawn,qs -c noctalia-shell ipc call sessionMenu lockAndSuspend

keymode=default
```

---

**Summary of all 4 entry keybindings:**

| Keymode              | Entry     | Mnemonic                 |
| -------------------- | --------- | ------------------------ |
| `guiapps`            | `SUPER,G` | **G**UI apps (unchanged) |
| `tuiapps`            | `SUPER,T` | **T**UI/Terminal apps    |
| `noctalia_launchers` | `SUPER,L` | **L**aunchers            |
| `noctalia_core`      | `SUPER,N` | **N**octalia shell core  |
| `noctalia_misc`      | `SUPER,M` | **M**isc                 |
