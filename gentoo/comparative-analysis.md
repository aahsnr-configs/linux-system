Now I have read all three files in full. Let me compose the complete three-way comparative analysis.

---

## Comparative Diff Analysis: `arch_hardening_setup.md` vs `gentoo-setup.md` vs `README.md`

---

### 1. Document Nature, Purpose, and Structure

**The Arch file** is a formal, comprehensive APT (Advanced Persistent Threat) security hardening guide running to 4,958 lines across 15 parts, 4 pre-work research sections, extensive appendices, and two embedded Python scripts. Every decision references a specific nation-state TTP it defeats. It is entirely self-contained with no external dotfile dependencies.

**The Gentoo file** is a structured installation and deployment guide running to 1,801 lines across 20 numbered sections and 4 appendices. It is focused on correctly assembling a RAID+LUKS+Btrfs+Snapper stack. It opens with a "Corrections" section documenting 10 fixes from a previous draft — something unique to this file — and is written for a general-purpose technical reader.

**The README file** is a personal operational runbook/cheatsheet running to 748 lines. It is informal, written entirely in the first person with references to personal dotfiles (`/home/ahsan/.dots/gentoo/preconfig_files/with_selinux/`), personal hostnames (`zephyrus`), and multiple installation attempts (several sets of real UUIDs are embedded inline). It contains to-do items, incomplete sections, personal Emacs and zsh notes, and a large unsorted package list. It is not a standalone guide — it presupposes that pre-configured Portage files exist in the user's dotfiles repository.

---

### 2. Threat Model and Security Intent

**The Arch file** declares an explicit threat model at the outset: Chinese and Russian state-sponsored actors (APT10, APT29, APT41, Sandworm, Cozy Bear, Fancy Bear), with documented TTPs including supply-chain compromise, kernel exploits, LUKS brute-force against weak KDFs, cold-boot attacks, DMA-over-Thunderbolt, SSH credential harvesting, and systemd persistence. Every configuration parameter is justified against this adversary.

**The Gentoo file** has no threat model. Appendix D contains brief security observations (PBKDF2 trade-off, RAID-0 risk, Evil Maid via ESP) but these are advisory footnotes, not a designed security posture.

**The README file** declares SELinux as its primary security aspiration in its very first line — but immediately qualifies it as "not yet running in my system." The pre-config files are sourced from a directory named `with_selinux`, signalling intent that is not yet realised. In practice, the file implements partial AppArmor enablement and a basic sysctl hardening block. It is security-aware without being security-designed.

---

### 3. Hardware and Drive Configuration

**The Arch file** targets a specific two-drive machine: a 500 GB NVMe (`nvme0n1`) and a 1 TB NVMe (`nvme1n1`) in a system with an Intel i9-13900K (Raptor Lake). Hardware-specific Intel features — TME, VT-d, CET, RDRAND, Thunderbolt 4 — are discussed and configured throughout.

**The Gentoo file** targets an identical two-drive setup (500 GB `nvme1n1` as boot disk, 1 TB `nvme0n1` as data disk) but with no CPU-specific discussion beyond cpuid2cpuflags for compiler flags. NVIDIA GPU driver installation is briefly noted in the kernel build.

**The README file** targets a **single-drive** machine: only `nvme0n1` is used. There is no RAID of any kind. Multiple real `lsblk` outputs embedded in the document all show a single NVMe device. The document contains references to an ASUS laptop (force_drivers include `hid_asus asus_wmi asus_nb_wmi` in the without-LVM dracut config, and the module checklist mentions "input devices → include asus g14"), making it the only laptop-oriented document of the three.

---

### 4. RAID Strategy

**The Arch file** uses **LVM-on-LUKS2** with LVM's built-in RAID-0 (`lvcreate --type raid0` via `dm-raid`). `mdadm` is not required. Stripe size is explicitly set to 512K for NVMe queue depth alignment.

**The Gentoo file** uses **mdadm software RAID-0**: two separate `md` arrays are created first — `md0` for swap and `md1` for root — using `mdadm --create --metadata=1.2`. LUKS2 is then layered on top of the `md` devices. `mdadm.conf` must be embedded in the initramfs and GRUB must load the `mdraid1x` module before it can decrypt anything.

**The README file** has **no RAID at all**. It operates on a single partition (`nvme0n1p2`) and provides two mutually exclusive paths — with LVM and without LVM — but neither involves striping across multiple drives. The document is the only one of the three that explicitly codes two divergent disk layouts.

---

### 5. LVM Usage

**The Arch file** uses LVM as the RAID-0 mechanism (LVM RAID-0 inside LUKS containers), creating a Volume Group `vg0` with two Logical Volumes: `vg0/main` (striped 1 TB RAID-0) and `vg0/secondary`.

