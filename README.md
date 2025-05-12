# Directory Memory Analyzer 📂💾

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)
![CLI](https://img.shields.io/badge/CLI-Bash%204%2B-brightgreen.svg)

A powerful CLI tool that combines hierarchical visualization of `tree` with detailed memory analysis of `du`, enhanced with system statistics and smart formatting.

![CLI Example](https://via.placeholder.com/800x400.png?text=Sample+CLI+Output+With+Colors+And+Hierarchy)

## Features ✨

- **Holistic System Stats**
  - Disk usage breakdown (Used/Free)
  - RAM consumption analysis
  - Percentage-based color alerts (🔴 >75%, 🟡 25-75%, 🟢 <25%)

- **Intelligent Directory Analysis**
  - True hierarchical display
  - Size percentages relative to filesystem
  - Adaptive path truncation (max 50 chars)
  - Depth-based indentation (2 spaces/level)

- **Enterprise-Grade Features**
  - Cross-platform (macOS/Linux)
  - Color output toggle (`-c`)
  - File output + live preview (`-o` + `-e`)
  - Top-N filtering (`-n`)
  - Permission-safe scanning

## Installation ⚙️

```bash
# Download and make executable
# just git clone and copy the file bro... it's not that hard
chmod +x mem_tree.sh

# System-wide install (optional)
sudo mv mem_tree.sh /usr/local/bin/memtree
```

## Usage 🚀

```bash
# Basic scan (current directory)
./mem_tree.sh -e

# Save report with live preview
./mem_tree.sh -o scan.txt -e

# Top 20 largest items
./mem_tree.sh -n 20

# Full scan (hidden files, no colors)
./mem_tree.sh -c -a
```

## Options 🛠

| Flag | Description                          | Default               |
|------|--------------------------------------|-----------------------|
| `-o` | Output file path                     | `memory_usage.txt`    |
| `-e` | Echo output to terminal while saving | `Disabled`            |
| `-n` | Show top N entries                   | `Show all`            |
| `-c` | Disable color output                 | `Colors enabled`      |
| `-h` | Display help message                 | `N/A`                 |


## Output Guide 🔍
### System Statistics Section
```bash
Disk Total:         500G | Used: 350G (70.00%) | Free: 150G (30.00%)
RAM Total:           16G | Used:   4G (25.00%) | Free:  12G (75.00%)
# All values calculated at hardware level
```
### Directory Analysis
```bash
  projects                    800.0M   16.00%
    client_a                  600.0M   12.00%
      assets                  550.0M   11.00%
        video.mp4            520.0M   10.40%  🔴
```
- Indentation: Directory depth

- Colors: Usage thresholds

- Truncation: .../final/path for long names


well... the rest I don't have much time for this, clone, fork and pr that's it...








