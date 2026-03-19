# 🚀 n8n Pro Installer for Ubuntu (SSH-Aware)

A production-ready, 1-click installer to deploy a secure **n8n** automation stack on a local Ubuntu laptop or server. This setup uses **Cloudflare Tunnels** to expose your local instance to the internet securely without port forwarding, includes **PostgreSQL** for database stability, and **Uptime Kuma** for real-time monitoring.

---

## 🌟 Key Features
* **Zero Trust Security:** Uses Cloudflare Tunnels (no open ports on your router).
* **Production Architecture:** Powered by Docker Compose with a dedicated PostgreSQL 16 database.
* **SSH-Aware:** Intelligent script logic detects if you are installing via SSH and provides clickable links and local IP discovery.
* **Health Checks:** Integrated `curl` polling with visual progress bars to ensure services are live before finishing.
* **Uptime Monitoring:** Pre-configured Uptime Kuma instance to track your automation's heartbeat.

---

## 🛠️ Prerequisites
1.  **Ubuntu Laptop/Server:** (Tested on Ubuntu 22.04/24.04 LTS).
2.  **Cloudflare Account:** A domain managed by Cloudflare.
3.  **Cloudflare Tunnel Token:** * Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
    * Networks -> Tunnels -> Create a Tunnel.
    * Choose **Docker** and copy the token string.

---

## 🚀 1-Click Installation
Clone this repository and run the installer:

```bash
git clone https://github.com/mysnoopy/n8n-ubuntu.git
cd n8n-ubuntu
chmod +x install_n8n.sh
./install_n8n.sh
```

---

## 🏗️ The Stack
The installer orchestrates four core containers:

| Container | Image | Purpose |
| :--- | :--- | :--- |
| n8n_app | n8nio/n8n:latest | The core automation engine. |
| n8n_db | postgres:16-alpine | Persistent storage for workflows. |
| uptime_kuma | louislam/uptime-kuma:1 | Monitoring dashboard for the stack. |
| cloudflared | cloudflare/cloudflared | Secure bridge to the internet. |

---

## 📂 Directory Structure
After installation, your project folder will look like this:

```text
.
├── n8n_data/           # n8n configuration and binary files
├── postgres_data/      # PostgreSQL database files
├── uptime_data/        # Uptime Kuma monitoring data
├── .env                # Secrets (DB Pass, Tunnel Token, etc.) - GIT IGNORED
├── docker-compose.yml  # Container orchestration - GIT IGNORED
└── install_n8n.sh      # The master installer script
```

---

## 🔐 Security & Access
* **Public Access:** Access n8n via your custom subdomain (e.g., `https://n8n.yourdomain.com`).
* **Local Access:** Access the Monitoring Dashboard at `http://localhost:3001` or `http://<LAPTOP_IP>:3001`.
* **SSH Tunneling:** For maximum security, you can access the dashboard through an SSH tunnel:
    `ssh -L 3001:localhost:3001 user@laptop-ip`

---

## ⚖️ License
MIT License

Copyright (c) 2026 Clarence Cheung

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