**The Gentoo file** does not use LVM at all. LUKS containers sit directly on `md` devices, and Btrfs is placed directly on the opened LUKS mapper devices.

**The README file** offers both paths. The **LVM path** (the primary path shown first) uses `cfdisk` → `mkfs.vfat` on `nvme0n1p1` → `cryptsetup luksFormat nvme0n1p2` → `cryptsetup luksOpen` → `pvcreate` → `vgcreate vg0` → `lvcreate -L 16G vg0 -n swap` + `lvcreate -l 100%FREE vg0 -n root` → `mkfs.btrfs /dev/vg0/root`. The **without-LVM path** opens LUKS directly onto a `cryptroot` mapper and mounts Btrfs from `/dev/mapper/cryptroot`. Only the without-LVM path also shows the post-install chroot re-mount procedure.

---

### 6. LUKS2 Setup and KDF

**The Arch file** uses **Argon2id** on both LUKS containers (`--pbkdf argon2id`, `--pbkdf-memory 1048576`, `--pbkdf-parallel 4`, `--iter-time 5000`) because there is no GRUB — the UKI loads directly from UEFI and the KDF is unconstrained.

**The Gentoo file** uses a **split KDF**: PBKDF2 on the root (`md1`) because GRUB 2.12 must decrypt it, and Argon2id on the swap (`md0`) since GRUB never opens it. A 20+ character passphrase is advised to compensate for PBKDF2's weaker GPU brute-force resistance.

**The README file** uses a **default KDF** — the `cryptsetup luksFormat` command specifies `--cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase` but no explicit `--pbkdf` flag. This means the KDF defaults to whatever `cryptsetup` chooses (Argon2id in libcryptsetup ≥ 2.4). There is no KDF discussion, no iteration time tuning, and no memory cost parameter. The README is the only file where the KDF is left implicit.

---

### 7. Bootloader

**The Arch file** uses **no traditional bootloader**. A Unified Kernel Image (UKI) — a signed PE/COFF `.efi` binary embedding kernel, initramfs, and cmdline — is loaded directly by UEFI firmware. `sbctl` signs it with custom Secure Boot keys. A pacman hook rebuilds and signs the UKI automatically on every kernel update. GRUB is completely absent.

**The Gentoo file** uses **GRUB 2.12** with `GRUB_ENABLE_CRYPTODISK=y`. GRUB is installed to the ESP (`grubx64.efi`), preloads `mdraid1x cryptodisk luks2 gcry_rijndael gcry_sha512 btrfs` modules, presents the single passphrase prompt, decrypts and reads the kernel from inside the encrypted Btrfs root, and generates its config via `grub-mkconfig`.

**The README file** uses **GRUB**, installed with `grub-install --target=x86_64-efi --efi-directory=/boot && grub-mkconfig -o /boot/grub/grub.cfg`. Crucially, `/boot` is mounted directly from `nvme0n1p1` as a **separate unencrypted partition** — not inside the encrypted root as in the Gentoo file. GRUB therefore never needs to open LUKS. The file also references **rEFInd** (`/usr/lib64/refind/refind/refind.conf-sample`) as an alternative but provides no rEFInd-specific configuration. The README is the only file where `/boot` is unencrypted and separate.

---

### 8. Secure Boot

**The Arch file** implements a complete **Secure Boot with custom keys** workflow via `sbctl`: Platform Key, Key Exchange Key, and Signature Database are generated, enrolled into UEFI, and the UKI is signed on every build. PCR[7] seals the TPM2 key against Secure Boot state — meaning any key rotation triggers an automatic TPM unsealing failure, forcing use of the recovery key.

**The Gentoo file** mentions Secure Boot once, in Appendix D, as an optional Evil Maid mitigation for the ESP. No implementation is provided.

**The README file** makes no mention of Secure Boot whatsoever.

---

### 9. Encryption Unlock at Boot

**The Arch file** uses **TPM2+PIN with PCR sealing** (`systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="0+2+7+12" --tpm2-with-pin=yes`). PCRs covering firmware code, option ROMs, Secure Boot state, and the kernel cmdline are all measured. A recovery key is enrolled as fallback. There is no keyfile.

**The Gentoo file** uses a **keyfile-based silent unlock**. A 4096-byte random keyfile is generated on the live host, added as a second LUKS keyslot on both volumes, copied to `/etc/cryptsetup-keys.d/root12.key`, and embedded in the initramfs. GRUB prompts once with the passphrase; dracut then unlocks both volumes silently via the keyfile. There is no TPM2.

**The README file** uses **standard passphrase unlock only**. There is no keyfile, no TPM2, no PCR sealing. The LUKS UUID is referenced by `rd.luks.uuid` in the dracut `kernel_cmdline` parameter. Unlocking at boot requires typing the passphrase at the initramfs prompt with no silent automation.

---

### 10. Dracut Configuration

