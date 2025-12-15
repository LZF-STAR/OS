#!/bin/bash
# 快速forktest测试脚本

cd /home/craftoldw/1learningoutput/NKUOS/OS/lab5

PASS=0
FAIL=0
TOTAL=${1:-10}

echo "Running forktest $TOTAL times..."

for i in $(seq 1 $TOTAL); do
    RESULT=$(timeout 10 qemu-system-riscv64 -machine virt -nographic -bios default \
        -device loader,file=bin/ucore.img,addr=0x80200000 \
        -serial mon:stdio -monitor none 2>&1)
    
    if echo "$RESULT" | grep -q "forktest pass."; then
        echo "Run $i: PASS"
        PASS=$((PASS+1))
    else
        echo "Run $i: FAIL"
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "===== Summary ====="
echo "PASS: $PASS / $TOTAL"
echo "FAIL: $FAIL / $TOTAL"
