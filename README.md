# Linux Optimizer

## This Bash script automates the optimization of your Linux server.
#### Notes:
 1. This script is designed for execution on Linux server environments, including VPS, VDS, Dedicated, and Bare Metal systems. It is not recommended for use on Linux desktop environments.
 2. Modifying the kernel (options 1 and 11) may result in removing or resetting some GPU drivers.
 3. Some VMs do not support kernel changes (options 1 and 11). Installing XanMod could cause the VM to break. Please be cautious and test beforehand.

### It performs the following tasks:
       
0. Fix `hosts` file and DNS _(temporarily)_:
    - Check and add 127.0.1.1 and server hostname to `/etc/hosts`.
    
    *Original `hosts` file is backed up at `/etc/hosts.bak`.*
    - Only if DNS is **not** working: add `Cloudflare-Security` DNS servers _`(1.1.1.2, 1.0.0.2)`_ to `/etc/resolv.conf`, keeping the old nameservers as fallback. A working DNS is left untouched.
    
    *Original `dns` file is backed up at `/etc/resolv.conf.bak`.*

    *Backups are only made on the first run, so running the script again never overwrites your original files.*


1. Update, Upgrade, and Clean the server:
    - _Update_
    - _Upgrade_
    - _Full-Upgrade_
    - _AutoRemove_
    - _AutoClean_
    - _Clean_
    - _Limit the systemd journal to 200MB (100MB with menu option 3)_


2. Disable Terminal Ads _(Only on Ubuntu)_.


3. Install XanMod Kernel _(Only on Ubuntu 24.04+ & Debian 12+, x86-64)_:
    - Enable BBRv3.
    - CloudFlare TCP Optimizations.
    - Skipped automatically on containers (LXC/OpenVZ), Secure Boot, and releases XanMod doesn't support.
    - More Details: https://xanmod.org

4. Install Useful Packages:

    _`apt-transport-https`_ _`apt-utils`_ _`autoconf`_ _`automake`_ _`bash-completion`_ _`bc`_ _`bind9-dnsutils`_ _`binutils`_ _`binutils-common`_ _`binutils-x86-64-linux-gnu`_ _`btop`_ _`build-essential`_ _`busybox`_ _`ca-certificates`_ _`certbot`_ _`cron`_ _`curl`_ _`dialog`_ _`epel-release`_ _`gnupg2`_ _`git`_ _`haveged`_ _`htop`_ _`iperf3`_ _`jq`_ _`keyring`_ _`libsodium-dev`_ _`libssl-dev`_ _`libsqlite3-dev`_ _`libtool`_ _`locales`_ _`lsb-release`_ _`make`_ _`mtr-tiny`_ _`nano`_ _`ncdu`_ _`net-tools`_ _`nload`_ _`pkg-config`_ _`preload`_ _`python3`_ _`python3-pip`_ _`qrencode`_ _`socat`_ _`screen`_ _`software-properties-common`_ _`ufw`_ _`unzip`_ _`vim`_ _`vnstat`_ _`wget`_ _`wireguard-tools`_ _`xxd`_ _`zip`_

    *Packages that don't exist on your release (e.g. `software-properties-common` on Debian 13) are skipped instead of breaking the install.*


5. Enable Packages at Server Boot.


6. Create & Enable `SWAP` File:
    - Swap Path: `"/swapfile"`
    - Swap Size: `2Gb`
    - **Skipped if the server already has SWAP** (e.g. created by your VPS provider).


7. Optimize the [SYSCTL](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf) Configs:
    - Optimize File System Settings.
    - Optimize Network Core Settings.
    - Optimize `SWAP`.
    - Optimize `TCP` and `UDP` Settings.
    - Optimize `UNIX` Domain Sockets Settings.
    - Optimize `Virtual memory (VM)` Settings.
    - Optimize Network Configuration Settings.
    - Optimize the Kernel.
    - Activate `BBR` _(`BBRv3` with XanMod)_.

    *Settings are written to `/etc/sysctl.d/99-linux-optimizer.conf` (Debian 13 and Ubuntu 26.04 no longer have `/etc/sysctl.conf`). If `/etc/sysctl.conf` exists, it is backed up at `/etc/sysctl.conf.bak`.*

    
