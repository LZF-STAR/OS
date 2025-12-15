#!/bin/bash
cd /home/craftoldw/1learningoutput/NKUOS/OS/lab5

echo "=== Running spin test ==="
timeout 20 make run-spin 2>&1 | tail -50
echo ""
echo "=== spin test exit code: $? ==="
echo ""

echo "=== Running forktest test ==="
timeout 20 make run-forktest 2>&1 | tail -50
echo ""
echo "=== forktest exit code: $? ==="
