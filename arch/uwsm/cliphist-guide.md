Based on my research, here's the answer to whether you need both files:

## No, you don't need both — choose ONE approach based on your needs

The uwsm example-units directory provides **both** `cliphist.desktop` and `cliphist.service` as **alternative examples**, not files you use together. Here's when to use each:

### Option 1: cliphist.desktop (XDG Autostart Approach)

**Use this if you want automatic, standards-based autostart:**

- Copy `cliphist.desktop` to `~/.config/autostart/`
- systemd's `systemd-xdg-autostart-generator` automatically converts it to a systemd unit (`app-cliphist@autostart.service`)
- uwsm automatically places it in `app-graphical.slice`
- **No manual enabling needed** — it just starts automatically
- Works across different desktop environments (respects `OnlyShowIn=` / `NotShowIn=` fields)

**Advantages:**

- Cross-desktop compatibility
- Simple drop-in configuration
- Standard XDG autostart behavior
- Easier for casual users

### Option 2: cliphist.service (Direct systemd Service)

**Use this if you want more control over systemd integration:**

- Copy `cliphist.service` to `~/.config/systemd/user/`
- Manually enable it: `systemctl --user enable cliphist.service`
- More explicit control over dependencies, ordering, restart behavior
- Can use all systemd service features

**Advantages:**

- Explicit systemd integration
- More control over service behavior
- Can customize restart policies, dependencies, etc.
- Better for power users who want fine-grained control

### Which Should You Choose?

**For cliphist specifically, I recommend the `.desktop` approach** because:

1. It's simpler — just drop the file in `~/.config/autostart/`
2. XDG autostart is the standard way for desktop applications
3. No manual `systemctl enable` needed
4. uwsm handles the systemd integration automatically

**Use the `.service` approach if:**

- You need specific systemd features (complex dependencies, specific restart policies)
- You want explicit control over when/how the service starts
- You're managing services programmatically

### Summary

**You only need ONE file, not both.** The example-units directory provides both as **alternatives** to demonstrate different integration approaches. For most users with uwsm, the `.desktop` file in `~/.config/autostart/` is the simpler, more automatic choice.
