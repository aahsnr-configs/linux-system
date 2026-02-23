Here's a complete guide to finding and searching for packages in the **Terra repository** for Fedora:

---

## What is Terra?

Terra is a collection of rolling-release Fedora repositories by Fyra Labs that includes commonly-used programs not packaged in the main Fedora repositories. It gives you access to 1000+ packages that Fedora doesn't ship.

---

## Step 1: Install Terra (if you haven't already)

**On standard Fedora:**

```bash
sudo dnf install --nogpgcheck \
  --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release
```

**On Atomic/Immutable Fedora (Silverblue, Kinoite, etc.):**

```bash
curl -fsSL https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo | \
  pkexec tee /etc/yum.repos.d/terra.repo
sudo rpm-ostree install terra-release
```

---

## Step 2: Search for Packages

Once Terra is added as a repo, you can search it just like any other DNF repository.

**Search by name or keyword:**

```bash
dnf search <package-name>
```

**Search only within Terra:**

```bash
dnf search <package-name> --repo=terra
```

**List ALL packages available from Terra:**

```bash
dnf repo-pkgs terra list
```

**Get info on a specific package:**

```bash
dnf info <package-name>
```

**Check which repo a package comes from:**

```bash
dnf info <package-name> | grep Repo
```

---

## Step 3: Browse Online (Without Installing)

You can browse Terra's package list online in a few ways:

- **Official website:** [terra.fyralabs.com](https://terra.fyralabs.com) — the main portal for Terra.
- **GitHub monorepo:** [github.com/terrapkg/packages](https://github.com/terrapkg/packages) — this monorepo contains the package manifests for all packages in Terra, so you can browse or search the repo directly on GitHub.
- **Direct repo URL:** You can browse the RPM files at `https://repos.fyralabs.com/terra<version>/` (replace `<version>` with your Fedora release number, e.g., `42` or `43`).

---

## Optional: Enable Subrepos

Terra provides additional packages in separate subrepos. These packages might conflict with RPM Fusion or Fedora repositories. The current subrepos are: **extras** (packages that conflict with or patch Fedora packages), **mesa** (patched codec-complete Mesa), **nvidia** (NVIDIA drivers), and **multimedia** (multimedia packages).

Enable them like so:

```bash
sudo dnf install terra-release-extras    # Patched Fedora packages
sudo dnf install terra-release-mesa      # Mesa with full codec support
sudo dnf install terra-release-nvidia    # NVIDIA drivers
sudo dnf install terra-release-multimedia # Multimedia packages
```

---

**Pro tip:** Use `dnf search --repo=terra <keyword>` for the fastest targeted search within Terra specifically, without results from other repos cluttering the output.