**The Arch file** uses dracut with `uefi="yes"` to output a UKI. Modules: `tpm2-tss crypt lvm btrfs systemd systemd-initrd`. The kernel cmdline is embedded into the signed binary and contains security-critical flags (IOMMU, AppArmor LSM, spectre mitigations, SLUB hardening, page poisoning) that become immutable once signed.

**The Gentoo file** uses dracut in standard initramfs mode. Modules: `crypt mdraid btrfs systemd systemd-initrd`. The keyfile path is specified via `install_items`. The `/etc/crypttab.initramfs` approach (not `rd.luks.key`) is used because the guide explicitly explains that `rd.luks.key` conflicts with the `systemd` dracut module. The `installkernel` package automates dracut and `grub-mkconfig` after every `make install`.

**The README file** uses dracut in standard initramfs mode with a significantly simpler config. The LVM path uses `add_dracutmodules+=" crypt dm rootfs-block resume lvm "` with `omit_dracutmodules+=" network cifs nfs nbd brltty "`. The without-LVM path uses `add_dracutmodules+=" crypt dm rootfs-block "` with ASUS-specific `force_drivers`. Unlike the Gentoo file, the README uses `rd.luks.uuid` directly in `kernel_cmdline` — the simpler approach that the Gentoo file explicitly rejects. There is no keyfile embedding and no `sd-encrypt`/`crypt` conflict discussion. The README is also the only file that provides both an OpenSUSE and a Gentoo `dracut --print-cmdline` example output for comparison purposes.

---

### 11. Btrfs Subvolume Layout

**The Arch file** uses 14 subvolumes: `@`, `@/.snapshots`, `@/home`, `@/opt`, `@/root`, `@/srv`, `@/tmp`, `@/usr/local`, `@/var`, `@/var/log`, `@/var/log/audit`, `@/var/cache`, `@/var/tmp`, `@/nix`. CoW is disabled via `chattr +C` on all `@/var/*` and `@/nix` before any files are written. The `@/var/*` subvolumes are mounted with a separate no-compress `BTRFS_NOCOW_OPTS` set. There is no `@/boot/grub2/x86_64-efi` because there is no GRUB.

**The Gentoo file** uses 11 subvolumes: `@`, `@/.snapshots`, `@/boot/grub2/x86_64-efi` (excluded from snapshots — GRUB EFI state must not roll back with the OS snapshot), `@/home`, `@/nix`, `@/opt`, `@/root`, `@/srv`, `@/tmp`, `@/usr/local`, `@/var`. CoW is disabled only on `@/var` and `@/nix`. `/boot` is a plain directory inside `@`, not a subvolume, so snapshots capture the kernel and initramfs.

**The README file** uses 15 subvolumes — the most of any file: `@`, `@home`, `@opt`, `@root`, `@srv`, `@nix`, `@usr@local`, `@var`, `@var@cache`, `@var@crash`, `@var@tmp`, `@var@spool`, `@var@log`, `@var@log@audit`, `@snapshots`. Two subvolumes are unique to this file: `@var@crash` (crash dump storage) and `@var@spool` (spool queue data). The snapshot subvolume is named `@snapshots` (not `@/.snapshots` as in the other two files), mounted at `/.snapshots`. There is no `@tmp` subvolume. All subvolumes — including `@var` and all its children — are mounted with `compress=zstd:3`. The README is the only file that applies zstd compression to the `@var` tree without separately disabling CoW via `chattr +C`.

---

### 12. Swap and Hibernation

**The Arch file** has **no swap partition**. Hibernation is explicitly disabled and blocked at three levels: `systemctl mask hibernate.target`, a polkit rule, and no swap LV in the LVM layout. The threat model justification is that hibernation images may contain decrypted LUKS keys, browser session tokens, and SSH agent keys. Intel TME (Total Memory Encryption) is discussed and verified as a cold-boot protection mechanism for Suspend-to-RAM.

**The Gentoo file** has a dedicated encrypted **~32 GB swap** across both NVMe drives (md0 → LUKS2/Argon2id → `/dev/mapper/swap12`). Hibernation is fully configured: `CONFIG_HIBERNATION=y` in the kernel, `resume=/dev/mapper/swap12` in GRUB cmdline, and Section 16 is dedicated entirely to hibernation setup.

**The README file** has a **16 GB swap LV** (`lvcreate -L 16G vg0 -n swap`) on the LVM path, activated at install time with `swapon /dev/vg0/swap`. Swappiness is tuned with `vm.swappiness=35` in sysctl. No hibernation configuration is provided, but nvidia hibernation/suspend services are enabled (`nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service`), implying hibernation is at least intended. There is no discussion of hibernation security risks.

---

### 13. Kernel: Source vs. Pre-built

