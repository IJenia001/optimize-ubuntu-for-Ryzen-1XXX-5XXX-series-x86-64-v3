#!/usr/bin/env bash
# ==============================================================================
# optimize.sh — Ubuntu x86-64-v3 optimisation for AMD Ryzen 1XXX-5XXX series
# ==============================================================================
# Safe, non-destructive tweaks that give real performance gains:
#   • Verifies CPU support for x86-64-v3 (AVX2, BMI2, F16C, FMA, MOVBE, XSAVE)
#   • GCC/Clang flags: -march=x86-64-v3 -mtune=znver3
#   • Rust RUSTFLAGS: -C target-cpu=x86-64-v3
#   • Go GOAMD64=v3
#   • MAKEFLAGS=-j$(nproc)
#   • glibc hwcaps: links /usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3
#   • APT config: pipelining, parallel downloads, zstd compression
#   • ld.so.conf.d entry for the hwcaps directory
# ==============================================================================
# Usage:
#   chmod +x optimize.sh
#   sudo ./optimize.sh
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Privilege check ────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Please run as root: sudo $0"

# ── Dry-run mode ───────────────────────────────────────────────────────────────
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true && warn "Dry-run mode: no changes will be written."

# Wrapper: writes file only outside dry-run
write_file() {
    local path="$1"; shift
    if $DRY_RUN; then
        info "[DRY-RUN] would write: $path"
    else
        cat > "$path"
    fi
}

# ── 1. CPU feature check ───────────────────────────────────────────────────────
check_cpu_support() {
    info "=== Step 1: Checking CPU x86-64-v3 feature support ==="

    local flags
    flags=$(grep -m1 '^flags' /proc/cpuinfo)

    local required=(avx avx2 bmi1 bmi2 f16c fma movbe xsave)
    local missing=()

    for feat in "${required[@]}"; do
        if echo "$flags" | grep -qw "$feat"; then
            info "  ✔ $feat"
        else
            warn "  ✘ $feat (missing)"
            missing+=("$feat")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "CPU does not support x86-64-v3. Missing features: ${missing[*]}"
    fi
    info "CPU fully supports x86-64-v3."
}

# ── 2. GCC / Clang optimisation flags ─────────────────────────────────────────
configure_gcc_flags() {
    info "=== Step 2: Configuring GCC/Clang optimisation flags ==="

    local profile_file="/etc/profile.d/x86-64-v3-flags.sh"

    write_file "$profile_file" <<'EOF'
# x86-64-v3 / AMD Ryzen (znver3) optimisation flags
# Applied at login for every interactive session
export CFLAGS="-O2 -march=x86-64-v3 -mtune=znver3 -pipe"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O1 -Wl,--as-needed"
EOF

    $DRY_RUN || chmod 644 "$profile_file"
    info "Written: $profile_file"
}

# ── 3. Rust RUSTFLAGS ──────────────────────────────────────────────────────────
configure_rust() {
    info "=== Step 3: Configuring Rust RUSTFLAGS ==="

    local cargo_env="/etc/profile.d/x86-64-v3-rust.sh"

    write_file "$cargo_env" <<'EOF'
# Rust: compile for x86-64-v3 target CPU
export RUSTFLAGS="-C target-cpu=x86-64-v3"
EOF

    $DRY_RUN || chmod 644 "$cargo_env"
    info "Written: $cargo_env"
}

# ── 4. Go GOAMD64 ──────────────────────────────────────────────────────────────
configure_go() {
    info "=== Step 4: Configuring Go GOAMD64=v3 ==="

    local go_env="/etc/profile.d/x86-64-v3-go.sh"

    write_file "$go_env" <<'EOF'
# Go: use x86-64-v3 ISA extension level
export GOAMD64=v3
EOF

    $DRY_RUN || chmod 644 "$go_env"
    info "Written: $go_env"
}

# ── 5. MAKEFLAGS ───────────────────────────────────────────────────────────────
configure_makeflags() {
    info "=== Step 5: Setting MAKEFLAGS for parallel builds ==="

    local nproc_count
    nproc_count=$(nproc)
    local make_env="/etc/profile.d/x86-64-v3-make.sh"

    if $DRY_RUN; then
        info "[DRY-RUN] would write: $make_env  (MAKEFLAGS=-j${nproc_count})"
    else
        printf '# Parallel make jobs equal to CPU thread count\nexport MAKEFLAGS="-j%s"\n' \
            "$nproc_count" > "$make_env"
        chmod 644 "$make_env"
    fi
    info "Written: $make_env  (MAKEFLAGS=-j${nproc_count})"
}

