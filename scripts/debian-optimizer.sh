#!/bin/bash
# https://github.com/amirmohamadamini/linux-optimizer
# Forked from https://github.com/hawshemi/Linux-Optimizer


# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2 2>/dev/null
    echo "[*] ----- $1"
    tput sgr0 2>/dev/null
}

yellow_msg() {
    tput setaf 3 2>/dev/null
    echo "[*] ----- $1"
    tput sgr0 2>/dev/null
}

red_msg() {
    tput setaf 1 2>/dev/null
    echo "[*] ----- $1"
    tput sgr0 2>/dev/null
}


# Declare Paths & Settings.
SYS_PATH="/etc/sysctl.conf"
SYSCTL_DROPIN="/etc/sysctl.d/99-linux-optimizer.conf"
PROF_PATH="/etc/profile"
SSH_PORT=""
SSH_PATH="/etc/ssh/sshd_config"
SSH_DROPIN="/etc/ssh/sshd_config.d/01-linux-optimizer.conf"
SWAP_PATH="/swapfile"
SWAP_SIZE_MB=2048

## Never stop for dpkg config-file questions or the needrestart dialog.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)


# Root
check_if_running_as_root() {
    ## If you want to run as another user, please modify $EUID to be owned by this user
    if [[ "$EUID" -ne '0' ]]; then
      echo
      red_msg 'Error: You must run this script as root!'
      echo
      sleep 0.5
      exit 1
    fi
}


# Check Root
check_if_running_as_root
sleep 0.5


# Helpers
apt_get() {
    apt-get "${APT_OPTS[@]}" "$@"
}

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'
}

## LXC, OpenVZ, Docker, ... share the host kernel: no custom kernel, no own swap.
is_container() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        systemd-detect-virt -cq
    else
        [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qa 'container=' /proc/1/environ 2>/dev/null
    fi
}

## Keep the very first backup, so running the script again doesn't overwrite the original file.
backup_once() {
    if [ -e "$1" ] && [ ! -e "$1.bak" ]; then
        cp -pL "$1" "$1.bak"
        yellow_msg "Default $1 saved. Directory: $1.bak"
    fi
}

## Ask a y/n question. Returns 0 for yes.
ask_yes_no() {
    local answer
    while true; do
        yellow_msg "$1 (y/n)"
        ## No more input (closed SSH session, piped input): treat as "no" instead of looping forever.
        read -r answer || { echo; return 1; }
        echo
        case "$answer" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
        esac
    done
}

