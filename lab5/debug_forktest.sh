#!/usr/bin/env bash

# 调试 forktest 的脚本 - 快速运行多次并检查结果
LOG_DIR="debug_logs"
RUNS=${1:-10}  # 默认运行10次，可通过参数修改

mkdir -p "$LOG_DIR"

echo "===== Forktest Debug Script ====="
echo "Running $RUNS times..."
echo ""

PASS=0
FAIL=0

for i in $(seq 1 $RUNS); do
    # 编译（只在第一次）
    if [ $i -eq 1 ]; then
        make build-forktest > /dev/null 2>&1
    fi
    
    # 运行 QEMU 并捕获输出
    OUTPUT=$(timeout 15 qemu-system-riscv64 -machine virt -nographic -bios default \
        -device loader,file=bin/ucore.img,addr=0x80200000 \
        -serial mon:stdio -monitor none 2>&1)
    
    # 保存完整日志
    echo "$OUTPUT" > "$LOG_DIR/run_$i.log"
    
    # 检查结果
    if echo "$OUTPUT" | grep -q "forktest pass."; then
        if echo "$OUTPUT" | grep -q "init check memory pass."; then
            PASS=$((PASS + 1))
            echo "Run $i: PASS"
        else
            FAIL=$((FAIL + 1))
            echo "Run $i: FAIL (missing 'init check memory pass')"
            echo "  -> Log saved to $LOG_DIR/run_$i.log"
        fi
    else
        FAIL=$((FAIL + 1))
        echo "Run $i: FAIL (missing 'forktest pass')"
        echo "  -> Log saved to $LOG_DIR/run_$i.log"
        # 打印最后几行帮助调试
        echo "  Last lines:"
        echo "$OUTPUT" | tail -10 | sed 's/^/    /'
    fi
done

echo ""
echo "===== Summary ====="
echo "Passed: $PASS / $RUNS"
echo "Failed: $FAIL / $RUNS"
echo "Pass rate: $(echo "scale=1; $PASS * 100 / $RUNS" | bc)%"