**The Arch file** uses the **pre-built `linux-cachyos` kernel** from CachyOS repositories. The kernel is built with LLVM, applying LTO, PGO, BOLT, x86-64-v3/v4 microarchitecture targets, and kCFI (Kernel Control Flow Integrity). No source compilation is required.

**The Gentoo file** compiles the kernel **from source** (`sys-kernel/gentoo-sources`). The build command is relatively straightforward: `make -j$(nproc)` with an optional LLVM path (`LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"`). The guide provides detailed `make menuconfig` instructions for enabling specific `CONFIG_*` options (RAID, DM_CRYPT, Btrfs, NVME, Btrfs POSIX ACL, EFI stub, hibernation). `installkernel` with `USE="dracut grub"` automates the post-compilation workflow.

**The README file** compiles the kernel **from source** with the most aggressive KCFLAGS of any file: `LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin -fno-math-errno -fno-signed-zeros -fno-trapping-math -fcf-protection -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -fstack-protector-strong -fstack-clash-protection -fplugin=LLVMPolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=LLVM -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"`. This incorporates the LLVM Polly vectorizer and parallelizer, `_FORTIFY_SOURCE=3`, stack clash protection, and CF-protection — compile-level security flags absent from the Gentoo file's build. The README uses `make nconfig` (ncurses-based) instead of `menuconfig`. It also uses `modprobed-db` (`sys-kernel/modprobed-db`) for kernel module tracking to minimise build size.

---

### 14. Package Management and Overlays

**The Arch file** uses **pacman** with the CachyOS repository for pre-built optimised packages. Package installation is mediated through a custom Python security wrapper (`pkgman.py`) that intercepts all `pacman`, AUR, and Flatpak operations, performs PKGBUILD static analysis, fetches AUR comments, and requires typed confirmation strings before any AUR build.

**The Gentoo file** uses **Portage/emerge** with the standard Gentoo repository. No additional overlays are added. Package-specific USE flags are configured via `/etc/portage/package.use/` with documented reasons for each flag.

**The README file** uses **Portage/emerge** with an extensive set of overlays beyond the standard Gentoo repository: `guru`, `pentoo`, `edgets`, `gentoo-zh`, `CachyOS-kernels`, `xarblu-overlay`, and a personal custom repository created with `pkgdev`. The standard Gentoo repository is switched from rsync to a GitHub git mirror (`https://github.com/gentoo-mirror/gentoo.git`) with `sync-git-verify-commit-signature = yes` and an OpenPGP key path configured — the only file to explicitly configure Portage repository GPG commit verification. Pre-configured Portage files (make.conf, package.use, package.accept_keywords, package.mask) are copied from the user's dotfiles rather than written inline.

---

### 15. Installed Package Scope

**The Arch file** installs a minimal, security-focused set: kernel, core utils, AppArmor, dracut, sbctl, lvm2, btrfs-progs, firewalld, dnscrypt-proxy, msmtp, auditd, and Python dependencies for the two hardening scripts. No desktop environment or productivity applications are installed.

**The Gentoo file** installs a similarly minimal set: mdadm, cryptsetup, btrfs-progs, GRUB, dracut, gentoo-sources, installkernel, snapper, inotify-tools, linux-firmware. No desktop.

**The README file** installs a massive list of 100+ packages spanning: full Hyprland desktop environment and its complete supporting stack (hyprland, hyprlock, hypridle, hyprpaper, hyprpicker, hyprsunset, xdg-desktop-portal-hyprland, aquamarine, hyprland-contrib, rofi-wayland, sddm, xwayland); container runtimes (docker, docker-compose, containerd, podman, podman-compose, lxc, lxd, distrobox); scientific/research applications (biopython, pymol); security and forensics tools (aide, lynis, sys-process/audit); extensive shell tooling (zsh, fzf, atuin, starship, zoxide, yazi, bat, eza, fd, ripgrep); development tools (neovim, emacs, lazygit, git-delta, tree-sitter, lua-language-server, texlab); Python scientific stack (numpy/scipy via pandas, matplotlib); communication apps (discord, zoom, element); and fonts (JetBrains Mono, Ubuntu, Nerd Fonts). It is the only file targeting a complete daily-driver workstation rather than a minimal or server-oriented installation.

---

### 16. Containers

**The Arch file** makes no mention of containers. The security model (AppArmor MAC confinement of individual processes) would conflict with container runtimes that rely on unprivileged user namespaces.

**The Gentoo file** makes no mention of containers.

**The README file** installs a comprehensive container stack: `docker`, `docker-cli`, `docker-compose`, `docker-credential-helpers`, `containerd`, `podman`, `podman-compose`, `podman-tui`, `pods`, `lxc`, `lxd`, `distrobox`, and `app-containers/lxd`. This is the only file of the three that treats container usage as a first-class workflow.

---

### 17. Desktop Environment and Display