## Install what is available and report the rest, instead of failing the whole list
## because one package was dropped from this release (e.g. software-properties-common on Debian 13).
apt_install_available() {
    local pkg available=() missing=()
    for pkg in "$@"; do
        if apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        yellow_msg "Not available on this release, skipped: ${missing[*]}"
    fi
    if [ ${#available[@]} -gt 0 ]; then
        apt_get install "${available[@]}"
    fi
}

# Ask Reboot
ask_reboot() {
    if ask_yes_no 'Reboot now? (Recommended)'; then
        sleep 0.5
        reboot
        exit 0
    fi
}


## Older versions of this script added XanMod's "releases" suite, which no longer exists
## and makes "apt update" fail. Point it to this release's suite instead.
fix_old_xanmod_repo() {
    local list="/etc/apt/sources.list.d/xanmod-release.list"
    if [ -f "$list" ] && grep -q ' releases main' "$list"; then
        . /etc/os-release
        sed -i "s/ releases main/ $VERSION_CODENAME main/" "$list"
        yellow_msg "Fixed the old XanMod repository entry ($list)."
    fi
}


# Update & Upgrade & Remove & Clean
complete_update() {
    echo
    yellow_msg 'Updating the System... (This can take a while.)'
    echo
    sleep 0.5

    fix_old_xanmod_repo

    apt_get update
    apt_get upgrade
    apt_get full-upgrade
    apt_get autoremove --purge
    apt_get autoclean
    apt_get clean

    limit_journal

    echo
    green_msg 'System Updated & Cleaned Successfully.'
    echo
    sleep 0.5
}


# Cap the systemd journal, so logs can't fill up a small disk.
limit_journal() {
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/99-linux-optimizer.conf <<'EOF'
[Journal]
SystemMaxUse=200M
EOF
    systemctl restart systemd-journald >/dev/null 2>&1
    journalctl --vacuum-size=200M >/dev/null 2>&1

    green_msg 'Journal logs limited to 200MB.'
}


# Install XanMod Kernel
install_xanmod() {
    echo
    yellow_msg 'Checking XanMod...'
    echo
    sleep 0.5

    if uname -r | grep -q 'xanmod'; then
        green_msg 'XanMod is already installed.'
        echo
        sleep 0.5
        return 0
    fi

    ## Cases where a new kernel can't (or must not) be installed.
    if [ "$(uname -m)" != "x86_64" ]; then
        red_msg 'XanMod only supports x86-64 CPUs. Skipping.'
        echo
        return 0
    fi
    if is_container; then
        red_msg 'This server is a container (LXC/OpenVZ/...) and uses the host kernel. Skipping XanMod.'
        echo
        return 0
    fi
    if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; then
        red_msg 'Secure Boot is enabled; the unsigned XanMod kernel would not boot. Skipping.'
        echo
        return 0
    fi

    ## XanMod publishes one suite per release (noble, resolute, bookworm, trixie, ...).
    . /etc/os-release
    local codename="$VERSION_CODENAME"
    if ! curl -fsS --max-time 20 -o /dev/null "http://deb.xanmod.org/dists/$codename/Release"; then
        red_msg "XanMod has no packages for '$codename' (needs Ubuntu 24.04+ / Debian 12+) or deb.xanmod.org is unreachable. Skipping."
        echo
        sleep 2
        return 0
    fi

    echo
    yellow_msg 'XanMod not found. Installing XanMod Kernel...'
    echo
    sleep 0.5

    ## Install dependencies
    apt_get update
    apt_get install wget curl gpg

    ## Check the CPU level
    cpu_level=$(awk -f - <<EOF
    BEGIN {
        while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
        if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
        if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
        if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
        if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
        if (level > 0) { print level; exit level + 1 }
        exit 1
    }
EOF
    )

    if [[ ! "$cpu_level" =~ ^[1-4]$ ]]; then
        echo
        red_msg "Unsupported CPU. (Check the supported CPUs at xanmod.org)"
        echo
        sleep 2
        return 0
    fi

    echo
    yellow_msg "CPU Level: v$cpu_level"
    echo

    ## XanMod no longer builds x64v4 (v3 runs on those CPUs), and x64v1 only exists as LTS.
    local kernel_pkg
    case "$cpu_level" in
        1) kernel_pkg="linux-xanmod-lts-x64v1" ;;
        4) kernel_pkg="linux-xanmod-x64v3" ;;
        *) kernel_pkg="linux-xanmod-x64v$cpu_level" ;;
    esac

    ## Add the XanMod repository key
    local tmp_keyring="/tmp/xanmod-archive-keyring.gpg"

    # Try downloading the GPG key from the XanMod link first, then the GitLab mirror.
    if ! wget -qO $tmp_keyring https://dl.xanmod.org/archive.key || ! [ -s $tmp_keyring ]; then
        if ! wget -qO $tmp_keyring https://gitlab.com/afrd.gpg || ! [ -s $tmp_keyring ]; then
            red_msg "Both attempts to download the XanMod GPG key failed. Skipping XanMod."
            echo
            rm -f $tmp_keyring
            return 1
        fi
    fi

    gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg $tmp_keyring
    rm -f $tmp_keyring

    ## Add the XanMod repository
    echo "deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $codename main" > /etc/apt/sources.list.d/xanmod-release.list

    ## Install XanMod
    apt_get update
    if ! apt-cache policy "$kernel_pkg" | grep -q 'Candidate: [^(]'; then
        kernel_pkg="linux-xanmod-lts-x64v$(( cpu_level > 3 ? 3 : cpu_level ))"
    fi
    if ! apt_get install "$kernel_pkg"; then
        red_msg "Installing $kernel_pkg failed."
        echo
        sleep 2
        return 1
    fi

    ## Clean up
    apt_get autoremove --purge

    echo
    green_msg "XanMod Kernel ($kernel_pkg) Installed. Reboot to Apply the new Kernel."
    echo
    sleep 1
}


