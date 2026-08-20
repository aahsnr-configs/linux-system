I've re‑ingested both files. Below is the complete keybinding map, split into: (1) what your JSON files set/override, (2) defaults your files **remove**, and (3) stock VS Code (Linux) defaults that remain active.

## 1. Custom keybindings — `keybindings.json` (added/overridden)

| Key         | Command                                    | When / Context                                                                                     |
| ----------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| `space`     | `vspacecode.space`                         | `activeEditorGroupEmpty && focusedView == '' && !whichkeyActive && !inputFocus`                    |
| `space`     | `vspacecode.space`                         | `sideBarFocus && !inputFocus && !whichkeyActive`                                                   |
| `alt+space` | `whichkey.show`                            | `editorTextFocus`                                                                                  |
| `alt+x`     | `workbench.action.showCommands`            | Always                                                                                             |
| `tab`       | `extension.vim_tab`                        | `editorTextFocus && vim.active && !inDebugRepl && vim.mode != 'Insert' && editorLangId != 'magit'` |
| `ctrl+j`    | `workbench.action.quickOpenSelectNext`     | `inQuickOpen`                                                                                      |
| `ctrl+k`    | `workbench.action.quickOpenSelectPrevious` | `inQuickOpen`                                                                                      |
| `ctrl+j`    | `selectNextSuggestion`                     | Suggest widget visible w/ multiple suggestions                                                     |
| `ctrl+k`    | `selectPrevSuggestion`                     | Suggest widget visible w/ multiple suggestions                                                     |
| `ctrl+l`    | `acceptSelectedSuggestion`                 | Suggest widget visible w/ multiple suggestions                                                     |
| `ctrl+j`    | `showNextParameterHint`                    | Parameter hints visible                                                                            |
| `ctrl+k`    | `showPrevParameterHint`                    | Parameter hints visible                                                                            |
| `ctrl+j`    | `selectNextCodeAction`                     | `codeActionMenuVisible`                                                                            |
| `ctrl+k`    | `selectPrevCodeAction`                     | `codeActionMenuVisible`                                                                            |
| `ctrl+l`    | `acceptSelectedCodeAction`                 | `codeActionMenuVisible`                                                                            |
| `ctrl+h`    | `file-browser.stepOut`                     | `inFileBrowser`                                                                                    |
| `ctrl+l`    | `file-browser.stepIn`                      | `inFileBrowser`                                                                                    |

### Magit‑specific (vim mode in magit buffers)

| Key       | Command                           |
| --------- | --------------------------------- |
| `x`       | `magit.discard-at-point`          |
| `-`       | `magit.reverse-at-point`          |
| `shift+-` | `magit.reverting`                 |
| `shift+o` | `magit.resetting`                 |
| `y`       | `vspacecode.showMagitRefMenu`     |
| `g`       | `vspacecode.showMagitRefreshMenu` |

## 2. Defaults explicitly **removed** by `keybindings.json` (`-` prefix)