**The Arch file** is written for a workstation (i9-13900K) but specifies no desktop environment. The security architecture (AppArmor profiles, auditd, sysctl) assumes a running desktop but does not install one.

**The Gentoo file** specifies no desktop environment.

**The README file** targets a full **Hyprland** (Wayland compositor) desktop with SDDM display manager. The complete Hyprland supporting stack is installed: aquamarine, hyprgraphics, hyprutils, hyprlang, hyprcursor, hyprland-protocols, xdg-desktop-portal-hyprland, along with associated tools (grim for screenshots, slurp for region selection, wf-recorder for screen recording, wl-clipboard for clipboard management). Qt5/Qt6 theming (qt5ct, qt6ct, Kvantum), Papirus icons, Thunar file manager, and XWayland support are included.

---

### 18. Sysctl Hardening

**The Arch file** has a dedicated Part 5 with 50+ sysctl parameters, each annotated with the APT TTP it mitigates. Notable values: `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`, `kernel.unprivileged_bpf_disabled=1`, `kernel.bpf_jit_harden=2`, `kernel.bpf_jit_kallsyms=0`, `kernel.yama.ptrace_scope=1`, `vm.unprivileged_userfaultfd=0`, `kernel.unprivileged_userns_clone=1` (kept enabled for browser sandbox compatibility), `net.ipv4.icmp_echo_ignore_broadcasts=1` (broadcasts only, not all ICMP), `kernel.kexec_load_disabled=1`, `kernel.sysrq=0`, `kernel.ftrace_enabled=0`, `kernel.panic_on_oops=1`, `kernel.panic=10`, `fs.suid_dumpable=0`, `kernel.core_pattern=|/bin/false`, `dev.tty.ldisc_autoload=0`. TCP SACK is not touched.

**The Gentoo file** has no sysctl hardening.

**The README file** has a single `harden.conf` file with approximately 30 parameters, no inline comments or threat model justifications. Key differences from the Arch file: `kernel.unprivileged_userns_clone=0` (disabled — unlike Arch which sets it to 1, accepting that this breaks browser sandboxing), `net.ipv4.icmp_echo_ignore_all=1` (ignores ALL ICMP pings, not just broadcasts), `kernel.perf_event_paranoid=3`, `vm.mmap_rnd_bits=32` and `vm.mmap_rnd_compat_bits=16` (ASLR entropy maximisation — absent from Arch), `net.ipv4.tcp_sack=0`, `net.ipv4.tcp_dsack=0`, `net.ipv4.tcp_fack=0` (disabling TCP selective acknowledgement — absent from Arch), `vm.swappiness=35` (has swap, unlike Arch). Missing from the README relative to Arch: BPF JIT kallsyms exposure setting, ftrace, panic_on_oops, core dump pattern routing, explicit core dump suppression mechanism (though `fs.suid_dumpable=0` is present).

---

### 19. AppArmor

**The Arch file** implements AppArmor as the **primary MAC layer** using the `apparmor.d` project (1500+ profiles). The LSM stack is baked into the signed UKI kernel cmdline: `lsm=landlock,lockdown,yama,integrity,apparmor,bpf`. Profile coverage is analysed in detail (system daemon profiles are enforce-ready; browser profiles are in complain mode upstream).

**The Gentoo file** has no AppArmor.

**The README file** enables AppArmor in the **without-LVM GRUB cmdline** (`GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor"`) and enables the `apparmor` service via systemctl. However, no AppArmor profiles, no `apparmor.d` project, and no profile configuration are provided. AppArmor is switched on but essentially unconfigured.

---

### 20. SELinux

**The Arch file** does not mention SELinux (AppArmor is chosen as the MAC implementation).

**The Gentoo file** does not mention SELinux.

**The README file** opens with SELinux as its stated primary security goal and copies pre-config files from a `with_selinux` directory in the user's dotfiles. However, the author explicitly notes it is "not yet running in my system." The pre-config source path (`/home/ahsan/.dots/gentoo/preconfig_files/with_selinux/etc/portage/*`) is visible but the portage config content is not shown inline. SELinux remains aspirational throughout the document.

---

### 21. Auditd

**The Arch file** has a dedicated Part 4 with a comprehensive auditd ruleset covering process execution, sensitive file access (`/etc/passwd`, `/etc/shadow`, `/etc/sudoers`), SUID/SGID execution, kernel module loads, network configuration changes, time change attempts, and pacman/makepkg tracking. Auditd output feeds the daily email reporting pipeline.

**The Gentoo file** has no auditd.

**The README file** installs `sys-process/audit` and enables `auditd` via `systemctl enable ... auditd ...` but provides no audit rules whatsoever. Auditd is installed and running, but is collecting events without any custom rule configuration.

---

### 22. Firewall