# Install useful packages
installations() {
    echo
    yellow_msg 'Installing Useful Packages...'
    echo
    sleep 0.5

    apt_get update

    ## Networking packages
    apt_install_available apt-transport-https vnstat nload wireguard-tools iperf3 mtr-tiny bind9-dnsutils

    ## System utilities
    apt_install_available apt-utils bash-completion busybox ca-certificates cron curl gnupg2 locales lsb-release nano preload screen software-properties-common ufw unzip vim wget xxd zip ncdu

    ## Programming and development tools
    apt_install_available autoconf automake build-essential git libtool make pkg-config python3 python3-pip

    ## Additional libraries and dependencies
    apt_install_available bc binutils binutils-common binutils-x86-64-linux-gnu debian-archive-keyring haveged jq libsodium-dev libsqlite3-dev libssl-dev qrencode socat

    ## Miscellaneous
    apt_install_available dialog htop btop net-tools certbot

    echo
    green_msg 'Useful Packages Installed Succesfully.'
    echo
    sleep 0.5
}


# Enable packages at server boot
enable_packages() {
    local svc
    for svc in cron haveged preload vnstat; do
        if systemctl enable --now "$svc" >/dev/null 2>&1; then
            green_msg "Enabled: $svc"
        else
            yellow_msg "Not available, skipped: $svc"
        fi
    done
    echo
    green_msg 'Packages Enabled Successfully.'
    echo
    sleep 0.5
}


## Swap Maker
swap_maker() {
    echo
    yellow_msg 'Making SWAP Space...'
    echo
    sleep 0.5

    ## The VPS may come with swap already (or this script made it before).
    local current
    current=$(swapon --show=NAME,SIZE --noheadings 2>/dev/null)
    if [ -n "$current" ]; then
        green_msg 'SWAP space already exists, skipping:'
        echo "$current"
        echo
        sleep 0.5
        return 0
    fi

    if is_container; then
        red_msg 'This server is a container (LXC/OpenVZ/...) and cannot have its own SWAP. Skipping.'
        echo
        return 0
    fi

    ## Swap file left over but not active? Try to just turn it on.
    if [ -f "$SWAP_PATH" ] && swapon "$SWAP_PATH" 2>/dev/null; then
        yellow_msg "Re-activated existing $SWAP_PATH."
    else
        local avail_mb
        avail_mb=$(df -Pm / | awk 'NR == 2 {print $4}')
        if [ "$avail_mb" -lt $(( SWAP_SIZE_MB + 1024 )) ]; then
            red_msg "Not enough free disk space for ${SWAP_SIZE_MB}MB SWAP (${avail_mb}MB free). Skipping."
            echo
            return 1
        fi

        rm -f "$SWAP_PATH"
        touch "$SWAP_PATH"
        chattr +C "$SWAP_PATH" 2>/dev/null           ## Btrfs needs No-CoW swap files
        chmod 600 "$SWAP_PATH"                      ## Set proper permission
        ## fallocate isn't supported on every filesystem; fall back to dd.
        fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_PATH" 2>/dev/null \
            || dd if=/dev/zero of="$SWAP_PATH" bs=1M count="$SWAP_SIZE_MB" status=none
        mkswap "$SWAP_PATH"                         ## Setup swap
        if ! swapon "$SWAP_PATH"; then              ## Enable swap
            red_msg 'Could not enable SWAP.'
            rm -f "$SWAP_PATH"
            echo
            return 1
        fi
    fi

    ## Add to fstab (once)
    if ! grep -qE "^[[:space:]]*${SWAP_PATH}[[:space:]]" /etc/fstab; then
        echo "$SWAP_PATH   none    swap    sw    0   0" >> /etc/fstab
    fi

    echo
    green_msg 'SWAP Created Successfully.'
    echo
    sleep 0.5
}


