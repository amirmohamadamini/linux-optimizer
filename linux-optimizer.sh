#!/bin/bash


clear


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


# Paths
HOST_PATH="/etc/hosts"
DNS_PATH="/etc/resolv.conf"
REPO_RAW="https://raw.githubusercontent.com/amirmohamadamini/linux-optimizer/refs/heads/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Never stop for dpkg config-file questions or the needrestart dialog.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a


# Intro
echo
green_msg '================================================================='
green_msg 'This script will automatically Optimize your Linux Server.'
green_msg 'Tested on: Ubuntu 20.04 - 26.04, Debian 11 - 13, CentOS stream 8+, AlmaLinux 8+, Fedora 37+'
green_msg 'Root access is required.'
green_msg 'Source is @ https://github.com/amirmohamadamini/linux-optimizer'
green_msg '================================================================='
echo


# Check Root Function
check_if_running_as_root() {
    # If you want to run as another user, please modify $EUID to be owned by this user
    if [[ "$EUID" -ne '0' ]]; then
      echo
      red_msg 'Error: You must run this script as root!'
      echo
      sleep 0.5
      exit 1
    fi
}


# Run Check Root
check_if_running_as_root
sleep 0.5


# Install dependencies
install_dependencies_debian_based() {
  echo
  yellow_msg 'Installing Dependencies...'
  echo
  sleep 0.5

  apt-get update -q
  apt-get install -yq wget curl sudo jq

  echo
  green_msg 'Dependencies Installed.'
  echo
  sleep 0.5
}


# Install dependencies
install_dependencies_rhel_based() {
  echo
  yellow_msg 'Installing Dependencies...'
  echo
  sleep 0.5

  # dnf up -y
  dnf install -y wget curl sudo jq

  echo
  green_msg 'Dependencies Installed.'
  echo
  sleep 0.5
}


# Fix Hosts file
fix_etc_hosts(){
  echo
  yellow_msg "Fixing Hosts file."
  sleep 0.5

  ## Keep the very first backup, so running the script again doesn't overwrite the original.
  if [ ! -e /etc/hosts.bak ]; then
    cp $HOST_PATH /etc/hosts.bak
    yellow_msg "Default hosts file saved. Directory: /etc/hosts.bak"
    sleep 0.5
  fi

  ## Look for the hostname as a whole word (a plain grep would also match it inside other names).
  if ! awk -v h="$(hostname)" '!/^[[:space:]]*#/ { for (i = 2; i <= NF; i++) if ($i == h) found = 1 } END { exit !found }' $HOST_PATH; then
    echo "127.0.1.1 $(hostname)" >> $HOST_PATH
    green_msg "Hosts Fixed."
    echo
    sleep 0.5
  else
    green_msg "Hosts OK. No changes made."
    echo
    sleep 0.5
  fi
}


# Fix DNS Temporarily
fix_dns(){
    echo
    yellow_msg "Checking DNS."
    sleep 0.5

    ## Don't touch a working DNS. Public resolvers can be filtered (e.g. in Iran),
    ## and the provider's DNS is often the better choice there.
    if timeout 5 getent hosts raw.githubusercontent.com >/dev/null 2>&1 \
        || timeout 5 getent hosts deb.debian.org >/dev/null 2>&1; then
        green_msg "DNS OK. No changes made."
        echo
        sleep 0.5
        return 0
    fi

    yellow_msg "DNS is not working. Fixing DNS Temporarily."

    if [ ! -e /etc/resolv.conf.bak ]; then
        cp -L $DNS_PATH /etc/resolv.conf.bak
        yellow_msg "Default resolv.conf file saved. Directory: /etc/resolv.conf.bak"
    fi
    sleep 0.5

    ## Cloudflare first, the old nameservers after it as a fallback.
    ## Writing with ">" follows the systemd-resolved symlink (sed -i would replace it with a plain file),
    ## so the change stays temporary.
    local others old_ns
    others=$(grep -v '^[[:space:]]*nameserver' $DNS_PATH)
    old_ns=$(grep '^[[:space:]]*nameserver' $DNS_PATH | grep -vE '1\.1\.1\.2|1\.0\.0\.2')
    {
        [ -n "$others" ] && echo "$others"
        echo "nameserver 1.1.1.2"
        echo "nameserver 1.0.0.2"
        [ -n "$old_ns" ] && echo "$old_ns"
    } > /tmp/resolv.conf.new
    cat /tmp/resolv.conf.new > $DNS_PATH
    rm -f /tmp/resolv.conf.new

    green_msg "DNS Fixed Temporarily."
    echo
    sleep 0.5
}


# OS Detection
OS="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu)                OS="ubuntu" ;;
        debian)                OS="debian" ;;
        centos)                OS="centos" ;;
        almalinux|rocky|rhel)  OS="almalinux" ;;
        fedora)                OS="fedora" ;;
    esac
fi

if [ "$OS" == "unknown" ]; then
    echo
    sleep 0.5
    red_msg "Unknown OS, Create an issue here: https://github.com/amirmohamadamini/linux-optimizer/issues"
    echo
    sleep 2
    exit 1
fi

echo
sleep 0.5
yellow_msg "OS: $PRETTY_NAME"
echo
sleep 0.5

## Warn about releases older than what this script supports.
case "$OS" in
    ubuntu) [ "${VERSION_ID%%.*}" -lt 20 ] 2>/dev/null && red_msg "Ubuntu $VERSION_ID is not supported (20.04+). Continue at your own risk." ;;
    debian) [ "${VERSION_ID:-0}" -lt 11 ] 2>/dev/null && red_msg "Debian $VERSION_ID is not supported (11+). Continue at your own risk." ;;
esac


## Run

# Fix Hosts file
fix_etc_hosts
sleep 0.5

# Fix DNS (before installing anything, so the package manager can resolve)
fix_dns
sleep 0.5

# Install dependencies
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    install_dependencies_debian_based
else
    install_dependencies_rhel_based
fi


# Run Script based on Distros
case $OS in
    ubuntu)    script="ubuntu-optimizer.sh" ;;
    debian)    script="debian-optimizer.sh" ;;
    centos)    script="centos-optimizer.sh" ;;
    almalinux) script="centos-optimizer.sh" ;;
    fedora)    script="fedora-optimizer.sh" ;;
esac

## Running from a cloned repo? Use the local copy (useful where GitHub is filtered or slow).
if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
    bash "$SCRIPT_DIR/scripts/$script"
elif wget -q "$REPO_RAW/scripts/$script" -O "$script" && [ -s "$script" ]; then
    chmod +x "$script" && bash "$script"
else
    red_msg "Could not download $REPO_RAW/scripts/$script"
    exit 1
fi