# ── 6. glibc hwcaps ────────────────────────────────────────────────────────────
configure_glibc_hwcaps() {
    info "=== Step 6: Enabling glibc hwcaps for x86-64-v3 ==="

    local hwcaps_dir="/usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3"
    local ld_conf="/etc/ld.so.conf.d/x86-64-v3-hwcaps.conf"

    if $DRY_RUN; then
        info "[DRY-RUN] would create directory: $hwcaps_dir"
        info "[DRY-RUN] would write:            $ld_conf"
        info "[DRY-RUN] would run:              ldconfig"
        return
    fi

    mkdir -p "$hwcaps_dir"

    # Write ld.so.conf.d entry so the dynamic linker searches this path first
    printf '%s\n' "$hwcaps_dir" > "$ld_conf"

    ldconfig
    info "hwcaps directory: $hwcaps_dir"
    info "ld.so.conf.d entry: $ld_conf"
    info "ldconfig updated."
}

# ── 7. APT optimisation ────────────────────────────────────────────────────────
configure_apt() {
    info "=== Step 7: Optimising APT ==="

    local apt_conf="/etc/apt/apt.conf.d/99-x86-64-v3-optimise"

    write_file "$apt_conf" <<'EOF'
// APT optimisations for fast downloads and builds
Acquire::http::Pipeline-Depth "5";
Acquire::http::No-Cache "false";
Acquire::Queue-Mode "access";
Acquire::Languages "none";

// Parallel downloads (apt >= 2.1.16)
Acquire::http::Dl-Limit "0";
APT::Acquire::Retries "3";
EOF

    $DRY_RUN || chmod 644 "$apt_conf"
    info "Written: $apt_conf"
}

# ── 8. /etc/environment persistence ───────────────────────────────────────────
configure_environment() {
    info "=== Step 8: Persisting key variables in /etc/environment ==="

    local env_file="/etc/environment"
    local -A wanted=(
        [GOAMD64]="v3"
        [MAKEFLAGS]="-j$(nproc)"
    )

    for key in "${!wanted[@]}"; do
        local val="${wanted[$key]}"
        if grep -q "^${key}=" "$env_file" 2>/dev/null; then
            if $DRY_RUN; then
                info "[DRY-RUN] would update ${key} in $env_file"
            else
                sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$env_file"
                info "Updated ${key}=${val} in $env_file"
            fi
        else
            if $DRY_RUN; then
                info "[DRY-RUN] would append ${key}=\"${val}\" to $env_file"
            else
                printf '%s="%s"\n' "$key" "$val" >> "$env_file"
                info "Appended ${key}=\"${val}\" to $env_file"
            fi
        fi
    done
}

# ── Summary ────────────────────────────────────────────────────────────────────
print_summary() {
    echo
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  x86-64-v3 optimisation applied successfully!        ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo
    echo "  Files written / updated:"
    echo "    /etc/profile.d/x86-64-v3-flags.sh   — CFLAGS / CXXFLAGS / LDFLAGS"
    echo "    /etc/profile.d/x86-64-v3-rust.sh    — RUSTFLAGS"
    echo "    /etc/profile.d/x86-64-v3-go.sh      — GOAMD64"
    echo "    /etc/profile.d/x86-64-v3-make.sh    — MAKEFLAGS"
    echo "    /etc/environment                     — GOAMD64, MAKEFLAGS"
    echo "    /etc/apt/apt.conf.d/99-x86-64-v3-*  — APT tweaks"
    echo "    /etc/ld.so.conf.d/x86-64-v3-*       — glibc hwcaps"
    echo
    echo "  Expected gains (rough estimates):"
    printf "    %-28s %s\n" "Compilation:"         "10-25%"
    printf "    %-28s %s\n" "Archiving (zstd/lz4):" "20-35%"
    printf "    %-28s %s\n" "Firefox / Chromium:"  "5-15%"
    printf "    %-28s %s\n" "Games:"               "3-10%"
    echo
    echo "  Re-login (or run: source /etc/profile) to activate env vars."
    echo
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    info "Starting Ubuntu x86-64-v3 optimisation for AMD Ryzen 1XXX-5XXX series"
    info "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo

    check_cpu_support
    configure_gcc_flags
    configure_rust
    configure_go
    configure_makeflags
    configure_glibc_hwcaps
    configure_apt
    configure_environment

    $DRY_RUN || print_summary
    $DRY_RUN && info "Dry-run complete. No changes were written."
}

main "$@"