# SYSCTL Optimization
sysctl_optimizations() {
    echo
    yellow_msg 'Optimizing the Network...'
    echo
    sleep 0.5

    ## Settings go to their own file in /etc/sysctl.d. Debian 13 and Ubuntu 26.04 don't have
    ## /etc/sysctl.conf at all, so anything written there would be lost on reboot.
    ## Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf

cat <<EOF > "$SYSCTL_DROPIN"
# $SYSCTL_DROPIN
# Created by linux-optimizer. Running the script again overwrites this file.
# Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf


## File system settings
## ----------------------------------------------------------------

# Set the maximum number of open file descriptors
fs.file-max = 67108864


## Network core settings
## ----------------------------------------------------------------

# Specify default queuing discipline for network devices
net.core.default_qdisc = fq

# Configure maximum network device backlog
net.core.netdev_max_backlog = 32768

# Set maximum socket receive buffer
net.core.optmem_max = 262144

# Define maximum backlog of pending connections
net.core.somaxconn = 65536

# Configure maximum TCP receive buffer size
net.core.rmem_max = 33554432

# Set default TCP receive buffer size
net.core.rmem_default = 1048576

# Configure maximum TCP send buffer size
net.core.wmem_max = 33554432

# Set default TCP send buffer size
net.core.wmem_default = 1048576


## TCP settings
## ----------------------------------------------------------------

# Define socket receive buffer sizes
net.ipv4.tcp_rmem = 16384 1048576 33554432

# Specify socket send buffer sizes
net.ipv4.tcp_wmem = 16384 1048576 33554432

# Set TCP congestion control algorithm to BBR
net.ipv4.tcp_congestion_control = bbr

# Configure TCP FIN timeout period
net.ipv4.tcp_fin_timeout = 25

# Set keepalive time (seconds)
net.ipv4.tcp_keepalive_time = 1200

# Configure keepalive probes count and interval
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30

# Define maximum orphaned TCP sockets
net.ipv4.tcp_max_orphans = 819200

# Set maximum TCP SYN backlog
net.ipv4.tcp_max_syn_backlog = 20480

# Configure maximum TCP Time Wait buckets
net.ipv4.tcp_max_tw_buckets = 1440000

# Define TCP memory limits
net.ipv4.tcp_mem = 65536 1048576 33554432

# Enable TCP MTU probing
net.ipv4.tcp_mtu_probing = 1

# Define minimum amount of data in the send buffer before TCP starts sending
net.ipv4.tcp_notsent_lowat = 32768

# Specify retries for TCP socket to establish connection
net.ipv4.tcp_retries2 = 8

# Enable TCP SACK and DSACK
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1

# Disable TCP slow start after idle
net.ipv4.tcp_slow_start_after_idle = 0

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2

# Enable TCP ECN
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1

# Enable the use of TCP SYN cookies to help protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1


## UDP settings
## ----------------------------------------------------------------

# Define UDP memory limits
net.ipv4.udp_mem = 65536 1048576 33554432


## UNIX domain sockets
## ----------------------------------------------------------------

# Set maximum queue length of UNIX domain sockets
net.unix.max_dgram_qlen = 256


## Virtual memory (VM) settings
## ----------------------------------------------------------------

# Specify minimum free Kbytes at which VM pressure happens
vm.min_free_kbytes = 65536

# Define how aggressively swap memory pages are used
vm.swappiness = 10

# Set the tendency of the kernel to reclaim memory used for caching of directory and inode objects
vm.vfs_cache_pressure = 250


## Network Configuration
## ----------------------------------------------------------------

# Configure reverse path filtering
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2

# Disable source route acceptance
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Neighbor table settings
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60

# ARP settings
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# Kernel panic timeout
kernel.panic = 1

# Set dirty page ratio for virtual memory
vm.dirty_ratio = 20

# Use the kernel's default (heuristic) memory overcommit.
# Strict mode (2) makes Java, Node.js, databases, Docker, ... fail with
# "Cannot allocate memory" on small servers even when RAM is free.
vm.overcommit_memory = 0
EOF

    ## /etc/sysctl.conf (where it still exists) is applied after our file and would win,
    ## so remove the keys we manage from it, plus what older versions of this script appended there.
    if [ -f "$SYS_PATH" ]; then
        backup_once "$SYS_PATH"
        local key
        for key in $(awk -F'=' '/^[a-z]/ {gsub(/[ \t]/, "", $1); print $1}' "$SYSCTL_DROPIN") vm.overcommit_ratio; do
            sed -i "/^[[:space:]]*${key//./\\.}[[:space:]]*=/d" "$SYS_PATH"
        done
        sed -i -e '/^#/d' -e '/^$/d' "$SYS_PATH"
    fi

    ## Load BBR at boot (it's built into XanMod, a module on stock kernels).
    echo 'tcp_bbr' > /etc/modules-load.d/linux-optimizer.conf
    modprobe tcp_bbr 2>/dev/null

    sysctl -p "$SYSCTL_DROPIN"

    echo
    green_msg 'Network is Optimized.'
    echo
    sleep 0.5
}


