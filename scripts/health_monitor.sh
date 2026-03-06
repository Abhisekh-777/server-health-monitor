#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/config.conf"
source "$CONFIG_FILE"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$SCRIPT_DIR/../logs/health_$(date '+%Y-%m-%d').log"
ALERT_TRIGGERED=false

log() { echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"; }

check_cpu() {
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
  CPU_INT=${CPU_USAGE%.*}
  if (( CPU_INT >= CPU_CRITICAL )); then STATUS="${RED}CRITICAL${NC}"; ALERT_TRIGGERED=true; log "ALERT: CPU CRITICAL at ${CPU_USAGE}%"
  elif (( CPU_INT >= CPU_WARN )); then STATUS="${YELLOW}WARNING${NC}"; ALERT_TRIGGERED=true
  else STATUS="${GREEN}OK${NC}"; log "INFO: CPU normal at ${CPU_USAGE}%"; fi
  echo -e "  CPU Usage   : ${CPU_USAGE}%  [ $STATUS ]"
}

check_ram() {
  RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
  RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
  RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))
  if (( RAM_PCT >= RAM_CRITICAL )); then STATUS="${RED}CRITICAL${NC}"; ALERT_TRIGGERED=true; log "ALERT: RAM CRITICAL at ${RAM_PCT}%"
  elif (( RAM_PCT >= RAM_WARN )); then STATUS="${YELLOW}WARNING${NC}"; ALERT_TRIGGERED=true
  else STATUS="${GREEN}OK${NC}"; log "INFO: RAM normal at ${RAM_PCT}%"; fi
  echo -e "  RAM Usage   : ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)  [ $STATUS ]"
}

check_disk() {
  echo -e "  Disk Usage"
  while IFS= read -r line; do
    MOUNT=$(echo "$line" | awk '{print $6}')
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    USED=$(echo "$line" | awk '{print $3}')
    TOTAL=$(echo "$line" | awk '{print $2}')
    if (( USAGE >= DISK_CRITICAL )); then STATUS="${RED}CRITICAL${NC}"; ALERT_TRIGGERED=true; log "ALERT: Disk $MOUNT CRITICAL at ${USAGE}%"
    elif (( USAGE >= DISK_WARN )); then STATUS="${YELLOW}WARNING${NC}"; ALERT_TRIGGERED=true
    else STATUS="${GREEN}OK${NC}"; fi
    echo -e "       ${MOUNT}: ${USED}/${TOTAL} (${USAGE}%)  [ $STATUS ]"
  done < <(df -h | grep -vE '^(Filesystem|tmpfs|udev|none)' | awk 'NF==6')
}

check_services() {
  echo -e "  Services"
  IFS=',' read -ra SVCS <<< "$SERVICES_TO_CHECK"
  for svc in "${SVCS[@]}"; do
    svc=$(echo "$svc" | xargs)
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo -e "       ${svc}: [ ${GREEN}RUNNING${NC} ]"; log "INFO: $svc RUNNING"
    else
      echo -e "       ${svc}: [ ${RED}DOWN${NC} ]"; ALERT_TRIGGERED=true; log "ALERT: $svc is DOWN"
    fi
  done
}

check_network() {
  if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then NET="${GREEN}CONNECTED${NC}"
  else NET="${RED}DISCONNECTED${NC}"; ALERT_TRIGGERED=true; fi
  echo -e "  Network    : [ $NET ]"
  echo -e "  Uptime     : $(uptime -p)"
}

mkdir -p "$(dirname "$LOG_FILE")"
echo ""
echo -e "${BOLD}${CYAN}============================================${NC}"
echo -e "${BOLD}${CYAN}   SERVER HEALTH MONITOR${NC}"
echo -e "${BOLD}${CYAN}   $TIMESTAMP${NC}"
echo -e "${BOLD}${CYAN}============================================${NC}"
echo ""
log "===== Health Check Started ====="
check_cpu
echo ""
check_ram
echo ""
check_disk
echo ""
check_services
echo ""
check_network
echo ""
echo -e "${CYAN}--------------------------------------------${NC}"
if [[ "$ALERT_TRIGGERED" == true ]]; then
  echo -e "  ${RED}${BOLD}ALERTS TRIGGERED — check logs/ folder${NC}"
else
  echo -e "  ${GREEN}${BOLD}All systems HEALTHY${NC}"
fi
echo -e "${CYAN}--------------------------------------------${NC}"
echo ""
log "===== Health Check Completed ====="