| Removed key        | Command unbound                                           |
| ------------------ | --------------------------------------------------------- |
| `tab`              | `extension.vim_tab` (re‑added above with magit exclusion) |
| `k`                | `magit.discard-at-point`                                  |
| `v`                | `magit.reverse-at-point`                                  |
| `shift+v`          | `magit.reverting`                                         |
| `shift+x`          | `magit.resetting`                                         |
| `x`                | `magit.reset-mixed`                                       |
| `ctrl+u x`         | `magit.reset-hard`                                        |
| `y`                | `magit.show-refs`                                         |
| `g`                | `magit.refresh` (replaced by refresh menu)                |
| `ctrl+i`           | `inlineChat.start`                                        |
| `ctrl+k ctrl+i`    | `inlineChat.start`                                        |
| `alt+\`            | `editor.action.inlineSuggest.trigger`                     |
| `alt+]`            | `editor.action.inlineSuggest.showNext`                    |
| `alt+[`            | `editor.action.inlineSuggest.showPrevious`                |
| `ctrl+enter`       | `editor.action.inlineSuggest.commit`                      |
| `ctrl+alt+shift+i` | `workbench.action.chat.open`                              |
| `ctrl+shift+alt+i` | `workbench.action.chat.openInEditor`                      |

## 3. Vim‑mode bindings — `settings.json`

| Mode   | Key       | Command(s)                                                                         |
| ------ | --------- | ---------------------------------------------------------------------------------- |
| Normal | `<space>` | `vspacecode.space`                                                                 |
| Normal | `,`       | `vspacecode.space` + `whichkey.triggerKey("m")` (jumps straight to the LaTeX menu) |
| Visual | `<space>` | `vspacecode.space`                                                                 |
| Visual | `,`       | `vspacecode.space` + `whichkey.triggerKey("m")`                                    |
| Visual | `>`       | `editor.action.indentLines`                                                        |
| Visual | `<`       | `editor.action.outdentLines`                                                       |

## 4. VSpaceCode leader menus (leader = `SPC`)

| Sequence  | Command                                               | Name                   |
| --------- | ----------------------------------------------------- | ---------------------- |
| `SPC n x` | `notebook.cell.execute`                               | Execute cell           |
| `SPC n n` | `notebook.cell.executeAndSelectBelow`                 | Execute + next         |
| `SPC n i` | `notebook.cell.executeAndInsertBelow`                 | Execute + insert below |
| `SPC n a` | `notebook.cell.insertCodeCellAbove`                   | Insert cell above      |
| `SPC n b` | `notebook.cell.insertCodeCellBelow`                   | Insert cell below      |
| `SPC n d` | `notebook.cell.delete`                                | Delete cell            |
| `SPC t s` | `workbench.action.toggleSidebarVisibility`            | Sidebar                |
| `SPC t p` | `workbench.action.togglePanel`                        | Panel                  |
| `SPC t b` | `workbench.action.toggleStatusbarVisibility`          | Status bar             |
| `SPC t z` | `workbench.action.toggleZenMode`                      | Zen mode               |
| `SPC t f` | `workbench.action.toggleFullScreen`                   | Full screen            |
| `SPC t w` | `editor.action.toggleWordWrap`                        | Word wrap              |
| `SPC t m` | `editor.action.toggleMinimap`                         | Minimap                |
| `SPC o p` | `workbench.view.explorer`                             | Project explorer       |
| `SPC o t` | `workbench.action.terminal.toggleTerminal`            | Terminal               |
| `SPC o s` | `workbench.view.search`                               | Search                 |
| `SPC o g` | `workbench.view.scm`                                  | Source control         |
| `SPC o d` | `workbench.view.debug`                                | Debug                  |
| `SPC o x` | `workbench.extensions.action.showInstalledExtensions` | Extensions             |
| `SPC m b` | `latex-workshop.build`                                | Build LaTeX project    |
| `SPC m v` | `latex-workshop.view`                                 | View PDF               |
| `SPC m j` | `latex-workshop.synctex`                              | SyncTeX from cursor    |
| `SPC m c` | `latex-workshop.clean`                                | Clean auxiliary files  |
| `SPC m k` | `latex-workshop.kill`                                 | Kill LaTeX compiler    |
| `SPC m r` | `latex-workshop.recipes`                              | Build with recipe      |
| `SPC m l` | `latex-workshop.compilerlog`                          | View compiler log      |

## 5. Stock VS Code defaults (Linux) that remain active

| Key                   | Action                     |     | Key                | Action                 |
| --------------------- | -------------------------- | --- | ------------------ | ---------------------- |
| `Ctrl+Shift+P` / `F1` | Command palette            |     | `Ctrl+B`           | Toggle sidebar         |
| `Ctrl+P`              | Quick Open                 |     | `Ctrl+J`           | Toggle panel ¹         |
| `Ctrl+,`              | Settings                   |     | ``Ctrl+` ``        | Toggle terminal        |
| `Ctrl+K Ctrl+S`       | Keyboard shortcuts         |     | ``Ctrl+Shift+` ``  | New terminal           |
| `Ctrl+K Ctrl+T`       | Color theme                |     | `Ctrl+Shift+E`     | Explorer view          |
| `Ctrl+Shift+N`        | New window                 |     | `Ctrl+Shift+F`     | Search view            |
| `Ctrl+W`              | Close editor               |     | `Ctrl+Shift+G`     | Source control view    |
| `Ctrl+K Ctrl+W`       | Close all editors          |     | `Ctrl+Shift+D`     | Run/Debug view         |
| `Ctrl+Tab`            | Recent editors             |     | `Ctrl+Shift+X`     | Extensions view        |
| `Ctrl+S`              | Save                       |     | `Ctrl+Shift+M`     | Problems panel         |
| `Ctrl+Shift+S`        | Save As                    |     | `Ctrl+Shift+U`     | Output panel           |
| `Ctrl+F`              | Find                       |     | `F11`              | Full screen            |
| `Ctrl+H`              | Replace ²                  |     | `F3` / `Shift+F3`  | Find next/prev         |
| `Ctrl+X/C/V`          | Cut/Copy/Paste             |     | `Ctrl+Enter`       | Insert line below ³    |
| `Ctrl+Z` / `Ctrl+Y`   | Undo/Redo                  |     | `Ctrl+Shift+Enter` | Insert line above      |
| `Ctrl+A`              | Select all                 |     | `Alt+↑/↓`          | Move line              |
| `Ctrl+/`              | Toggle line comment        |     | `Shift+Alt+↑/↓`    | Copy line              |
| `Ctrl+Shift+A`        | Toggle block comment [[2]] |     | `Ctrl+Shift+K`     | Delete line            |
| `Ctrl+]` / `Ctrl+[`   | Indent/Outdent             |     | `Shift+Alt+F`      | Format document        |
| `F2`                  | Rename                     |     | `Ctrl+K Ctrl+F`    | Format selection       |
| `F12`                 | Go to definition           |     | `Ctrl+K M`         | Change language mode   |
| `Alt+F12`             | Peek definition            |     | `Ctrl+Space`       | Trigger suggest        |
| `Ctrl+Shift+O`        | Go to symbol               |     | `Ctrl+Shift+Space` | Parameter hints        |
| `Ctrl+G`              | Go to line                 |     | `Ctrl+D`           | Select next occurrence |
| `Ctrl+Home/End`       | File start/end             |     | `Ctrl+Shift+L`     | Select all occurrences |
| `Alt+←/→`             | Navigate back/forward      |     | `Ctrl+L`           | Select line ⁴          |

**Notes:** ¹ `Ctrl+J` is superseded by your custom bindings while Quick Open/suggest/parameter‑hint/code‑action widgets are open. ² `Ctrl+H` acts as `file-browser.stepOut` inside the file browser. ³ `Ctrl+Enter`'s inline‑suggest commit was removed; the editor default remains. ⁴ `Ctrl+L` is superseded in suggest/code‑action/file‑browser contexts. With the Vim extension active, editor‑text keys follow Vim semantics in Normal/Visual mode; the defaults above apply in Insert mode and outside the editor. Any default not listed in sections 1–3 is untouched and behaves per stock VS Code.
