#!/bin/bash
# https://github.com/hawshemi/Linux-Optimizer


# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}


# Declare Paths & Settings.
SYS_PATH="/etc/sysctl.conf"
PROF_PATH="/etc/profile"
SSH_PORT=""
SSH_PATH="/etc/ssh/sshd_config"
SWAP_PATH="/swapfile"
SWAP_SIZE=2G
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
ARVAN_DOCKER_MIRROR="https://docker.arvancloud.ir"


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


# Ask Reboot
ask_reboot() {
    yellow_msg 'Reboot now? (RECOMMENDED) (y/n)'
    echo 
    while true; do
        read choice
        echo 
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            sleep 0.5
            reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}


# Update & Upgrade & Remove & Clean
complete_update() {
    echo 
    yellow_msg 'Updating the System... (This can take a while.)'
    echo 
    sleep 0.5

    sudo dnf -y up
    sudo dnf -y autoremove
    sudo dnf -y clean all
    sleep 0.5
    
    ## Again :D
    sudo dnf -y up
    sudo dnf -y autoremove
    
    echo 
    green_msg 'System Updated & Cleaned Successfully.'
    echo 
    sleep 0.5
}


# Install useful packages
installations() {
    echo 
    yellow_msg 'Installing Useful Packages... (This can take a while.)'
    echo 
    sleep 0.5

    ## System utilities
    sudo dnf -y install bash-completion busybox crontabs ca-certificates curl dnf-plugins-core dnf-utils gnupg2 nano screen ufw unzip vim wget zip

    ## Programming and development tools
    sudo dnf -y install autoconf automake bash-completion git libtool make pkg-config python3 python3-pip

    ## Additional libraries and dependencies
    sudo dnf -y install bc binutils haveged jq libsodium libsodium-devel PackageKit qrencode socat

    ## Miscellaneous
    sudo dnf -y install dialog htop net-tools

    echo 
    green_msg 'Useful Packages Installed Succesfully.'
    echo 
    sleep 0.5
}


# Enable packages at server boot
enable_packages() {
    sudo systemctl enable crond.service haveged
    echo 
    green_msg 'Packages Enabled Successfully.'
    echo
    sleep 0.5
}


# Swap Maker
swap_maker() {
    echo 
    yellow_msg 'Making SWAP Space...'
    echo 
    sleep 0.5

    ## Make Swap
    sudo fallocate -l $SWAP_SIZE $SWAP_PATH  ## Allocate size
    sudo chmod 600 $SWAP_PATH                ## Set proper permission
    sudo mkswap $SWAP_PATH                   ## Setup swap         
    sudo swapon $SWAP_PATH                   ## Enable swap
    echo "$SWAP_PATH   none    swap    sw    0   0" >> /etc/fstab ## Add to fstab
    echo 
    green_msg 'SWAP Created Successfully.'
    echo
    sleep 0.5
}


