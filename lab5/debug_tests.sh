#!/bin/bash
cd /home/craftoldw/1learningoutput/NKUOS/OS/lab5

for i in {1..5}; do
    echo "=== Run $i: spin ==="
    timeout 30 make qemu 2>&1 | grep -E "spin|Breakpoint|panic|kill|wait|assert|error" | head -15
    echo ""
done
