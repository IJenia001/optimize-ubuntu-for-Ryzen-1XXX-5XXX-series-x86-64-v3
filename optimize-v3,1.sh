#!/usr/bin/env bash

set -e

echo "======================================"
echo " Ubuntu Extreme Optimization Script "
echo " x86-64-v3 / Ryzen tuning"
echo "======================================"

# Проверка CPU
echo "Checking CPU features..."

if grep -q avx2 /proc/cpuinfo; then
    echo "AVX2 supported"
else
    echo "CPU does not support x86-64-v3"
    exit 1
fi

CORES=$(nproc)

echo "CPU cores: $CORES"

echo
echo "Applying compiler optimizations..."

sudo tee /etc/profile.d/99-x86-64-v3.sh > /dev/null <<EOF
export CFLAGS="-O3 -march=x86-64-v3 -mtune=znver3 -pipe -fomit-frame-pointer -fno-plt"
export CXXFLAGS="\$CFLAGS"
export RUSTFLAGS="-C target-cpu=x86-64-v3"
export GOAMD64=v3
export MAKEFLAGS="-j$CORES"
EOF

sudo chmod +x /etc/profile.d/99-x86-64-v3.sh

echo
echo "Configuring APT performance..."

sudo tee /etc/apt/apt.conf.d/99-performance > /dev/null <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "5";
Acquire::http::Pipeline-Depth "10";
Acquire::Languages "none";
DPkg::Use-Pty "0";
EOF

echo
echo "Creating glibc hwcaps directories..."

sudo mkdir -p /usr/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3
sudo mkdir -p /lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v3

echo
echo "Applying kernel performance tuning..."

sudo tee /etc/sysctl.d/99-performance.conf > /dev/null <<EOF
kernel.sched_autogroup_enabled=0
kernel.sched_latency_ns=6000000
kernel.sched_min_granularity_ns=750000
kernel.sched_wakeup_granularity_ns=1000000
kernel.sched_migration_cost_ns=5000000

vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.vfs_cache_pressure=50

vm.max_map_count=1048576
vm.compaction_proactiveness=0

fs.file-max=2097152
EOF

sudo sysctl --system

echo
echo "Enabling Transparent HugePages tuning..."

sudo tee /etc/systemd/system/disable-thp.service > /dev/null <<EOF
[Unit]
Description=Disable Transparent Huge Pages

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/sh -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable disable-thp

echo
echo "Systemd CPU tuning..."

sudo mkdir -p /etc/systemd/system.conf.d

sudo tee /etc/systemd/system.conf.d/cpu-performance.conf > /dev/null <<EOF
[Manager]
DefaultCPUAccounting=yes
DefaultMemoryAccounting=yes
DefaultTasksAccounting=yes
EOF

echo
echo "I/O scheduler tuning..."

for disk in /sys/block/*/queue/scheduler; do
    echo mq-deadline | sudo tee \$disk > /dev/null || true
done

echo
echo "Setting CPU governor to performance..."

sudo tee /etc/systemd/system/cpu-performance.service > /dev/null <<EOF
[Unit]
Description=CPU performance mode

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > \$cpu; done'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable cpu-performance

echo
echo "Optimizing build tools..."

sudo tee /etc/make.conf > /dev/null <<EOF
CFLAGS="-O3 -march=x86-64-v3 -mtune=znver3 -pipe"
CXXFLAGS="\$CFLAGS"
MAKEFLAGS="-j$CORES"
EOF

echo
echo "Cleaning system..."

sudo apt clean

echo
echo "======================================"
echo "Optimization finished"
echo "Reboot recommended"
echo "======================================"