# SYSCTL Optimization
sysctl_optimizations() {
    ## Make a backup of the original sysctl.conf file
    cp $SYS_PATH /etc/sysctl.conf.bak

    echo 
    yellow_msg 'Default sysctl.conf file Saved. Directory: /etc/sysctl.conf.bak'
    echo 
    sleep 1

    echo 
    yellow_msg 'Optimizing the Network...'
    echo 
    sleep 0.5

    sed -i -e '/fs.file-max/d' \
        -e '/net.core.default_qdisc/d' \
        -e '/net.core.netdev_max_backlog/d' \
        -e '/net.core.optmem_max/d' \
        -e '/net.core.somaxconn/d' \
        -e '/net.core.rmem_max/d' \
        -e '/net.core.wmem_max/d' \
        -e '/net.core.rmem_default/d' \
        -e '/net.core.wmem_default/d' \
        -e '/net.ipv4.tcp_rmem/d' \
        -e '/net.ipv4.tcp_wmem/d' \
        -e '/net.ipv4.tcp_congestion_control/d' \
        -e '/net.ipv4.tcp_fastopen/d' \
        -e '/net.ipv4.tcp_fin_timeout/d' \
        -e '/net.ipv4.tcp_keepalive_time/d' \
        -e '/net.ipv4.tcp_keepalive_probes/d' \
        -e '/net.ipv4.tcp_keepalive_intvl/d' \
        -e '/net.ipv4.tcp_max_orphans/d' \
        -e '/net.ipv4.tcp_max_syn_backlog/d' \
        -e '/net.ipv4.tcp_max_tw_buckets/d' \
        -e '/net.ipv4.tcp_mem/d' \
        -e '/net.ipv4.tcp_mtu_probing/d' \
        -e '/net.ipv4.tcp_notsent_lowat/d' \
        -e '/net.ipv4.tcp_retries2/d' \
        -e '/net.ipv4.tcp_sack/d' \
        -e '/net.ipv4.tcp_dsack/d' \
        -e '/net.ipv4.tcp_slow_start_after_idle/d' \
        -e '/net.ipv4.tcp_window_scaling/d' \
        -e '/net.ipv4.tcp_adv_win_scale/d' \
        -e '/net.ipv4.tcp_ecn/d' \
        -e '/net.ipv4.tcp_ecn_fallback/d' \
        -e '/net.ipv4.tcp_syncookies/d' \
        -e '/net.ipv4.udp_mem/d' \
        -e '/net.ipv6.conf.all.disable_ipv6/d' \
        -e '/net.ipv6.conf.default.disable_ipv6/d' \
        -e '/net.ipv6.conf.lo.disable_ipv6/d' \
        -e '/net.unix.max_dgram_qlen/d' \
        -e '/vm.min_free_kbytes/d' \
        -e '/vm.swappiness/d' \
        -e '/vm.vfs_cache_pressure/d' \
        -e '/net.ipv4.conf.default.rp_filter/d' \
        -e '/net.ipv4.conf.all.rp_filter/d' \
        -e '/net.ipv4.conf.all.accept_source_route/d' \
        -e '/net.ipv4.conf.default.accept_source_route/d' \
        -e '/net.ipv4.neigh.default.gc_thresh1/d' \
        -e '/net.ipv4.neigh.default.gc_thresh2/d' \
        -e '/net.ipv4.neigh.default.gc_thresh3/d' \
        -e '/net.ipv4.neigh.default.gc_stale_time/d' \
        -e '/net.ipv4.conf.default.arp_announce/d' \
        -e '/net.ipv4.conf.lo.arp_announce/d' \
        -e '/net.ipv4.conf.all.arp_announce/d' \
        -e '/kernel.panic/d' \
        -e '/vm.dirty_ratio/d' \
        -e '/vm.overcommit_memory/d' \
        -e '/vm.overcommit_ratio/d' \
        -e '/^#/d' \
        -e '/^$/d' \
        "$SYS_PATH"


    ## Add new parameters. Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf

cat <<EOF >> "$SYS_PATH"


################################################################
################################################################


# /etc/sysctl.conf
# These parameters in this file will be added/updated to the sysctl.conf file.
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


## IPv6 settings
## ----------------------------------------------------------------

# Enable IPv6
#net.ipv6.conf.all.disable_ipv6 = 0

# Enable IPv6 by default
#net.ipv6.conf.default.disable_ipv6 = 0

# Enable IPv6 on the loopback interface (lo)
#net.ipv6.conf.lo.disable_ipv6 = 0


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

# Strictly limits memory allocation to physical RAM + swap, preventing overcommit and reducing OOM risks.
vm.overcommit_memory = 2

# Sets overcommit to 100% of RAM when enabled, but ignored here since overcommit_memory = 2 disables it.
vm.overcommit_ratio = 100


################################################################
################################################################


EOF

    sudo sysctl -p
    
    echo 
    green_msg 'Network is Optimized.'
    echo 
    sleep 0.5
}


