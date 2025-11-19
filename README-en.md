# DNSTT Server – Installation and Usage Guide

## 🔎 Overview

The **DNSTT Server** is the component responsible for maintaining tunnels over DNS, forwarding traffic received on UDP port 53/5300 to an internal TCP server (for example, an SSH server at `127.0.0.1:22`).

This repository provides:

- The official `dnstt-server` binary (main server).
- The `dnstt` management script, which:
  - Automatically detects the system architecture.
  - Installs the binary under `/usr/local/bin`.
  - Generates private/public keys.
  - Configures basic firewall rules (iptables/ip6tables).
  - Creates and manages the `systemd` service (`dnstt.service`).

---

## ⚙️ Requirements

- Linux distribution with **systemd** (tested on Ubuntu/Debian).
- **Root** access (`sudo`) to install binaries, create services, and adjust firewall rules.
- Standard tools:
  - `curl` or `wget`
  - `iptables` / `ip6tables`
  - `ip` (to detect default network interface)

---

## 🚀 Automatic Installation (Recommended)

### 1. Install the `dnstt` management script

Download the management script and make it executable (adjust the URL according to your repo layout):

```bash
sudo curl -fsSL https://raw.githubusercontent.com/alexdsgmoura/dnstt/main/dnstt -o /usr/local/bin/dnstt
sudo chmod +x /usr/local/bin/dnstt
````

### 2. Run the automatic server installation

Use the following command, passing your NS domain and TCP upstream target:

```bash
sudo dnstt install ns.yourdomain.com 127.0.0.1:22
```

> Example: if your SSH server is at `127.0.0.1:22`, this will be the default `upstream`.

### What the `dnstt` script does during installation

* Detects the architecture (`amd64`, `arm64`, `386`, `armv7`).
* Downloads the appropriate binary from the releases:

  * `/usr/local/bin/dnstt-server`
* Generates the server private/public keys:

  * `/etc/dnstt/server.key`
  * `/etc/dnstt/server.pub`
* Opens the required firewall ports:

  * UDP 53 and 5300 (IPv4 and IPv6)
  * Redirects UDP 53 → 5300 on the detected default interface (e.g. `eth0`, `ens3`, etc.)
* Creates the `systemd` service unit:

  * `/etc/systemd/system/dnstt.service`
* Starts the service and prints the **public key** at the end of the installation.

---

## 📦 Manual Installation (Step by Step)

If you prefer not to use the automatic script, you can set everything up manually.

### 1. Check the system architecture

```bash
uname -m
```

### 2. Download the binary according to your architecture

```bash
# x86_64
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-amd64

# aarch64 (arm64)
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-arm64

# i686 or i386
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-386

# armv7l
wget -O /usr/local/bin/dnstt-server https://github.com/alexdsgmoura/dnstt/releases/download/1.0.0/dnstt-server-armv7
```

### 3. Make the binary executable

```bash
chmod +x /usr/local/bin/dnstt-server
```

### 4. Generate private and public keys

Create the directory for keys:

```bash
mkdir -p /etc/dnstt
```

Generate the keys:

```bash
/usr/local/bin/dnstt-server -gen-key -privkey-file /etc/dnstt/server.key -pubkey-file /etc/dnstt/server.pub
```

### 5. Obtain the public key (for client configuration)

```bash
cat /etc/dnstt/server.pub
```

Keep this key — it will be used in the DNSTT client configuration.

### 6. Configure the firewall

Open UDP ports (IPv4):

```bash
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
```

Open UDP ports (IPv6):

```bash
ip6tables -I INPUT -p udp --dport 53 -j ACCEPT
ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT
```

Redirect port 53 → 5300 (IPv4):

```bash
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-port 5300
```

Redirect port 53 → 5300 (IPv6):

```bash
ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-port 5300
```

> Adjust `eth0` to the correct interface on your server if necessary.

### 7. Create the systemd service

Create the service unit file:

```bash
nano /etc/systemd/system/dnstt.service
```

Service file contents:

```ini
[Unit]
Description=DNSTT Tunnel Server
After=network.target syslog.target