**The Arch file** configures `firewalld` with the `drop` zone as default on all interfaces, explicit rules for DoT/DoH (853 TCP, 443 TCP/UDP), SSH on a custom port (2222), Cockpit on localhost only, and outbound port 53 blocked (to prevent DNS leaks around dnscrypt-proxy).

**The Gentoo file** has no firewall configuration.

**The README file** installs `net-firewall/firewalld` in its package list but provides no firewalld configuration. Firewalld is present in the package list only.

---

### 23. DNS Security

**The Arch file** implements a full layered DNS stack in Part 9.2: applications → `systemd-resolved` stub (127.0.0.53:53) → `dnscrypt-proxy` (127.0.0.1:5300) → anonymized relay → encrypted resolver. The full `dnscrypt-proxy.toml` is provided with `require_dnssec`, `require_nolog`, `require_nofilter`, and anonymized relay routes. Cleartext DNS to external port 53 is blocked at the firewall.

**The Gentoo file** has no DNS hardening.

**The README file** has no DNS hardening.

---

### 24. SSH Hardening

**The Arch file** provides a full hardened `sshd_config` and `ssh_config` in Part 10: custom port (2222), Ed25519 host key only, restricted KexAlgorithms and ciphers, key-only authentication, no root login, no X11/agent forwarding, AllowUsers whitelist, ControlMaster disabled (explicitly noted as an APT hijack vector), and a warning banner.

**The Gentoo file** has no SSH configuration.

**The README file** has no SSH configuration.

---

### 25. PAM Hardening

**The Arch file** has a dedicated Part 11 covering `faillock.conf` (5 failures → 15-minute lockout, root lockable), `pwquality.conf` (16-character minimum, character class requirements, dictionary check), a fully rewritten `/etc/pam.d/system-auth` with preauth/authfail/authsucc faillock integration, and `limits.conf` with zero core dumps and hard caps on process count and file descriptors.

**The Gentoo file** has no PAM hardening.

**The README file** has a `/etc/security/limits.conf` with a different group-based structure: a `@dev` group receives relaxed limits (core 100000, nproc 35, maxlogins 10) while all other users have hard limits on nproc (15), rss (10000), and maxlogins (2). This is the only file to use `maxlogins` as a limit. The README also implements **password aging** via `chage --mindays 40 --maxdays 120 --warndays 30 ahsan` — minimum 40 days before a password can be changed, maximum 120-day lifetime, 30-day warning. This is absent from both other files. No faillock or pwquality configuration is provided.

---

### 26. Security and Forensics Tools

**The Arch file** implements its own monitoring via auditd rulesets, the Python-based `svc-harden.py` service analysis tool, `arch-audit` for CVE scanning, and automated email reports via msmtp + systemd timers.

**The Gentoo file** has no security tools beyond the base system.

**The README file** installs **`app-forensics/aide`** (Advanced Intrusion Detection Environment — file integrity monitoring) and **`app-forensics/lynis`** (system security auditing). It is the only file to install dedicated host-based IDS tooling. However, no AIDE database initialisation, no AIDE configuration, and no Lynis hardening report procedure are shown. Both tools are installed but not configured.

---

### 27. Entropy and RNG

**The Arch file** dedicates Part 8 and pre-work Section 0.4 to concluding that no userspace RNG augmentation is needed on the i9-13900K with kernel ≥ 6.x. `haveged` is explicitly labelled "NOT recommended" (weaker than kernel jitterentropy). `rng-tools` is labelled "OPTIONAL, marginal benefit." `jitterentropy-rngd` is labelled "NOT needed" (duplicates kernel built-in).

**The Gentoo file** makes no mention of entropy sources.

**The README file** installs **both `sys-apps/haveged` and `sys-apps/rng-tools`** and enables `rngd` via systemctl. This directly contradicts the Arch file's explicit recommendation against haveged and characterization of rng-tools as marginal. The README is the only file to install and enable haveged.

---

### 28. IOMMU / DMA Protection

**The Arch file** has a dedicated Part 7 configuring `intel_iommu=on iommu=force` in the signed UKI cmdline, verifying VT-d is enabled in UEFI, and documenting the trade-off between `iommu=pt` (passthrough) and `iommu=force` (strict, with ~5–10% I/O overhead). The interaction between IOMMU and Intel TME is analysed.

**The Gentoo file** has no IOMMU configuration.

**The README file** has no IOMMU configuration.

---

### 29. Kernel Module Blacklisting

**The Arch file** has a comprehensive Part 6 blacklisting unused filesystems (cramfs, freevxfs, jffs2, hfs, hfsplus, udf), unused network protocol parsers (dccp, sctp, rds, tipc, ax25, netrom, x25, atm, appletalk, can), DMA attack surface modules (firewire-core, firewire-ohci, firewire-sbp2), PCMCIA, speakup, cdc-acm, and conditional Bluetooth blacklisting. Thunderbolt is explicitly NOT blacklisted due to hardware usage, with IOMMU as the compensating control.