# Function to find the SSH port and set it in the SSH_PORT variable
find_ssh_port() {
    echo 
    yellow_msg "Finding SSH port..."
    echo 

    ## Check if the SSH configuration file exists
    if [ -e "$SSH_PATH" ]; then
        ## Use grep to search for the 'Port' directive in the SSH configuration file
        SSH_PORT=$(grep -oP '^Port\s+\K\d+' "$SSH_PATH" 2>/dev/null)

        if [ -n "$SSH_PORT" ]; then
            echo 
            green_msg "SSH port found: $SSH_PORT"
            echo 
            sleep 0.5
        else
            echo 
            green_msg "SSH port is default 22."
            echo 
            SSH_PORT=22
            sleep 0.5
        fi
    else
        red_msg "SSH configuration file not found at $SSH_PATH"
    fi
}


# Remove old SSH config to prevent duplicates.
remove_old_ssh_conf() {
    ## Make a backup of the original sshd_config file
    cp $SSH_PATH /etc/ssh/sshd_config.bak

    echo 
    yellow_msg 'Default SSH Config file Saved. Directory: /etc/ssh/sshd_config.bak'
    echo 
    sleep 1

    ## Remove these lines
    sed -i -e 's/#UseDNS yes/UseDNS no/' \
        -e 's/#Compression no/Compression yes/' \
        -e 's/Ciphers .*/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/' \
        -e '/MaxAuthTries/d' \
        -e '/MaxSessions/d' \
        -e '/TCPKeepAlive/d' \
        -e '/ClientAliveInterval/d' \
        -e '/ClientAliveCountMax/d' \
        -e '/AllowAgentForwarding/d' \
        -e '/AllowTcpForwarding/d' \
        -e '/GatewayPorts/d' \
        -e '/PermitTunnel/d' \
        -e '/X11Forwarding/d' "$SSH_PATH"

}


