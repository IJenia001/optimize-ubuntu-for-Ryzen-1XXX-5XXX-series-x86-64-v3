#!/usr/bin/env bash

set -e

echo "======================================="
echo " Ubuntu x86-64-v3 Optimization Script "
echo "======================================="

# Проверка CPU
echo "Checking CPU support..."

if grep -q avx2 /proc/cpuinfo; then
    echo "AVX2 supported ✔"
else
    echo "CPU does NOT support x86-64-v3"
    exit 1
fi

CORES=$(nproc)

echo "Detected CPU cores: $CORES"

echo
echo "Applying compiler optimizations..."

sudo tee /etc/profile.d/x86_64_v3.sh > /dev/null <<EOF
export CFLAGS="-O3 -march=x86-64-v3 -mtune=znver3 -pipe -fomit-frame-pointer"
export CXXFLAGS="\$CFLAGS"
export RUSTFLAGS="-C target-cpu=x86-64-v3"
export GOAMD64=v3
export MAKEFLAGS="-j$CORES"
EOF

chmod +x /etc/profile.d/x86_64_v3.sh

echo "Compiler flags applied."

echo
echo "Configuring APT optimizations..."

sudo tee /etc/apt/apt.conf.d/99performance > /dev/null <<EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
Acquire::Retries "3";
Acquire::http::Pipeline-Depth "5";
Acquire::Languages "none";
EOF

echo "APT optimized."

echo
echo "Enabling glibc hwcaps directories..."

sudo mkdir -p /usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3
sudo mkdir -p /lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3

echo "glibc hwcaps ready."

echo
echo "Applying sysctl CPU optimizations..."

sudo tee /etc/sysctl.d/99-cpu-performance.conf > /dev/null <<EOF
kernel.sched_autogroup_enabled=0
kernel.sched_migration_cost_ns=5000000
kernel.sched_min_granularity_ns=10000000
kernel.sched_wakeup_granularity_ns=15000000
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF

sudo sysctl --system

echo "Kernel tuning applied."

echo
echo "Optimizing build tools..."

sudo tee /etc/makepkg.conf >/dev/null <<EOF
CFLAGS="-O3 -march=x86-64-v3 -mtune=znver3 -pipe -fomit-frame-pointer"
CXXFLAGS="\$CFLAGS"
MAKEFLAGS="-j$CORES"
EOF

echo
echo "Cleaning package cache..."

sudo apt clean

echo
echo "======================================="
echo "Optimization complete!"
echo "Reboot recommended."
echo "======================================="