[Service]
Type=simple
User=root

ExecStart=/usr/local/bin/dnstt-server -udp [::]:5300 -privkey-file /etc/dnstt/server.key ns.yourdomain.com 127.0.0.1:22

Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 8. Reload, enable and start the service

```bash
# Reload systemd units
systemctl daemon-reload

# Enable service on boot
systemctl enable dnstt

# Start the service
systemctl start dnstt

# Check service status
systemctl status dnstt

# Monitor logs
journalctl -u dnstt -f
```

---

## 🛠 Managing the Server with `dnstt`

Once the `dnstt` script is installed under `/usr/local/bin/dnstt`, you can manage the service easily:

```bash
# Install (download binary, generate keys, firewall, systemd)
sudo dnstt install ns.yourdomain.com 127.0.0.1:22

# Start / stop / restart service
sudo dnstt start
sudo dnstt stop
sudo dnstt restart

# Check service status
sudo dnstt status

# Show server public key
sudo dnstt pubkey

# Show logs
sudo dnstt logs

# Watch logs in real time
sudo dnstt logs-watch

# Fully uninstall (binary, keys, service)
sudo dnstt uninstall
```

If you run `dnstt install` when the service/binary already exist, the script will detect that DNSTT appears to be installed and will not proceed, to avoid accidental reconfiguration.

---

## 🌐 Language and Network Interface

### Language

The `dnstt` script automatically detects the language using the system `locale`:

* `pt_PT`, `pt_BR`, etc. → messages in **Portuguese**
* `en_US`, `en_GB`, etc. → messages in **English**

You can force the language with:

```bash
DNSTT_LANG=pt dnstt status
DNSTT_LANG=en dnstt status
```

Or via parameter:

```bash
dnstt --lang pt status
dnstt --lang en status
```

### Network interface

By default, the script detects the default route interface automatically (e.g. `eth0`, `ens3`, etc.) and applies the NAT redirection rules on it.

To override explicitly:

```bash
DNSTT_IFACE=eth0 dnstt install ns.yourdomain.com 127.0.0.1:22
```

---

## 🔁 Updating

### Using the `dnstt` script

The recommended update flow today is:

1. Stop and remove the existing installation:

```bash
sudo dnstt uninstall
```

2. Run the installation again:

```bash
sudo dnstt install ns.yourdomain.com 127.0.0.1:22
```

> This ensures binary, keys (if needed), firewall, and the `systemd` service are all consistent.

### Manually updating only the binary

If you prefer to only update the binary:

```bash
sudo systemctl stop dnstt

# Download the new binary for your architecture to /usr/local/bin/dnstt-server
# (see the manual installation section for the exact URLs)

sudo chmod +x /usr/local/bin/dnstt-server
sudo systemctl start dnstt
```

---

## 🗑 Full Manual Removal

If you don’t want to use `dnstt uninstall`, you can remove everything manually:

```bash
sudo systemctl stop dnstt
sudo systemctl disable dnstt

sudo rm -f /usr/local/bin/dnstt-server
sudo rm -f /usr/local/bin/dnstt

sudo rm -f /etc/systemd/system/dnstt.service
sudo rm -rf /etc/dnstt

sudo systemctl daemon-reload
```

> `iptables` / `ip6tables` rules added during installation are **not** automatically reverted.
> Adjust them manually if needed or reset your firewall policies.

---

## 📂 File Layout

* Server binary:
  `/usr/local/bin/dnstt-server`

* Management script:
  `/usr/local/bin/dnstt`

* Server keys:
  `/etc/dnstt/server.key`
  `/etc/dnstt/server.pub`

* systemd service:
  `/etc/systemd/system/dnstt.service`

---

* Author: **Alex Moura** (@alexdsgmoura)
* GitHub: `https://github.com/alexdsgmoura/dnstt`

---

Built to make installing and managing DNSTT servers simple, standardized, and fully automated.