# Update SSH config
update_sshd_conf() {
    echo 
    yellow_msg 'Optimizing SSH...'
    echo 
    sleep 0.5

    ## Enable TCP keep-alive messages
    echo "TCPKeepAlive yes" | tee -a "$SSH_PATH"

    ## Configure client keep-alive messages
    echo "ClientAliveInterval 3000" | tee -a "$SSH_PATH"
    echo "ClientAliveCountMax 100" | tee -a "$SSH_PATH"

    ## Allow TCP forwarding
    echo "AllowTcpForwarding yes" | tee -a "$SSH_PATH"

    ## Enable gateway ports
    echo "GatewayPorts yes" | tee -a "$SSH_PATH"

    ## Enable tunneling
    echo "PermitTunnel yes" | tee -a "$SSH_PATH"

    ## Enable X11 graphical interface forwarding
    echo "X11Forwarding yes" | tee -a "$SSH_PATH"

    ## Restart the SSH service to apply the changes
    sudo systemctl restart sshd

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
    sed -i '/ulimit -c/d' $PROF_PATH
    sed -i '/ulimit -d/d' $PROF_PATH
    sed -i '/ulimit -f/d' $PROF_PATH
    sed -i '/ulimit -i/d' $PROF_PATH
    sed -i '/ulimit -l/d' $PROF_PATH
    sed -i '/ulimit -m/d' $PROF_PATH
    sed -i '/ulimit -n/d' $PROF_PATH
    sed -i '/ulimit -q/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH
    sed -i '/ulimit -t/d' $PROF_PATH
    sed -i '/ulimit -u/d' $PROF_PATH
    sed -i '/ulimit -v/d' $PROF_PATH
    sed -i '/ulimit -x/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH


    ## Add new ulimits
    ## The maximum size of core files created.
    echo "ulimit -c unlimited" | tee -a $PROF_PATH

    ## The maximum size of a process's data segment
    echo "ulimit -d unlimited" | tee -a $PROF_PATH

    ## The maximum size of files created by the shell (default option)
    echo "ulimit -f unlimited" | tee -a $PROF_PATH

    ## The maximum number of pending signals
    echo "ulimit -i unlimited" | tee -a $PROF_PATH

    ## The maximum size that may be locked into memory
    echo "ulimit -l unlimited" | tee -a $PROF_PATH

    ## The maximum memory size
    echo "ulimit -m unlimited" | tee -a $PROF_PATH

    ## The maximum number of open file descriptors
    echo "ulimit -n 1048576" | tee -a $PROF_PATH

    ## The maximum POSIX message queue size
    echo "ulimit -q unlimited" | tee -a $PROF_PATH

    ## The maximum stack size
    echo "ulimit -s -H 65536" | tee -a $PROF_PATH
    echo "ulimit -s 32768" | tee -a $PROF_PATH

    ## The maximum number of seconds to be used by each process.
    echo "ulimit -t unlimited" | tee -a $PROF_PATH

    ## The maximum number of processes available to a single user
    echo "ulimit -u unlimited" | tee -a $PROF_PATH

    ## The maximum amount of virtual memory available to the process
    echo "ulimit -v unlimited" | tee -a $PROF_PATH

    ## The maximum number of file locks
    echo "ulimit -x unlimited" | tee -a $PROF_PATH


    echo 
    green_msg 'System Limits are Optimized.'
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
    sudo dnf -y remove firewalld

    ## Install UFW if not installed.
    dnf -y up
    dnf -y install ufw
    
    ## Disable UFW
    sudo ufw disable

    ## Open default ports.
    sudo ufw allow $SSH_PORT
    sudo ufw allow 80/tcp
    sudo ufw allow 80/udp
    sudo ufw allow 443/tcp
    sudo ufw allow 443/udp
    sleep 0.5

    ## Change the UFW config to use System config.
    sed -i 's+/etc/ufw/sysctl.conf+/etc/sysctl.conf+gI' /etc/default/ufw

    ## Enable & Reload
    echo "y" | sudo ufw enable
    sudo ufw reload
    echo 
    green_msg 'UFW is Installed & Optimized. (Open your custom ports manually.)'
    echo 
    sleep 0.5
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


## Keep the very first backup, so running the script again doesn't overwrite the original file.
backup_once() {
    if [ -e "$1" ] && [ ! -e "$1.bak" ]; then
        cp -pL "$1" "$1.bak"
        yellow_msg "Default $1 saved. Directory: $1.bak"
    fi
}


# Install Docker Engine + Compose
# https://docs.docker.com/engine/install/
install_docker() {
    echo
    yellow_msg 'Installing Docker...'
    echo
    sleep 0.5

    if command -v docker >/dev/null 2>&1; then
        green_msg "Docker is already installed: $(docker --version 2>/dev/null)"
        systemctl enable --now docker >/dev/null 2>&1
        echo
        return 0
    fi

    . /etc/os-release
    local distro base="" candidate tmp_key="/tmp/docker_signing.key" tmp_repo="/tmp/docker-ce.repo" gnupg_tmp
    case "$ID" in
        fedora) distro="fedora" ;;
        rhel)   distro="rhel" ;;
        *)      distro="centos" ;;
    esac

    ## download.docker.com refuses Iranian servers (HTTP 403), so the ArvanCloud copy is tried next.
    ## Either way the signing key must be Docker's official one.
    for candidate in "https://download.docker.com/linux/$distro" "https://mirror.arvancloud.ir/docker-ce/linux/$distro"; do
        curl -fsS --max-time 20 -o "$tmp_repo" "$candidate/docker-ce.repo" && grep -q '^\[docker-ce-stable\]' "$tmp_repo" || continue
        curl -fsSL --max-time 30 -o "$tmp_key" "$candidate/gpg" && [ -s "$tmp_key" ] || continue
        gnupg_tmp=$(mktemp -d)
        if GNUPGHOME="$gnupg_tmp" gpg --dry-run --quiet --no-keyring --import --import-options import-show \
                "$tmp_key" 2>/dev/null | grep -q '060A61C51B558A7F742B77AAC52FEB6B621E9F35'; then
            base="$candidate"
            rm -rf "$gnupg_tmp"
            break
        fi
        red_msg "The Docker signing key from $candidate does not match the official fingerprint."
        rm -rf "$gnupg_tmp"
    done

    if [ -z "$base" ]; then
        red_msg "Docker's repository is not reachable from this server (download.docker.com blocks Iranian servers). Skipping."
        echo
        rm -f "$tmp_key" "$tmp_repo"
        return 1
    fi

    rpm --import "$tmp_key"
    sed "s|https://download.docker.com/linux/$distro|$base|g" "$tmp_repo" > /etc/yum.repos.d/docker-ce.repo
    rm -f "$tmp_key" "$tmp_repo"

    if ! dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        red_msg 'Installing Docker failed. If podman or buildah is installed, it may conflict: dnf remove podman buildah'
        echo
        return 1
    fi

    systemctl enable --now containerd docker >/dev/null 2>&1
    if ! docker info >/dev/null 2>&1; then
        red_msg 'Docker is installed, but did not start. Check: journalctl -u docker'
        echo
        return 1
    fi

    echo
    green_msg "$(docker --version) Installed from $base"
    docker compose version >/dev/null 2>&1 && green_msg "$(docker compose version)"
    yellow_msg 'Note: ports published with "docker run -p" bypass UFW. Use -p 127.0.0.1:PORT:PORT for ports only a local proxy should reach.'
    echo

    ## Docker Hub blocks Iranian servers too. Its own repository being blocked is a good hint.
    if [ "$base" != "https://download.docker.com/linux/$distro" ] && ! grep -qsF "$ARVAN_DOCKER_MIRROR" "$DOCKER_DAEMON_JSON" \
            && ask_yes_no 'Docker Hub blocks Iranian servers too. Pull images through the ArvanCloud mirror?'; then
        docker_mirror_arvan
    fi
    sleep 0.5
}