8. Optimize [SSH](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sshd_config):
    - Disable DNS lookups for connecting clients.
    - Remove less efficient encryption ciphers.
    - Enable and Configure TCP keep-alive messages.
    - Allow TCP forwarding.
    - Enable gateway ports, Tunneling and compression.
    - Enable X11 Forwarding.

    *Settings are written to `/etc/ssh/sshd_config.d/01-linux-optimizer.conf`. The config is checked with `sshd -t` before restarting SSH, and rolled back if invalid. Original file is backed up at `/etc/ssh/sshd_config.bak`.*
   

9. Optimize the [System Limits](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/profile):
    - Soft and Hard *ulimit* `-c -d -f -i -l -n -q -s -u -v -x` optimizations.
    - Open files limit (`1048576`) for systemd services too (xray, nginx, ...), not only login shells.
    
    
10. Optimize `UFW` and open Common Ports:
    - Open Ports `SSH` (all ports sshd really listens on), `80`, `443`.
    - With `IPv6`, `TCP` & `UDP`.


11. Install `Fail2ban` for SSH brute-force protection _(Ubuntu & Debian)_:
    - 5 failed logins in 10 minutes = 1 hour ban.
    - Reads logins from the systemd journal, so it works on Debian 12/13 without `/var/log/auth.log`.


