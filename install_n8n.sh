#!/bin/bash

clear
echo "===================================================="
echo "🚀 n8n PRO INSTALLER: UBUNTU (SSH-AWARE v2.5)"
echo "===================================================="

# --- HELPER: BROWSER OPENER ---
smart_open() {
    local url=$1
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        echo ""
        echo "🔗 REMOTE SESSION DETECTED:"
        echo "Please open this link in your LOCAL browser:"
        echo "👉 $url"
        echo ""
    else
        xdg-open "$url" 2>/dev/null || echo "👉 Please open: $url"
    fi
}

# --- 0. DEPENDENCY CHECK ---
echo "🔍 Checking system requirements..."

# 1. Check for Curl
if ! command -v curl &> /dev/null; then
    echo "🌐 Curl not found. Installing..."
    sudo apt update && sudo apt install -y curl
fi

# 2. Check for Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    sudo apt update && sudo apt install -y docker.io docker-compose-v2
    sudo usermod -aG docker $USER
    echo "----------------------------------------------------"
    echo "⚠️  ACTION REQUIRED: User added to Docker group."
    echo "Please LOG OUT and LOG BACK IN, then run this script again."
    echo "----------------------------------------------------"
    exit 1
else
    if ! sudo docker info &> /dev/null; then
        echo "⏳ Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    echo "✅ Docker is ready."
fi

# --- 1. WIPE CONFIRMATION & DEEP CLEAN ---
echo ""
echo "⚠️  WARNING: TARGETED WIPE DETECTED"
echo "This will force-delete n8n containers and local data."
echo "----------------------------------------------------"
read -p "❓ Wipe n8n environment and start fresh? (y/n): " confirm
if [[ $confirm != [yY] ]]; then echo "❌ Setup cancelled."; exit 1; fi

echo "🧹 Performing Deep Clean..."
docker rm -f n8n_app n8n_db uptime_kuma cloudflared_tunnel >/dev/null 2>&1
docker compose down -v --remove-orphans >/dev/null 2>&1
rm -rf ./n8n_data ./postgres_data ./uptime_data .env docker-compose.yml
echo "✅ Environment cleared."

# --- 2. PRE-PLANNING ---
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
read -p "🌐 Subdomain (e.g. n8n): " MY_SUBDOMAIN
read -p "🏠 Domain (e.g. example.com): " MY_DOMAIN
FULL_URL="https://${MY_SUBDOMAIN}.${MY_DOMAIN}"

# --- 3. CLOUDFLARE SETUP ---
echo "☁️  STEP 1: CONFIGURE CLOUDFLARE"
smart_open "https://one.dash.cloudflare.com/"

echo "----------------------------------------------------"
echo "1️⃣  Tunnel Name: ${MY_SUBDOMAIN}-ubuntu-tunnel"
echo "2️⃣  Select 'Docker' and copy the token."
echo "3️⃣  Public Hostname: ${MY_SUBDOMAIN}.${MY_DOMAIN} -> http://n8n:5678"
echo "💡 Optional: Add monitor-${MY_SUBDOMAIN}.${MY_DOMAIN} -> http://uptime_kuma:3001"
echo "----------------------------------------------------"

while true; do
    read -p "❓ Have you saved the tunnel in Cloudflare? (y/n): " yn
    [[ $yn == [Yy]* ]] && break
done

echo ""
read -p "📋 Paste the Cloudflare Docker command/token: " FULL_COMMAND
TUNNEL_TOKEN=$(echo "$FULL_COMMAND" | sed -n 's/.*--token \([^ ]*\).*/\1/p')
[[ -z "$TUNNEL_TOKEN" ]] && TUNNEL_TOKEN=$FULL_COMMAND

read -p "🐘 Database Password: " DB_PASSWORD

# --- 4. DATA DIRECTORY SETUP ---
mkdir -p ./n8n_data ./postgres_data ./uptime_data
GEN_KEY=$(openssl rand -hex 16)

# --- 5. DEPLOYMENT ---
cat <<EOF > .env
DOMAIN_NAME=${MY_SUBDOMAIN}.${MY_DOMAIN}
TUNNEL_TOKEN=${TUNNEL_TOKEN}
POSTGRES_PASSWORD=${DB_PASSWORD}
N8N_ENCRYPTION_KEY=${GEN_KEY}
EOF

cat <<EOF > docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    container_name: n8n_db
    restart: always
    environment:
      - POSTGRES_USER=n8n_admin
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=n8n_prod
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n_admin -d n8n_prod"]
      interval: 5s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n_app
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n_prod
      - DB_POSTGRESDB_USER=n8n_admin
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - N8N_HOST=\${DOMAIN_NAME}
      - WEBHOOK_URL=https://\${DOMAIN_NAME}
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
    volumes:
      - ./n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime_kuma
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - ./uptime_data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001"]
      interval: 10s
      timeout: 5s
      retries: 5

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared_tunnel
    restart: always
    command: tunnel --no-autoupdate run --token \${TUNNEL_TOKEN}
    depends_on:
      - n8n
      - uptime-kuma
EOF

echo "🏗️  Starting containers..."
docker compose up -d --remove-orphans

# --- 6. PROGRESS BAR HEALTH CHECK ---
check_service() {
    local label=$1
    local url=$2
    local max_retries=30
    local count=0
    echo -e "\n⏳ Checking $label..."
    while [ $count -lt $max_retries ]; do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$url")
        if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" ]]; then
            echo -e "\n✅ $label is LIVE!"
            return 0
        fi
        count=$((count + 1))
        filled=$(printf "%${count}s" | tr ' ' '#')
        empty=$(printf "%$((max_retries - count))s" | tr ' ' '-')
        echo -ne "\r[${filled}${empty}] Polling... ($HTTP_STATUS)"
        sleep 2
    done
    echo -e "\n❌ $label timeout."
}

check_service "n8n (Public Tunnel)" "$FULL_URL"
check_service "Uptime Kuma (Local)" "http://localhost:3001"

# --- 7. FINAL STATUS ---
echo ""
echo "====================================================================================================="
echo "✅ SUCCESS! EVERYTHING IS LIVE."
echo "-----------------------------------------------------------------------------------------------------"
echo "🌐 n8n App URL:      ${FULL_URL}"
echo "📊 Uptime Kuma:      http://localhost:3001"
echo "💻 LAN Dashboard:    http://${LOCAL_IP}:3001"
echo ""
echo "🛠️  SSH Tunneling Tip (on your Mac):"
echo "   ssh -L 3001:localhost:3001 youruser@${LOCAL_IP}"
echo ""
echo "🛠️  RECOMMENDED MONITORS TO ADD IN UPTIME KUMA:"
echo "1. Create your new account"
echo ""
echo "2. At home screen, click 'Add New Monitor'"
echo "   Add Monitor Type: 'HTTP' -> Friendly Name: 'n8n App' -> URL: ${FULL_URL} -> Save"
echo ""
echo "3. At home screen, click 'Add New Monitor'"
echo "   Add Monitor Type: 'TCP Port' -> Friendly Name: 'n8n DB' -> Hostname: n8n_db -> Port: 5432 -> Save"
echo ""
echo "4. At home screen, click 'Add New Monitor'"
echo "   Add Monitor Type: 'TCP Port' -> Name: 'Tunnel' -> Host: cloudflared_tunnel -> Port: 20241 -> Save"
echo "====================================================================================================="
