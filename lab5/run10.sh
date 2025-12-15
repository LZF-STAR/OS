#!/bin/bash
cd /home/craftoldw/1learningoutput/NKUOS/OS/lab5

for i in {1..10}; do
    echo "=== Test Run $i ==="
    timeout 180 make grade 2>&1 | grep -E "spin:|forktest:|Total Score"
    echo ""
done