# Find the SSH port(s) and set them in the SSH_PORT variable
find_ssh_port() {
    echo
    yellow_msg "Finding SSH port..."
    echo

    ## sshd -T shows the effective config (including sshd_config.d); ssh.socket is used
    ## for socket activation on Ubuntu 22.10+. The grep is a fallback if sshd -T fails.
    SSH_PORT=$(
        {
            sshd -T 2>/dev/null | awk '$1 == "port" {print $2}'
            systemctl show -p Listen ssh.socket 2>/dev/null | grep -oE ':[0-9]+ ' | tr -d ': '
            grep -hoP '^\s*Port\s+\K\d+' "$SSH_PATH" /etc/ssh/sshd_config.d/*.conf 2>/dev/null
        } | sort -un | xargs
    )

    if [ -n "$SSH_PORT" ]; then
        green_msg "SSH port found: $SSH_PORT"
    else
        SSH_PORT=22
        green_msg "SSH port is default 22."
    fi
    echo
    sleep 0.5
}


# Optimize SSH
update_sshd_conf() {
    echo
    yellow_msg 'Optimizing SSH...'
    echo
    sleep 0.5

    if [ ! -f "$SSH_PATH" ]; then
        red_msg "SSH configuration file not found at $SSH_PATH. Skipping."
        echo
        return 1
    fi
    backup_once "$SSH_PATH"

    local settings="UseDNS no
Compression yes
TCPKeepAlive yes
ClientAliveInterval 3000
ClientAliveCountMax 100
AllowTcpForwarding yes
GatewayPorts yes
PermitTunnel yes
X11Forwarding yes"

    if grep -qiE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' "$SSH_PATH"; then
        ## sshd uses the first value it reads, and sshd_config.d is read first,
        ## so a "01-" drop-in also wins over e.g. cloud-init's 50-cloud-init.conf.
        echo "# Created by linux-optimizer." > "$SSH_DROPIN"
        echo "$settings" >> "$SSH_DROPIN"
    else
        ## Old sshd_config without drop-ins: replace the lines in the main file.
        local key
        for key in $(echo "$settings" | awk '{print $1}'); do
            sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]]/Id" "$SSH_PATH"
        done
        echo "$settings" >> "$SSH_PATH"
    fi

    ## Never restart sshd with a broken config; that would lock you out.
    if ! sshd -t; then
        red_msg 'The new SSH config is invalid. Rolling back.'
        rm -f "$SSH_DROPIN"
        cp -p "$SSH_PATH.bak" "$SSH_PATH"
        echo
        return 1
    fi

    ## Restart the SSH service to apply the changes
    systemctl restart ssh 2>/dev/null || systemctl restart sshd

    echo
    green_msg 'SSH is Optimized.'
    echo
    sleep 0.5
}


# System Limits Optimizations
limits_optimizations() {
    echo
    yellow_msg 'Optimizing System Limits...'
    echo
    sleep 0.5

    ## Clear old ulimits
    sed -i '/ulimit -[cdfilmnqstuvx]/d' $PROF_PATH

    ## Add new ulimits. Errors are hidden: normal users can't raise every limit
    ## and would see "Operation not permitted" on every login otherwise.
    cat >> $PROF_PATH <<'EOF'
ulimit -c unlimited 2>/dev/null
ulimit -d unlimited 2>/dev/null
ulimit -f unlimited 2>/dev/null
ulimit -i unlimited 2>/dev/null
ulimit -l unlimited 2>/dev/null
ulimit -m unlimited 2>/dev/null
ulimit -n 1048576 2>/dev/null
ulimit -q unlimited 2>/dev/null
ulimit -s -H 65536 2>/dev/null
ulimit -s 32768 2>/dev/null
ulimit -t unlimited 2>/dev/null
ulimit -u unlimited 2>/dev/null
ulimit -v unlimited 2>/dev/null
ulimit -x unlimited 2>/dev/null
EOF

    ## /etc/profile only affects login shells. Services (xray, nginx, ...) started by
    ## systemd never read it, so raise the open files limit for them too.
    mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d
    cat > /etc/security/limits.d/99-linux-optimizer.conf <<'EOF'
*       soft    nofile  1048576
*       hard    nofile  1048576
root    soft    nofile  1048576
root    hard    nofile  1048576
EOF
    cat > /etc/systemd/system.conf.d/99-linux-optimizer.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1048576
EOF

    echo
    green_msg 'System Limits are Optimized. (Services get the new limits after a reboot.)'
    echo
    sleep 0.5
}


# UFW Optimizations
ufw_optimizations() {
    echo
    yellow_msg 'Installing & Optimizing UFW...'
    echo
    sleep 0.5

    ## Purge firewalld to install UFW.
    if is_installed firewalld; then
        apt_get purge firewalld
    fi

    ## Install UFW if it isn't installed.
    if ! is_installed ufw; then
        apt_get update
        apt_get install ufw
    fi

    ## Disable UFW
    ufw disable

    ## Open default ports. SSH first, so you are never locked out.
    local port
    for port in ${SSH_PORT:-22}; do
        ufw allow "$port/tcp"
    done
    ufw allow 80/tcp
    ufw allow 80/udp
    ufw allow 443/tcp
    ufw allow 443/udp
    sleep 0.5

    ## Let UFW load our sysctl settings instead of its own (which would override them).
    if [ -f "$SYSCTL_DROPIN" ]; then
        sed -i "s|^IPT_SYSCTL=.*|IPT_SYSCTL=$SYSCTL_DROPIN|" /etc/default/ufw
    fi

    ## Enable & Reload
    ufw --force enable
    ufw reload
    echo
    green_msg 'UFW is Installed & Optimized. (Open your custom ports manually.)'
    echo
    sleep 0.5
}


# Fail2ban for SSH brute-force protection
install_fail2ban() {
    echo
    yellow_msg 'Installing & Configuring Fail2ban...'
    echo
    sleep 0.5

    apt_get update
    apt_install_available fail2ban python3-systemd
    if ! is_installed fail2ban; then
        red_msg 'Fail2ban could not be installed.'
        echo
        return 1
    fi

    [ -z "$SSH_PORT" ] && find_ssh_port

    ## Read SSH logins from the journal: Debian 12+ and minimal images have no /var/log/auth.log.
    ## OpenSSH 9.8+ logs from "sshd-session", so match the whole unit instead of the process name.
    mkdir -p /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/linux-optimizer.local <<EOF
# Created by linux-optimizer.
[sshd]
enabled      = true
port         = ${SSH_PORT// /,}
backend      = systemd
journalmatch = _SYSTEMD_UNIT=ssh.service + _SYSTEMD_UNIT=sshd.service
maxretry     = 5
findtime     = 10m
bantime      = 1h
ignoreip     = 127.0.0.1/8 ::1
EOF
    if ! command -v iptables >/dev/null 2>&1; then
        echo "banaction    = nftables-multiport" >> /etc/fail2ban/jail.d/linux-optimizer.local
    fi

    systemctl enable fail2ban >/dev/null 2>&1
    systemctl restart fail2ban
    sleep 2

    if fail2ban-client status sshd >/dev/null 2>&1; then
        echo
        green_msg 'Fail2ban is protecting SSH. (5 failed logins in 10 min = 1 hour ban)'
    else
        echo
        red_msg 'Fail2ban did not start. Check: journalctl -u fail2ban'
    fi
    echo
    sleep 0.5
}


# Install Nginx from the official nginx.org repository (newer than the distro's)
# https://nginx.org/en/linux_packages.html
install_nginx() {
    echo
    yellow_msg 'Installing Nginx from the official nginx.org repository...'
    echo 
    sleep 0.5

    . /etc/os-release
    local arch branch repo_path old_user="" backup="" migrate=0
    arch=$(dpkg --print-architecture)
    if [ "$arch" != "amd64" ] && [ "$arch" != "arm64" ]; then
        red_msg "nginx.org has no packages for $arch (only amd64 & arm64). Skipping."
        echo 
        return 1
    fi

    ## Mainline gets new features first and is what nginx.org recommends; stable only gets critical fixes.
    yellow_msg 'Which branch? [m] mainline (newest, recommended) / [s] stable. (Enter = mainline)'
    read -r branch || branch=""
    echo 
    if [[ "$branch" == "s" || "$branch" == "S" ]]; then
        branch="stable"
        repo_path="packages/$ID"
    else
        branch="mainline"
        repo_path="packages/mainline/$ID"
    fi

    if ! curl -fsS --max-time 20 -o /dev/null "https://nginx.org/$repo_path/dists/$VERSION_CODENAME/Release"; then
        red_msg "nginx.org has no packages for '$VERSION_CODENAME' (needs Ubuntu 22.04+ / Debian 11+) or nginx.org is unreachable. Skipping."
        echo 
        return 1
    fi

    apt_get update
    apt_install_available curl gnupg2 ca-certificates lsb-release

    ## Add the signing key and make sure it's the one published in the nginx docs.
    local tmp_key="/tmp/nginx_signing.key" gnupg_tmp
    if ! curl -fsSL --max-time 30 -o "$tmp_key" https://nginx.org/keys/nginx_signing.key || ! [ -s "$tmp_key" ]; then
        red_msg 'Could not download the nginx signing key. Skipping.'
        echo 
        rm -f "$tmp_key"
        return 1
    fi
    gpg --dearmor --yes -o /usr/share/keyrings/nginx-archive-keyring.gpg "$tmp_key"
    rm -f "$tmp_key"

    gnupg_tmp=$(mktemp -d)
    if ! GNUPGHOME="$gnupg_tmp" gpg --dry-run --quiet --no-keyring --import --import-options import-show \
            /usr/share/keyrings/nginx-archive-keyring.gpg 2>/dev/null | grep -q '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62'; then
        red_msg 'The nginx signing key does not match the official fingerprint. Skipping.'
        echo 
        rm -rf "$gnupg_tmp" /usr/share/keyrings/nginx-archive-keyring.gpg
        return 1
    fi
    rm -rf "$gnupg_tmp"

    ## Add the repository, and pin it so its packages win over the distro's.
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/$repo_path $VERSION_CODENAME nginx" > /etc/apt/sources.list.d/nginx.list
    printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx

    ## Switching from the distro's nginx? Its nginx.conf gets replaced by one that only reads
    ## conf.d/*.conf and runs as "nginx", so existing sites (and PHP-FPM sockets) would stop working.
    if is_installed nginx-common && [ -f /etc/nginx/nginx.conf ]; then
        migrate=1
        backup="/etc/nginx.distro-backup-$(date +%Y%m%d-%H%M%S)"
        cp -a /etc/nginx "$backup"
        old_user=$(awk '$1 == "user" {sub(/;$/, "", $2); print $2; exit}' /etc/nginx/nginx.conf)
        yellow_msg "Replacing the distro's nginx. Old config saved. Directory: $backup"
    fi

    ## logrotate's recommends would pull in a mail server on minimal systems.
    apt_get update
    if ! apt_get install --no-install-recommends nginx logrotate; then
        red_msg 'Installing Nginx failed.'
        echo 
        return 1
    fi

    if [ "$migrate" = 1 ]; then
        if [ -n "$old_user" ]; then
            sed -i "s/^user .*;/user $old_user;/" /etc/nginx/nginx.conf
        fi
        if ls /etc/nginx/sites-enabled/* >/dev/null 2>&1; then
            ## Keep serving the old sites; nginx.org's default site would clash with them on port 80.
            sed -i 's|^\([[:space:]]*\)include /etc/nginx/conf.d/\*\.conf;|&\n\1include /etc/nginx/sites-enabled/*;|' /etc/nginx/nginx.conf
            [ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
        fi
    fi

    ## certbot plugin, so "certbot --nginx" can get & renew SSL certificates.
    apt_install_available python3-certbot-nginx

    if ufw status 2>/dev/null | grep -q 'Status: active'; then
        ufw allow 80/tcp >/dev/null
        ufw allow 443/tcp >/dev/null
        ufw allow 443/udp >/dev/null
    fi

    if ! nginx -t; then
        red_msg "Nginx is installed, but its config has errors. Fix them, then: systemctl restart nginx"
        [ -n "$backup" ] && red_msg "Your old config is in $backup"
        echo 
        return 1
    fi
    systemctl enable nginx >/dev/null 2>&1
    systemctl restart nginx

    echo 
    green_msg "$(nginx -v 2>&1 | sed 's/^nginx version: //') ($branch) Installed from nginx.org."
    green_msg 'Put your sites in /etc/nginx/conf.d/*.conf. Get SSL with: certbot --nginx'
    echo 
    sleep 0.5
}


# Show the current state of the server
show_status() {
    . /etc/os-release
    local swap
    swap=$(swapon --show=NAME,SIZE --noheadings 2>/dev/null | xargs)

    echo
    yellow_msg 'Server Status:'
    echo
    echo "  OS:                 $PRETTY_NAME"
    echo "  Kernel:             $(uname -r)"
    echo "  Virtualization:     $(systemd-detect-virt 2>/dev/null || echo unknown)"
    echo "  CPU / RAM:          $(nproc) cores / $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  SWAP:               ${swap:-none}"
    echo "  Disk free (/):      $(df -Ph / | awk 'NR == 2 {print $4}')"
    echo "  Congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    echo "  Queue discipline:   $(sysctl -n net.core.default_qdisc 2>/dev/null)"
    echo "  Open files limit:   $(ulimit -n)"
    echo "  UFW:                $(ufw status 2>/dev/null | head -1 | awk '{print $2}')"
    echo "  Fail2ban:           $(systemctl is-active fail2ban 2>/dev/null)"
    echo "  Nginx:              $(nginx -v 2>&1 | sed -n 's/^nginx version: //p')"
    echo
}


# Show the Menu
show_menu() {
    echo
    yellow_msg 'Choose One Option: '
    echo
    green_msg '1  - Apply Everything + XanMod Kernel. (RECOMMENDED)'
    echo
    green_msg '2  - Install XanMod Kernel.'
    echo
    green_msg '3  - Complete Update + Useful Packages + Make SWAP + Optimize Network, SSH & System Limits + UFW'
    green_msg '4  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits + UFW'
    green_msg '5  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits'
    echo
    green_msg '6  - Complete Update & Clean the OS.'
    green_msg '7  - Install Useful Packages.'
    green_msg '8  - Make SWAP (2Gb). (Skipped if SWAP already exists)'
    green_msg '9  - Optimize the Network, SSH & System Limits.'
    echo
    green_msg '10 - Optimize the Network settings.'
    green_msg '11 - Optimize the SSH settings.'
    green_msg '12 - Optimize the System Limits.'
    echo
    green_msg '13 - Install & Optimize UFW.'
    green_msg '14 - Install Fail2ban (SSH brute-force protection).'
    green_msg '15 - Install Nginx from the official nginx.org repository.'
    echo
    green_msg 's  - Show Server Status.'
    red_msg 'q  - Exit.'
    echo
}



done_msg() {
    echo
    green_msg '========================='
    green_msg  'Done.'
    green_msg '========================='
}


# Choosing Program
main() {
    while true; do
        show_menu
        read -r -p 'Enter Your Choice: ' choice || exit 0
        case $choice in
        1)
            apply_everything
            done_msg
            ask_reboot
            ;;
        2)
            complete_update
            sleep 0.5

            install_xanmod
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        3)
            complete_update
            sleep 0.5

            installations
            enable_packages
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            find_ssh_port
            ufw_optimizations
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        4)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            find_ssh_port
            ufw_optimizations
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        5)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        6)
            complete_update
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        7)
            complete_update
            sleep 0.5

            installations
            enable_packages
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        8)
            swap_maker
            sleep 0.5

            done_msg
            ;;
        9)
            sysctl_optimizations
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        10)
            sysctl_optimizations
            sleep 0.5

            done_msg
            ;;
        11)
            update_sshd_conf
            sleep 0.5

            done_msg
            ;;
        12)
            limits_optimizations
            sleep 0.5

            done_msg
            ask_reboot
            ;;
        13)
            find_ssh_port
            ufw_optimizations
            sleep 0.5

            done_msg
            ;;
        14)
            find_ssh_port
            install_fail2ban
            sleep 0.5

            done_msg
            ;;
        15)
            install_nginx
            sleep 0.5

            done_msg
            ;;
        s|S)
            show_status
            ;;
        q|Q)
            exit 0
            ;;

        *)
            red_msg 'Wrong input!'
            ;;
        esac
    done
}


# Apply Everything
apply_everything() {

    complete_update
    sleep 0.5

    install_xanmod
    sleep 0.5

    installations
    enable_packages
    sleep 0.5

    swap_maker
    sleep 0.5

    sysctl_optimizations
    sleep 0.5

    update_sshd_conf
    sleep 0.5

    limits_optimizations
    sleep 0.5

    find_ssh_port
    ufw_optimizations
    sleep 0.5
}


main