**The Gentoo file** has no module blacklisting.

**The README file** has no module blacklisting. It does configure **NVIDIA-specific module options** (`/etc/modprobe.d/nvidia.conf` with `nvidia-drm modeset=1` and `NVreg_UsePageAttributeTable=1`, and `/etc/modprobe.d/nvidia-power-management.conf` with `NVreg_PreserveVideoMemoryAllocations=1`) — GPU driver configuration that is absent from both other files.

---

### 30. systemd Service Hardening

**The Arch file** includes a full Python 3 `svc-harden.py` script in Part 12 with subcommands: `analyze` (runs `systemd-analyze security`), `apply` (interactively prompts through 28 hardening directives), `test`, `revert`, `bisect` (binary-searches for the directive that broke a service), and `log`. The tool explicitly refuses bulk/wildcard operations.

**The Gentoo file** has no systemd service hardening.

**The README file** has no systemd service hardening.

---

### 31. Supply Chain and Monitoring

**The Arch file** has Part 13 (supply chain monitoring: pacman hooks for GPG SigLevel verification, post-transaction audit logging, `arch-audit` CVE scanning, CachyOS GitHub API polling) and Part 14 (ongoing monitoring: daily auditd summary emails, real-time threshold alerts, weekly CVE reports, weekly AppArmor denial digests, all automated via systemd timers and msmtp to Proton Mail Bridge).

**The Gentoo file** has no supply chain monitoring and no automated alerting.

**The README file** configures Portage with `sync-git-verify-commit-signature = yes` (GPG verification of repository commits) — a supply-chain control not present in the Gentoo file. No other supply chain monitoring or automated alerting is present.

---

### 32. Snapshot Management and Rollback

**The Arch file** installs Snapper but **prohibits bootloader-integrated snapshot booting** as an explicit requirement. Rollback is chroot-based only. `grub-btrfs` is not installed.

**The Gentoo file** implements full **bootable snapshots via `grub-btrfs`**. The `grub-btrfsd` daemon watches `/.snapshots` and regenerates GRUB config. A "Btrfs Snapshots" GRUB submenu lets the user boot directly into any snapshot. Three rollback paths are documented: GRUB snapshot boot (non-destructive test), `snapper rollback N` (commit), and manual live-environment subvolume set-default.

**The README file** installs `app-backup/grub-btrfs` and `app-backup/snapper` along with GUI tools `app-backup/btrfs-assistant` and `app-backup/snapper-gui`. The snapper setup command is provided (`snapper -c root create-config /` followed by manual subvolume cleanup to align with the pre-created `@snapshots` subvolume). No detailed rollback procedure is documented. The README is the only file to install GUI-based snapshot management tools.

---

### 33. Legal/Warning Banner

**The Arch file** has no login banner configuration.

**The Gentoo file** has no login banner configuration.

**The README file** configures `/etc/issue` and `/etc/issue.net` with a legal warning banner stating that the system is for authorized users only, that all activity may be monitored and recorded, and that evidence may be provided to law enforcement. This is the only file to include a pre-login warning banner.

---

### 34. Network Configuration

**The Arch file** configures NetworkManager with hardened settings (Part 9.3), deploys firewalld with detailed rich rules, and implements the dnscrypt-proxy + systemd-resolved DNS stack.

**The Gentoo file** presents NetworkManager or systemd-networkd as a choice and enables `NetworkManager` (or optionally `systemd-networkd systemd-resolved`) in the final services section without configuration detail.

**The README file** uses **iwd** (Intel Wireless Daemon) as the wireless backend (`net-wireless/iwd`, enabled via systemctl) rather than NetworkManager or wpa_supplicant. The OpenRC path uses dhcpcd + wpa_supplicant; the systemd path uses dhcpcd + iwd. The README is the only file to use iwd as the wireless manager. Firewalld is installed but not configured.

---

### 35. Miscellaneous Personal Details

**The Arch file** references a specific Proton Mail address (`aahsnr041@proton.me`) in the monitoring scripts and a username (`ahsan`) in the PAM sections, indicating this is a guide written for a specific person's system.

**The Gentoo file** copies a `tc-optimize` script and `.nanorc` from `/home/ahsan/Git/configs/linux-system/gentoo/preconfig/` to the chroot, revealing the same author.

**The README file** is the most explicitly personal of the three: it references the author's dotfiles path (`/home/ahsan/.dots/gentoo/preconfig_files/with_selinux/`), personal hostname (`zephyrus`, identifiable as an ASUS ROG Zephyrus laptop), multiple real device UUIDs from actual installation attempts, personal Emacs workflow notes, Python/scientific stack preferences, and per-application HiDPI scaling settings (`--force-device-scale-factor=1.75`).

---

