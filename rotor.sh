#!/bin/bash

# === CONFIG ===
TOR_DIR="$HOME/.tor"
TORRC_PATH="$TOR_DIR/torrc"
DATA_DIR="$TOR_DIR/data"
COOKIE_PATH="$DATA_DIR/control_auth_cookie"
CONTROL_PORT=9051

cleanup() {
  echo -e "\nStopping Tor..."
  pkill -x tor
  exit 0
}
trap cleanup SIGINT SIGTERM

# === STEP 0: Validate input ===
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [interval_in_minutes] [exit_country_codes]"
  echo "Examples:"
  echo "  $0                 # Rotate every 10 minutes"
  echo "  $0 5               # Rotate every 5 minutes"
  echo "  $0 us,ca           # Rotate every 10 minutes, US/CA exit nodes"
  echo "  $0 5 us,ca         # Rotate every 5 minutes, US/CA exit nodes"
  exit 0
fi

# Default values
INTERVAL=600  # 10 minutes default
EXIT_NODES=""

# Check if $1 is a number (interval)
if [[ "$1" =~ ^[0-9]+$ ]]; then
  INTERVAL=$(( $1 * 60 ))
  EXIT_NODES="$2"
elif [[ -n "$1" ]]; then
  # If not a number but non-empty, assume it's a country code list
  EXIT_NODES="$1"
fi

# === STEP 1: Check if Tor is installed ===
if ! command -v tor &> /dev/null; then
  echo "Tor not found. Installing..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
      debian | ubuntu | kali | parrot)
        sudo apt update -qq && sudo apt install -y tor torsocks >/dev/null
        ;;
      arch | manjaro)
        sudo pacman -Sy --noconfirm tor torsocks >/dev/null
        ;;
      fedora)
        sudo dnf install -y tor torsocks -q >/dev/null
        ;;
      centos | rhel)
        sudo yum install -y epel-release >/dev/null
        sudo yum install -y tor torsocks >/dev/null
        ;;
      opensuse* | suse*)
        sudo zypper install -y tor torsocks >/dev/null
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

# === STEP 2: Create torrc dynamically ===
if [ ! -f "$TORRC_PATH" ]; then
  mkdir -p "$TOR_DIR"
  mkdir -p "$DATA_DIR"
fi

cat > "$TORRC_PATH" <<EOF
## Allow applications to use Tor via SOCKS5
SocksPort 9050

## Enable control over Tor from the CLI (for rotating circuits, etc.)
ControlPort ${CONTROL_PORT}

## Use cookie authentication (more secure than password)
CookieAuthentication 1

## Optional: Limit exit nodes by country
EOF

if [[ -n "$EXIT_NODES" ]]; then
  IFS=',' read -ra CODES <<< "$EXIT_NODES"
  NODE_LIST=""
  for CODE in "${CODES[@]}"; do
    NODE_LIST+="{${CODE}},"
  done
  NODE_LIST=${NODE_LIST%,}  # Remove trailing comma
  echo "ExitNodes $NODE_LIST" >> "$TORRC_PATH"
  echo "StrictNodes 1" >> "$TORRC_PATH"
fi

cat >> "$TORRC_PATH" <<EOF
              
## Disable DNS leaks
DNSPort 5353
AutomapHostsOnResolve 1

## Required: Store Tor's runtime state (including cookie)
DataDirectory ${DATA_DIR}
EOF

# === STEP 3: Start Tor (user-owned) if not already running ===
if ! pgrep -x "tor" > /dev/null; then
  echo "Starting Tor with torrc: $TORRC_PATH"
  tor -f "$TORRC_PATH" &> "$TOR_DIR/tor.log" &
  sleep 5
fi

# === STEP 4: Check for control_auth_cookie ===
FILESIZE=$(wc -c < "$COOKIE_PATH")
if [ ! -f "$COOKIE_PATH" ] || [ "$FILESIZE" -ne 32 ]; then
  echo "❌ Invalid or missing control_auth_cookie at $COOKIE_PATH"
  exit 1
fi    
chmod 600 "$COOKIE_PATH"

# === STEP 5: Begin rotation loop ===
if [[ -n "$EXIT_NODES" ]]; then
  printf "Rotating Tor IP every \033[32m$(($INTERVAL / 60)) minute(s)\033[0m using \033[32m$EXIT_NODES\033[0m exit nodes... (Ctrl+C to stop)\n"
else
  printf "Rotating Tor IP every \033[32m$(($INTERVAL / 60)) minute(s)\033[0m... (Ctrl+C to stop)\n"
fi
printf "ℹ️ Don't forget to 'torify' your shell with: \033[34msource torsocks on\033[0m\n"
while true; do
  COOKIE=$(xxd -p "$COOKIE_PATH" | tr -d '\n')
  RESPONSE=$( (echo authenticate $COOKIE; echo signal newnym; echo quit) | nc 127.0.0.1 9051 )
  CHECK=$( curl --proxy socks5h://127.0.0.1:9050 -s https://check.torproject.org/api/ip )
  TOR_STATUS=$( echo "$CHECK" | sed -n 's/.*"IsTor":\([a-z]*\),.*/\1/p' ) 

  if echo "$RESPONSE" | grep -q "250 OK" && [[ "$TOR_STATUS" == "true" ]]; then
    IP=$( echo "$CHECK" | sed -n 's/.*"IP":"\([0-9.]*\)".*/\1/p' )
    printf "✅ IP rotated successfully at $(date)\nNew IP: \033[32m$IP\033[0m\n"
  else
    echo "❌ Failed to rotate IP at $(date)"
    echo "Tor response:"
    echo "$RESPONSE"
  fi

  sleep "$INTERVAL"
done
