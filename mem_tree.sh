#!/bin/bash

# Configuration
OUTPUT_FILE="./memory_usage.txt"
ECHO_ENABLED=0
SHOW_COLORS=1
MAX_ENTRIES=50
TMP_FILE=$(mktemp)

# Colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

# Help message
show_help() {
    echo "Usage: $0 [-o file] [-e] [-n num] [-c] [-h]"
    echo "Options:"
    echo "  -o FILE   Output file (default: ./memory_usage.txt)"
    echo "  -e        Echo output to terminal while writing to file"
    echo "  -n NUM    Show top N entries (default: all)"
    echo "  -c        Disable color output"
    echo "  -h        Show this help message"
    exit 0
}

# Parse options
while getopts ":o:en:ch" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG" ;;
        e) ECHO_ENABLED=1 ;;
        n) [[ $OPTARG =~ ^[0-9]+$ ]] && MAX_ENTRIES="$OPTARG" || { echo "Invalid number: -n $OPTARG"; exit 1; } ;;
        c) SHOW_COLORS=0 ;;
        h) show_help ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

# Get system statistics
get_system_stats() {
    # Disk statistics
    local disk_info=$(df -k . | awk 'NR==2 {print $2,$3,$4}')
    DISK_TOTAL=$(( $(echo "$disk_info" | awk '{print $1}') * 1024 ))
    DISK_USED=$(( $(echo "$disk_info" | awk '{print $2}') * 1024 ))
    DISK_FREE=$(( $(echo "$disk_info" | awk '{print $3}') * 1024 ))

    # Memory statistics (macOS/Linux compatible)
    if [ "$(uname)" = "Darwin" ]; then
        local page_size=$(vm_stat | awk '/page size of/ {print $8}')
        MEM_TOTAL=$(sysctl -n hw.memsize)
        
        local vm_stats=$(vm_stat)
        local free_pages=$(echo "$vm_stats" | awk '/free/ {gsub(/\./, ""); print $NF}')
        local inactive_pages=$(echo "$vm_stats" | awk '/inactive/ {gsub(/\./, ""); print $NF}')
        local speculative_pages=$(echo "$vm_stats" | awk '/speculative/ {gsub(/\./, ""); print $NF}')
        
        MEM_FREE=$(( (free_pages + inactive_pages + speculative_pages) * page_size ))
        MEM_USED=$(( MEM_TOTAL - MEM_FREE ))
    else
        MEM_TOTAL=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)
        MEM_FREE=$(awk '/MemAvailable/ {print $2 * 1024}' /proc/meminfo)
        MEM_USED=$(( MEM_TOTAL - MEM_FREE ))
    fi
}

# Safe bc calculation
bc_calc() {
    local expression=$1
    bc -l <<< "scale=2; $expression" 2>/dev/null || echo "0.00"
}

human_readable() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
        return
    fi
    local suffixes=("K" "M" "G" "T")
    for suffix in "${suffixes[@]}"; do
        bytes=$(bc_calc "$bytes / 1024")
        if (( $(echo "$bytes < 1024" | bc -l) )); then
            echo "$(printf "%'.1f" "$bytes")${suffix}"
            return
        fi
    done
}

color_percent() {
    local percent=$1
    if [ "$SHOW_COLORS" -eq 0 ]; then
        printf "%.2f%%" "$percent"
        return
    fi
    
    if (( $(echo "$percent > 75" | bc -l) )); then
        printf "${RED}%.2f%%${NC}" "$percent"
    elif (( $(echo "$percent > 25" | bc -l) )); then
        printf "${YELLOW}%.2f%%${NC}" "$percent"
    else
        printf "${GREEN}%.2f%%${NC}" "$percent"
    fi
}

generate_report() {
    echo -e "${BLUE}=== System Statistics ===${NC}"
    
    # Disk stats
    local disk_used_percent=$(bc_calc "$DISK_USED / $DISK_TOTAL * 100")
    local disk_free_percent=$(bc_calc "100 - $disk_used_percent")
    
    printf "Disk Total: %15s | Used: %15s (%s) | Free: %15s (%s)\n" \
        "$(human_readable $DISK_TOTAL)" \
        "$(human_readable $DISK_USED)" \
        "$(color_percent $disk_used_percent)" \
        "$(human_readable $DISK_FREE)" \
        "$(color_percent $disk_free_percent)"

    # Memory stats
    local mem_used_percent=$(bc_calc "$MEM_USED / $MEM_TOTAL * 100")
    local mem_free_percent=$(bc_calc "100 - $mem_used_percent")
    
    printf "RAM  Total: %15s | Used: %15s (%s) | Free: %15s (%s)\n\n" \
        "$(human_readable $MEM_TOTAL)" \
        "$(human_readable $MEM_USED)" \
        "$(color_percent $mem_used_percent)" \
        "$(human_readable $MEM_FREE)" \
        "$(color_percent $mem_free_percent)"

    echo -e "${BLUE}=== Directory Analysis ===${NC}"
    find . -mindepth 1 -type d \
        -not \( -path "./Library/*" -o -path "./.Trash/*" -o -path "./.vol" \) \
        -print0 2>/dev/null \
    | xargs -0 du -sk 2>/dev/null \
    | sort -nrk1 \
    | head -n ${MAX_ENTRIES:-100000} \
    | awk -v total="$DISK_TOTAL" -v color="$SHOW_COLORS" '
      function hr(bytes) {
          if (bytes < 1024) return sprintf("%8.1fB", bytes)
          suffixes = "KMGTP"
          for (i = 0; bytes >= 1024 && i < 5; i++) bytes /= 1024
          return sprintf("%8.1f%s", bytes, substr(suffixes, i, 1))
      }
      
      function color_percent(pct) {
          fmt = "%6.2f%%"
          if (!color) return sprintf(fmt, pct)
          
          if (pct > 75) color_code = "\033[1;31m"
          else if (pct > 25) color_code = "\033[1;33m"
          else color_code = "\033[1;32m"
          
          return sprintf("%s" fmt "\033[0m", color_code, pct)
      }
      
      function format_path(depth, path) {
          # Total width allocated for path column: 50 characters
          max_path_width = 50
          indent = depth * 2
          max_content_width = max_path_width - indent
          
          # Truncate path with leading ellipsis if needed
          if (length(path) > max_content_width) {
              truncated = "..." substr(path, length(path) - max_content_width + 4)
          } else {
              truncated = path
          }
          
          # Pad right to fill column
          return sprintf("%*s%-*s", indent, "", max_content_width, truncated)
      }
      
      {
          size_bytes = $1 * 1024
          full_path = $2
          sub(/^\.\//, "", full_path)
          
          # Calculate depth
          depth = gsub(/\//, "/", full_path)
          
          # Format output with fixed columns
          percent = (size_bytes / total) * 100
          if (!seen[full_path]++) {
              # First column: 50 characters for path
              # Second column: 10 characters for size
              # Third column: 10 characters for percentage
              printf "%s%s%s\n", 
                  format_path(depth, full_path),
                  hr(size_bytes),
                  color_percent(percent)
          }
      }
'
}

# Main execution
get_system_stats
{
    generate_report
} | {
    if [ "$ECHO_ENABLED" -eq 1 ]; then
        tee "$OUTPUT_FILE"
    else
        cat > "$OUTPUT_FILE"
    fi
}

rm -f "$TMP_FILE"
echo "Report generated: $OUTPUT_FILE"cho "Report generated: $OUTPUT_FILE"
