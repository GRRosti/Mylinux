#!/bin/bash

# Configuration
TARGETS=("google.com" "facebook.com" "tiktok.com" "youtube.com" "netflix.com")
PING_COUNT="5"
LOG_FILE="pingstorm.log"
RESULT_FILE="ping_results.txt"
CSV_FILE="ping_results.csv"

# Logging function
log() {
  local module="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$module] $message" >> "$LOG_FILE"
}

# Ping function
ping_service() {
  local target="$1"
  local ping_output=$(ping -c "$PING_COUNT" "$target" 2>&1)
  local latency=$(echo "$ping_output" | awk '/rtt/ {print $4}' | cut -d'/' -f1 | sed 's/\ //g')
  local packet_loss=$(echo "$ping_output" | awk '/packet loss/ {print $6}' | sed 's/%//g')

  if [[ -z "$latency" ]] || [[ -z "$packet_loss" ]]; then
    log "ping_service" "Failed to parse ping output for $target."
    echo "$target,N/A"
  elif [[ "$packet_loss" -eq 100 ]]; then
    log "ping_service" "100% packet loss for $target."
    echo "$target,100%_LOSS"
  else
    log "ping_service" "Pinged $target, average latency: $latency ms."
    echo "$target,$latency"
  fi
}
# Process results
process_results() {
  local fastest=""
  local slowest=""
  local fastest_latency=999999
  local slowest_latency=0
  local total_latency=0
  local count=0

  # Clear existing result file
  > "$RESULT_FILE"

  for target in "${TARGETS[@]}"; do
    local result=$(ping_service "$target")
    echo "$result" >> "$RESULT_FILE"
  done

  # Process results
  while IFS=',' read -r full_domain latency; do
    domain=$(echo "$full_domain" | sed 's/[^a-zA-Z0-9._-]//g') #remove all non alpha numeric characters.
    if [[ "$latency" == "100%_LOSS" ]]; then
      continue #skip this line.
    fi

    if [[ "$latency" != "N/A" ]]; then
      local latency_float=$(echo "$latency" | awk '{print $1 + 0}')
      total_latency=$(echo "$total_latency + $latency_float" | bc)
      count=$((count + 1))

      if (( $(echo "$latency_float < $fastest_latency" | bc -l) )); then
        fastest="$domain"
        fastest_latency="$latency_float"
      fi

      if (( $(echo "$latency_float > $slowest_latency" | bc -l) )); then
        slowest="$domain"
        slowest_latency="$latency_float"
      fi
    fi
  done < "$RESULT_FILE"

  # Sort by latency
  sort -t',' -k2n "$RESULT_FILE" > sorted_results.tmp
  mv sorted_results.tmp "$RESULT_FILE"

  if [[ "$count" -gt 0 ]]; then
    local average_latency=$(echo "$total_latency / $count" | bc)
    log "process_results" "Average latency: $average_latency ms"
  else
    log "process_results" "No valid latency data to calculate average."
  fi
}

# Export to CSV
export_csv() {
  echo "Domain,Latency (ms)" > "$CSV_FILE"
  while IFS=',' read -r domain latency; do
    if [[ "$latency" == "100%_LOSS" ]]; then
        echo "$domain, 100% Packet Loss" >> "$CSV_FILE"
    else
        echo "$domain,$latency" >> "$CSV_FILE"
    fi
  done < "$RESULT_FILE"
  log "export_csv" "Results exported to $CSV_FILE"
}

# Control script functions
start_pingstorm() {
  log "pingstorm_control" "Starting pingstorm."
  process_results
  export_csv
  echo ""
  echo "PingStorm completed."
  echo "------------------"
  echo "Results are in:"
  echo "  - $RESULT_FILE"
  echo "  - $CSV_FILE"
  echo "Logs are in:"
  echo "  - $LOG_FILE"
  echo ""
  echo "Sorted Ping Results (Valid Latencies):"
  echo "-------------------------------------"
  local valid_count=0
  local valid_total=0

  while IFS=',' read -r domain latency; do
    if [[ "$latency" == "100%_LOSS" ]]; then
      echo "$domain: 100% Packet Loss"
      continue
    fi

    if [[ "$latency" != "N/A" ]]; then
    local bar_length=$(echo "scale=0; $latency / 5" | bc) # Corrected line
    local bar=""
    for ((i = 0; i < bar_length; i++)); do
        bar+="="
    done
 

      if [[ "$domain" == "$fastest" ]]; then
        echo -e "\033[32m$domain: $latency ms [$bar] (Fastest)\033[0m"
      elif [[ "$domain" == "$slowest" ]]; then
        echo -e "\033[31m$domain: $latency ms [$bar] (Slowest)\033[0m"
      else
        echo "$domain: $latency ms [$bar]"
      fi
      valid_total=$(echo "$valid_total + $latency" | bc) # use bc for addition.
      valid_count=$((valid_count + 1))
    fi
  done < "$RESULT_FILE"

  if [[ "$valid_count" -gt 0 ]]; then
    local average_latency=$(echo "$valid_total / $valid_count" | bc) #use bc for division.
    echo ""
    echo "Average latency (Valid Results): $average_latency ms"
  else
    echo ""
    echo "No valid latency data to display."
  fi

}

stop_pingstorm() {
  log "pingstorm_control" "Stopping pingstorm (no process to stop, just log)"
  echo "Pingstorm stopped (no process to stop)."
}

pingstorm_status() {
  log "pingstorm_control" "Checking pingstorm status (always ready)"
  echo "Pingstorm is ready."
}

show_last_logs() {
  log "pingstorm_control" "Showing last 10 log lines."
  tail -n 10 "$LOG_FILE"
}

# Main script
if [[ "$1" == "start" ]]; then
  start_pingstorm
elif [[ "$1" == "stop" ]]; then
  stop_pingstorm
elif [[ "$1" == "status" ]]; then
  pingstorm_status
elif [[ "$1" == "logs" ]]; then
  show_last_logs
else
  echo "Usage: $0 {start|stop|status|logs}"
  exit 1
fi