# Pull Docker Hub images through the ArvanCloud mirror (Docker Hub refuses Iranian servers).
# Running it again removes the mirror. With "on", it's only turned on, never removed.
docker_mirror_arvan() {
    local mode="$1"
    echo
    yellow_msg 'Configuring the ArvanCloud mirror for Docker Hub...'
    echo
    sleep 0.5

    command -v jq >/dev/null 2>&1 || dnf -y install jq
    if [ -s "$DOCKER_DAEMON_JSON" ] && ! jq empty "$DOCKER_DAEMON_JSON" >/dev/null 2>&1; then
        red_msg "$DOCKER_DAEMON_JSON is not valid JSON. Fix it first. Skipping."
        echo
        return 1
    fi

    local tmp code done_text
    tmp=$(mktemp)
    if [ -s "$DOCKER_DAEMON_JSON" ] && jq -e --arg m "$ARVAN_DOCKER_MIRROR" \
            '(.["registry-mirrors"] // []) | index($m) != null' "$DOCKER_DAEMON_JSON" >/dev/null; then
        green_msg 'Docker already pulls images through the ArvanCloud mirror.'
        echo
        if [ "$mode" = "on" ] || ! ask_yes_no 'Remove it and pull from Docker Hub directly?'; then
            rm -f "$tmp"
            return 0
        fi
        jq --arg m "$ARVAN_DOCKER_MIRROR" \
            '.["registry-mirrors"] -= [$m] | if .["registry-mirrors"] == [] then del(.["registry-mirrors"]) else . end' \
            "$DOCKER_DAEMON_JSON" > "$tmp"
        done_text='ArvanCloud mirror removed. Images come from Docker Hub again.'
    else
        ## A registry answers /v2/ with 200, or 401 when it wants a token.
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$ARVAN_DOCKER_MIRROR/v2/")
        if [ "$code" != 200 ] && [ "$code" != 401 ]; then
            red_msg "$ARVAN_DOCKER_MIRROR is not reachable (HTTP $code). Skipping."
            echo
            rm -f "$tmp"
            return 1
        fi
        mkdir -p /etc/docker
        backup_once "$DOCKER_DAEMON_JSON"
        ## Keep the other settings and mirrors, put ArvanCloud first.
        { [ -s "$DOCKER_DAEMON_JSON" ] && cat "$DOCKER_DAEMON_JSON" || echo '{}'; } \
            | jq --arg m "$ARVAN_DOCKER_MIRROR" '.["registry-mirrors"] = ([$m] + ((.["registry-mirrors"] // []) - [$m]))' > "$tmp"
        done_text="Docker Hub images are now pulled through $ARVAN_DOCKER_MIRROR"
    fi

    if command -v dockerd >/dev/null 2>&1 && dockerd --help 2>&1 | grep -q -- '--validate' \
            && ! dockerd --validate --config-file "$tmp" >/dev/null 2>&1; then
        red_msg "The new $DOCKER_DAEMON_JSON is rejected by Docker. No changes made."
        echo
        rm -f "$tmp"
        return 1
    fi
    cat "$tmp" > "$DOCKER_DAEMON_JSON"
    chmod 644 "$DOCKER_DAEMON_JSON"
    rm -f "$tmp"

    ## registry-mirrors can be reloaded live, so running containers are not restarted.
    if systemctl is-active --quiet docker; then
        systemctl reload docker
        sleep 1
        yellow_msg "Docker mirrors: $(docker info --format '{{range .RegistryConfig.Mirrors}}{{.}} {{end}}' 2>/dev/null)"
    else
        yellow_msg 'Docker is not running. The setting is used when it starts.'
    fi

    echo
    green_msg "$done_text"
    echo
    sleep 0.5
}


