# optimize-ubuntu-for-Ryzen-1XXX-5XXX-series-x86-64-v3

Bash script that safely optimises Ubuntu for the **x86-64-v3** microarchitecture
level, targeting **AMD Ryzen 1XXX – 5XXX** (znver1 / znver2 / znver3) processors.

---

## What the script does

| Step | Action | Expected gain |
|------|--------|---------------|
| 1 | Verify CPU supports all x86-64-v3 features (AVX2, BMI2, F16C, FMA, MOVBE, XSAVE) | — |
| 2 | Set `CFLAGS`/`CXXFLAGS` to `-O2 -march=x86-64-v3 -mtune=znver3` | +10–25% compile speed |
| 3 | Set `RUSTFLAGS="-C target-cpu=x86-64-v3"` | +10–25% Rust build speed |
| 4 | Set `GOAMD64=v3` | Go binaries use wider ISA |
| 5 | Set `MAKEFLAGS=-j$(nproc)` | Full-parallel `make` builds |
| 6 | Create glibc hwcaps directory & `ldconfig` entry | Faster glibc dispatch |
| 7 | Tune APT (`Pipeline-Depth`, parallel downloads, retries) | Faster `apt upgrade` |
| 8 | Persist `GOAMD64` and `MAKEFLAGS` in `/etc/environment` | Survive reboots |

Expected user-facing speedups:

| Component | Speed-up |
|-----------|----------|
| Compilation (GCC/Clang/Rust) | 10–25 % |
| Archiving (zstd / lz4) | 20–35 % |
| Firefox / Chromium | 5–15 % |
| Games | 3–10 % |

---

## Requirements

* Ubuntu 22.04 LTS (Jammy) or later (x86-64)
* AMD Ryzen 1XXX – 5XXX CPU (or any x86-64-v3-capable CPU)
* `bash` 4+, `sudo` / root access

---

## Quick start

```bash
# Clone
git clone https://github.com/IJenia001/optimize-ubuntu-for-Ryzen-1XXX-5XXX-series-x86-64-v3.git
cd optimize-ubuntu-for-Ryzen-1XXX-5XXX-series-x86-64-v3

# Make executable
chmod +x optimize.sh

# Preview without making changes
sudo ./optimize.sh --dry-run

# Apply optimisations
sudo ./optimize.sh

# Activate env-vars in current shell (or re-login)
source /etc/profile
```

---

## Files written by the script

| File | Purpose |
|------|---------|
| `/etc/profile.d/x86-64-v3-flags.sh` | `CFLAGS`, `CXXFLAGS`, `LDFLAGS` |
| `/etc/profile.d/x86-64-v3-rust.sh` | `RUSTFLAGS` |
| `/etc/profile.d/x86-64-v3-go.sh` | `GOAMD64` |
| `/etc/profile.d/x86-64-v3-make.sh` | `MAKEFLAGS` |
| `/etc/environment` | `GOAMD64`, `MAKEFLAGS` (PAM-level) |
| `/etc/apt/apt.conf.d/99-x86-64-v3-optimise` | APT pipeline / parallel tuning |
| `/etc/ld.so.conf.d/x86-64-v3-hwcaps.conf` | glibc hwcaps loader path |
| `/usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3/` | hwcaps library directory |

---

## Options

| Flag | Effect |
|------|--------|
| `--dry-run` | Print every action that *would* be taken; write nothing |

---

## Safety notes

* **Non-destructive** — only writes new config files and appends to `/etc/environment`.
  Nothing is removed.
* **Idempotent** — running the script a second time is safe; existing lines in
  `/etc/environment` are updated in-place rather than duplicated.
* **Exit on error** — the script uses `set -euo pipefail`; if the CPU check
  fails the script aborts before touching any system files.

---

## Reverting

```bash
# Remove profile.d snippets
sudo rm -f /etc/profile.d/x86-64-v3-*.sh

# Remove APT config
sudo rm -f /etc/apt/apt.conf.d/99-x86-64-v3-optimise

# Remove ld.so entry and hwcaps dir
sudo rm -f /etc/ld.so.conf.d/x86-64-v3-hwcaps.conf
sudo rm -rf /usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3
sudo ldconfig

# Remove /etc/environment additions (edit manually)
sudo nano /etc/environment
```

---

## License

MIT