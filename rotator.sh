#!/bin/bash

# === CONFIG ===
TOR_DIR="$HOME/.tor"
TORRC_PATH="$TOR_DIR/torrc"
COOKIE_PATH="$TOR_DIR/control.authcookie"
CONTROL_PORT=9051
GITHUB_TORRC_URL="https://raw.githubusercontent.com/jshuntley/ip_rotator/refs/heads/main/torrc"  # <-- Replace this with your actual torrc URL

# === STEP 0: Validate input ===
if [[ -z "$1" || ! "$1" =~ ^[0-9]+$ || "$1" -le 0 ]]; then
  echo "❌ Invalid input."
  echo "Usage: $0 <interval_in_minutes>"
  exit 1
fi

INTERVAL=$(( $1 * 60 ))

# === STEP 1: Check if Tor is installed ===
if ! command -v tor &> /dev/null; then
  echo "Tor not found. Installing..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
      debian | ubuntu | kali | parrot)
        sudo apt update -qq && sudo apt install -y tor >/dev/null
        ;;
      arch | manjaro)
        sudo pacman -Sy --noconfirm tor >/dev/null
        ;;
      fedora)
        sudo dnf install -y tor -q >/dev/null
        ;;
      centos | rhel)
        sudo yum install -y epel-release >/dev/null
        sudo yum install -y tor >/dev/null
        ;;
      opensuse* | suse*)
        sudo zypper install -y tor >/dev/null
        ;;
      *)
        echo "❌ Unsupported Linux distribution: $ID. Please manually install Tor."
        exit 1
        ;;
    esac
  else
    echo "❌ Cannot detect OS. /etc/os-release not found. Please manually install Tor."
    exit 1
  fi

  if ! command -v tor &> /dev/null; then
    echo "❌ Tor installation failed."
    exit 1
  fi
fi

# === STEP 2: Download torrc if not present ===
mkdir -p "$TOR_DIR"

if [ ! -f "$TORRC_PATH" ]; then
  echo "⬇️ Downloading basic torrc from GitHub..."
  curl -fsSL "$GITHUB_TORRC_URL" -o "$TORRC_PATH"

  if [ $? -ne 0 ]; then
    echo "❌ Failed to download torrc from GitHub."
    exit 1
  fi
fi

# === STEP 3: Start Tor (user-owned) if not already running ===
if ! pgrep -x "tor" > /dev/null; then
  echo "Starting Tor with torrc: $TORRC_PATH"
  tor -f "$TORRC_PATH" &> "$TOR_DIR/tor.log" &
  sleep 5
fi

# === STEP 4: Check for control.authcookie ===
if [ ! -f "$COOKIE_PATH" ]; then
  echo "❌ control.authcookie not found at $COOKIE_PATH"
  echo "Tor may have failed to start. Check log: $TOR_DIR/tor.log"
  exit 1
fi

# === STEP 5: Begin rotation loop ===
echo "Rotating Tor IP every $1 minute(s)... (Ctrl+C to stop)"
while true; do
  COOKIE=$(xxd -p "$COOKIE_PATH" | tr -d '\n')

  RESPONSE=$((echo authenticate $COOKIE ; echo signal newnym; echo quit) | nc 127.0.0.1 9051)

  if echo "$RESPONSE" | grep -q "250 OK"; then
    IP=$(torsocks curl -s https://checkip.amazonaws.com)
    printf "✅ IP rotated successfully at $(date)\nNew IP: \033[32m$IP\033[0m\n"
  else
    echo "❌ Failed to rotate IP at $(date)"
    echo "Tor response:"
    echo "$RESPONSE"
  fi

  sleep "$INTERVAL"
done