### Summary Comparison Table

| Dimension | Arch (`arch_hardening_setup.md`) | Gentoo (`gentoo-setup.md`) | README (`README.md`) |
|---|---|---|---|
| Purpose | APT security hardening guide | Installation/deployment guide | Personal runbook/cheatsheet |
| Lines | 4,958 | 1,801 | 748 |
| Style | Formal, threat-model-justified | Structured, explanatory | Informal, personal notes |
| Drives | 2× NVMe (500 GB + 1 TB) | 2× NVMe (500 GB + 1 TB) | 1× NVMe (single drive) |
| RAID | LVM RAID-0 (no mdadm) | mdadm RAID-0 (md0 + md1) | No RAID |
| LVM | Yes (RAID mechanism) | No | Optional (two paths shown) |
| LUKS KDF | Argon2id (both drives) | PBKDF2 (root) + Argon2id (swap) | Implicit default (no flag) |
| Bootloader | None (UKI + direct UEFI) | GRUB 2.12 (GRUB_ENABLE_CRYPTODISK) | GRUB (separate unencrypted /boot) |
| /boot location | On ESP (outside Btrfs) | Inside encrypted Btrfs root | Separate unencrypted partition |
| Secure Boot | Full custom key enrollment (sbctl) | Not implemented | Not mentioned |
| Unlock mechanism | TPM2+PIN with PCR sealing | Keyfile embedded in initramfs | Standard passphrase |
| Swap | None (disabled) | ~32 GB encrypted | 16 GB LVM volume |
| Hibernation | Disabled (security threat) | Fully supported | Implied (nvidia services enabled) |
| Btrfs subvolumes | 14 (granular var/* separation) | 11 (Tumbleweed-style + GRUB subvol) | 15 (adds @var@crash, @var@spool) |
| CoW on var | Disabled (chattr +C + separate mount opts) | Disabled on @/var and @/nix | Not disabled (zstd on all) |
| Snapshot booting | Disabled (chroot rollback only) | grub-btrfs bootable snapshots | grub-btrfs installed |
| Snapshot GUI | None | None | btrfs-assistant + snapper-gui |
| Kernel | linux-cachyos (pre-built, kCFI) | Compiled from source (basic LLVM) | Compiled from source (Polly + security KCFLAGS) |
| Package manager | pacman + CachyOS repos + pkgman.py | Portage/emerge (standard repos) | Portage/emerge (6+ overlays + custom repo) |
| Desktop | Not installed | Not installed | Hyprland + SDDM (full stack) |
| Containers | Not mentioned | Not mentioned | Docker + Podman + LXD + distrobox |
| SELinux | Not mentioned | Not mentioned | Intended, not implemented |
| AppArmor | Primary MAC (apparmor.d, 1500+ profiles) | None | Enabled, not configured |
| Auditd | Comprehensive ruleset | None | Installed, no rules |
| Sysctl hardening | 50+ params with APT justifications | None | ~30 params, no justification |
| unprivileged_userns_clone | 1 (enabled for browser sandbox) | N/A | 0 (disabled) |
| ICMP blocking | Broadcasts only | N/A | All ICMP (icmp_echo_ignore_all=1) |
| TCP SACK | Not touched | N/A | Disabled (tcp_sack/dsack/fack=0) |
| Module blacklisting | Comprehensive (Part 6) | None | None (NVIDIA opts only) |
| IOMMU | iommu=force (strict, Part 7) | None | None |
| Intel TME | Discussed and verified | Not mentioned | Not mentioned |
| Firewall | firewalld, drop zone (configured) | None | firewalld (installed, not configured) |
| DNS hardening | dnscrypt-proxy + anonymized relays | None | None |
| SSH hardening | Full sshd_config + ssh_config | None | None |
| PAM hardening | faillock + pwquality + system-auth | None | limits.conf with @dev group + password aging |
| Password aging | Not set | Not set | chage (40/120/30 days) |
| Login banner | None | None | /etc/issue legal warning |
| IDS/forensics tools | auditd (with rules), arch-audit | None | AIDE + Lynis (installed, not configured) |
| haveged | Explicitly NOT recommended | Not mentioned | Installed and enabled |
| rng-tools | Optional, marginal | Not mentioned | Installed and enabled |
| Supply chain | GPG hooks + CVE scan + email alerts | None | sync-git-verify-commit-signature |
| Email alerting | msmtp + daily/weekly timers | None | None |
| Service hardening | svc-harden.py Python tool | None | None |
| Network manager | NetworkManager | NetworkManager or systemd-networkd | iwd + dhcpcd |
| NVIDIA config | Not applicable (Intel platform) | Briefly noted | Detailed (modprobe.d, power mgmt) |
| Disaster recovery | Full live-USB procedure (Part 15) | Troubleshooting section (Section 20) | Post-install chroot remount only |