12. Install `Nginx` from the official [nginx.org repository](https://nginx.org/en/linux_packages.html) _(Ubuntu 22.04+ & Debian 11+)_:
    - Choose `mainline` (newest features, default) or `stable`.
    - Newer than the distro's nginx, and updated by `apt upgrade` from nginx.org.
    - The signing key is checked against the official fingerprint.
    - Already using the distro's nginx? `/etc/nginx` is backed up, and your `sites-enabled` sites and nginx user (`www-data`) are kept.
    - Installs the `certbot` nginx plugin, so you can get SSL with `certbot --nginx`.


13. Remove `Snapd` and all snap packages _(Only on Ubuntu)_:
    - Snaps are removed first, then `snapd`, leftovers in `/snap`, `/var/snap`, `/var/lib/snapd`, `~/snap`.
    - `snapd` is pinned so it is never installed again.


14. Remove unneeded packages _(Only on Ubuntu)_:
    - `apport`, `whoopsie`, `popularity-contest`, `landscape-common`, `lxd-installer`, `modemmanager`, `pollinate`.


15. Install `Docker` with the ArvanCloud mirrors, all in one (first option of the Docker group):
    - Ubuntu & Debian: change APT to the ArvanCloud mirror, use the ArvanCloud Docker Hub mirror, then install Docker.
    - CentOS, AlmaLinux & Fedora: use the ArvanCloud Docker Hub mirror, then install Docker.
    - The mirrors are set before Docker is installed, so Docker starts with them. Running it again never removes a mirror.


16. Install `Docker` + `Docker Compose`:
    - From Docker's official repository (`docker-ce`, `buildx` & `compose` plugins). The signing key is checked against the official fingerprint.
    - `download.docker.com` blocks Iranian servers, so the ArvanCloud copy is tried next. If neither works, the distro's `docker.io` package can be installed instead _(Ubuntu & Debian)_.
    - Ports published with `docker run -p` bypass `UFW`. Use `-p 127.0.0.1:PORT:PORT` for ports that should stay private.


17. Use the [ArvanCloud](https://www.arvancloud.ir) mirror for Docker Hub images (`https://docker.arvancloud.ir`):
    - Docker Hub blocks Iranian servers. With the mirror, `docker pull nginx` works as usual.
    - Added to `registry-mirrors` in `/etc/docker/daemon.json`. Your other settings are kept. Original file is backed up at `/etc/docker/daemon.json.bak`.
    - Docker is reloaded, not restarted, so running containers keep running.
    - **Run the option again to remove the mirror.**


18. Change the APT repositories to the [ArvanCloud mirror](https://www.arvancloud.ir/en/dev/linux-repository) _(Ubuntu & Debian)_:
    - Faster inside Iran, and works when the official mirrors are filtered.
    - Written to `/etc/apt/sources.list.d/ubuntu.sources` (or `debian.sources`), including security updates. Other repositories (Nginx, Docker, XanMod) are not touched.
    - Original sources are backed up at `/etc/apt/linux-optimizer-sources-backup`. If `apt update` fails on the mirror, they are restored automatically.
    - Ubuntu: `amd64` only (ArvanCloud has no `ubuntu-ports` for ARM).
    - **Run the option again to restore the original repositories.**


19. Show Server Status (`s` in the menu): OS, kernel, virtualization, RAM, SWAP, BBR, limits, UFW, Fail2ban, Nginx, Docker, mirrors.

    
**Reboot at the end is recommended.**


## Prerequisites

### Ensure that the `sudo` and `wget` packages are installed on your system:

- Ubuntu & Debian:
```
sudo apt update -q && sudo apt install -y sudo wget
```
- CentOS & Fedora:
```
sudo dnf up -y && sudo dnf install -y sudo wget
```


## Run
#### **Tested on:** Ubuntu 20.04 - 26.04, Debian 11 - 13, CentOS Stream 8+, AlmaLinux 8+, Fedora 37+

#### Root Access is Required. If the user is not root, first run:
```
sudo -i
```
#### Then:
```
wget -4 "https://raw.githubusercontent.com/amirmohamadamini/linux-optimizer/refs/heads/main/linux-optimizer.sh" -O linux-optimizer.sh && chmod +x linux-optimizer.sh && bash linux-optimizer.sh 
```



## Menu
### Ubuntu & Debian _(Debian has no `Cleanup` section)_:
```
Presets:
1  - Apply Everything + XanMod Kernel. (RECOMMENDED)
2  - Optimize the Network, SSH & System Limits only. (No updates or installs)
3  - Complete Update + Useful Packages + Make SWAP + Optimize Network, SSH & System Limits + UFW + Journal 100MB
4  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits + UFW
5  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits

System:
6  - Complete Update & Clean the OS.
7  - Change the APT repositories to the ArvanCloud mirror. (Run again to restore)
8  - Install Useful Packages.
9  - Make SWAP (2Gb). (Skipped if SWAP already exists)
10 - Optimize the System Limits.
11 - Install XanMod Kernel.

Network:
12 - Optimize the Network settings. (sysctl, BBR)
13 - Install & Optimize UFW.

SSH:
14 - Optimize SSH + Install Fail2ban. (15 + 16)
15 - Optimize the SSH settings.
16 - Install Fail2ban (SSH brute-force protection).

Nginx:
17 - Install Nginx from the official nginx.org repository.

Docker:
18 - Install Docker with the ArvanCloud APT & Docker Hub mirrors. (7 + 19 + 20)
19 - Install Docker + Docker Compose.
20 - Use the ArvanCloud mirror for Docker Hub images. (Run again to remove)

Cleanup:
21 - Remove Snapd + ALL snap packages.
22 - Remove Unneeded Packages (apport, landscape, lxd-installer, modemmanager, ...).

s  - Show Server Status.
q  - Exit.
```

### CentOS, AlmaLinux & Fedora:
```
Presets:
1  - Apply Everything. (RECOMMENDED)
2  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits + UFW
3  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits
4  - Optimize the Network, SSH & System Limits only. (No updates or installs)

System:
5  - Complete Update & Clean the OS.
6  - Install Useful Packages.
7  - Make SWAP (2Gb).
8  - Optimize the System Limits.

Network:
9  - Optimize the Network settings. (sysctl, BBR)
10 - Install & Optimize UFW.

SSH:
11 - Optimize the SSH settings.

Docker:
12 - Install Docker with the ArvanCloud Docker Hub mirror. (13 + 14)
13 - Install Docker + Docker Compose.
14 - Use the ArvanCloud mirror for Docker Hub images. (Run again to remove)

q  - Exit.
```


## Disclaimer
This script is provided as-is, without any warranty or guarantee. Use it at your own risk.


## License
This script is licensed under the MIT License.