# All in one: Docker Hub mirror, then Docker (so Docker starts with the mirror and doesn't ask again).
docker_arvan_all() {
    docker_mirror_arvan on
    sleep 0.5

    install_docker
}


# Show the Menu
show_menu() {
    echo 
    yellow_msg 'Choose One Option: '
    echo 
    yellow_msg 'Presets:'
    green_msg '1  - Apply Everything. (RECOMMENDED)'
    green_msg '2  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits + UFW'
    green_msg '3  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits'
    green_msg '4  - Optimize the Network, SSH & System Limits only. (No updates or installs)'
    echo 
    yellow_msg 'System:'
    green_msg '5  - Complete Update & Clean the OS.'
    green_msg '6  - Install Useful Packages.'
    green_msg '7  - Make SWAP (2Gb).'
    green_msg '8  - Optimize the System Limits.'
    echo 
    yellow_msg 'Network:'
    green_msg '9  - Optimize the Network settings. (sysctl, BBR)'
    green_msg '10 - Install & Optimize UFW.'
    echo 
    yellow_msg 'SSH:'
    green_msg '11 - Optimize the SSH settings.'
    echo 
    yellow_msg 'Docker:'
    green_msg '12 - Install Docker with the ArvanCloud Docker Hub mirror. (13 + 14)'
    green_msg '13 - Install Docker + Docker Compose.'
    green_msg '14 - Use the ArvanCloud mirror for Docker Hub images. (Run again to remove)'
    echo 
    red_msg 'q  - Exit.'
    echo 
}


# Choosing Program
main() {
    while true; do
        show_menu
        read -p 'Enter Your Choice: ' choice
        case $choice in
        1)
            apply_everything

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        2)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5
    
            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            find_ssh_port
            ufw_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        3)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5
    
            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        4)
            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5
    
            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        5)
            complete_update
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
            
        6)
            complete_update
            installations
            enable_packages
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        7)
            swap_maker
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        8)
            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        9)
            sysctl_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        10)
            find_ssh_port
            ufw_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        11)
            remove_old_ssh_conf
            sleep 0.5
    
            update_sshd_conf
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        12)
            docker_arvan_all
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        13)
            install_docker
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        14)
            docker_mirror_arvan
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        q)
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

    installations
    sleep 0.5

    enable_packages
    sleep 0.5

    swap_maker
    sleep 0.5

    sysctl_optimizations
    sleep 0.5

    remove_old_ssh_conf
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
