Installing specific packages from the **oiledmachine-overlay** while ignoring the rest of the repository is a standard task for an experienced Gentoo user. Because this overlay is "opinionated" and often contains patched versions of standard packages (like `sqlite` or `mariadb`), it is highly recommended to surgically pick the packages you want to avoid system-wide version conflicts.

### 1. Add and Sync the Overlay

If you haven't already, add the repository using `eselect repository`. This is the modern, preferred method over the old `layman`.

```bash
# Install the tool if missing
emerge --ask app-eselect/eselect-repository

# Add the oiledmachine-overlay
eselect repository add oiledmachine-overlay git https://github.com/orsonteodoro/oiledmachine-overlay.git

# Sync the new repo
emaint sync --repo oiledmachine-overlay

```

### 2. Force the Overlay for a Specific Package

To ensure `emerge` pulls a package specifically from `oiledmachine-overlay` rather than the main Gentoo tree or another overlay, use the `::` suffix (repo atom).

**One-time install:**

```bash
emerge --ask dev-util/unity-editor::oiledmachine-overlay

```

**Permanent configuration:**
To keep a package tied to this overlay for future updates, add it to your `/etc/portage/package.accept_keywords` or a specific file within that directory:

```bash
# Example: Using the custom kernel from this overlay
echo "sys-kernel/ot-sources::oiledmachine-overlay ~amd64" >> /etc/portage/package.accept_keywords/oiledmachine

```

### 3. Mask the Rest of the Overlay (Recommended)

Since this overlay contains many performance-patched versions of common system libraries, you might want to "white-list" only the specific tools you need. This prevents `emerge --update @world` from accidentally pulling in optimized versions of packages you didn't intend to change.

1. **Mask everything from the repo:**
Create `/etc/portage/package.mask/oiledmachine`:
```text
*/*::oiledmachine-overlay

```


2. **Unmask only what you want:**
Create `/etc/portage/package.unmask/oiledmachine`:

```text
    # Allow only the custom kernel and Unity editor
    sys-kernel/ot-sources::oiledmachine-overlay
    dev-util/unity-editor::oiledmachine-overlay
    ```

### 4. Handling Special Licenses
As noted in the repository's documentation, many packages (especially game dev tools and C# utilities) have custom or non-free licenses.

If your merge fails with a license error, you must manually accept them:
```bash
# Accept all licenses specifically for this overlay's packages
echo "*/*::oiledmachine-overlay *" >> /etc/portage/package.accept_license

```

> [!TIP]
> **Check for "Fetch" Restrictions:** Many packages in this overlay (like Unity or certain .NET tools) cannot be downloaded automatically. If you see a `RESTRICT="fetch"` message, you will need to download the source manually from the vendor's site and place it in `/var/cache/distfiles/` before emerging.

Are you looking for a specific tool like `ot-sources` or one of the game engines, or are you trying to apply the overlay's PGO/BOLT optimizations to your existing system libraries?


