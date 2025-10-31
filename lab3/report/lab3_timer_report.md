# Lab3 实验报告（中断与定时器）
---

## 目录
- 练习1：完善中断处理（已完成）
- 扩展练习 Challenge1：描述与理解中断流程（占位）
- 扩增练习 Challenge2：理解上下文切换机制（占位）
- 扩展练习 Challenge3：完善异常中断（占位）
- 本实验关键知识点与原理映射（占位）
- OS 原理中未覆盖但重要的知识点（占位）

---

## 练习1：完善中断处理（需要编程）

目标：在 `kern/trap/trap.c` 的时钟中断处理分支中补全逻辑，使系统每遇到 100 次时钟中断打印一行 `"100 ticks"`，累计打印 10 行后调用关机接口退出模拟器。

涉及文件（路径相对 `lab3/`）：
- `kern/trap/trap.c`：中断与异常的顶层分发与处理；本练习主要修改 `interrupt_handler()` 的 `IRQ_S_TIMER` 分支。
- `kern/driver/clock.c`、`kern/driver/clock.h`：时钟相关，提供 `clock_set_next_event()` 与全局 `ticks` 计数。
- `libs/sbi.h`：提供关机接口（通常为 `sbi_shutdown()`）。

### 实现内容
- 在 `interrupt_handler` 的 `IRQ_S_TIMER` 分支中：
  - 重新设置下一次时钟中断：调用 `clock_set_next_event()`。
  - 维护全局节拍计数 `ticks`，每次时钟中断执行 `ticks++`。
  - 每累计 100 次（`TICK_NUM = 100`）调用 `print_ticks()` 打印 `"100 ticks"`。
  - 打印 10 次后调用关机接口（一般为 `sbi_shutdown()`；若本环境使用 `shutdown()`/`shut_down()`，以实际声明为准）。
- 在 `trap.c` 文件内定义静态计数器 `tick_print_times` 记录打印次数。
- 在文件顶部引入 `<sbi.h>` 使用关机接口。

### 代码变更标识
- 所有新增/修改逻辑均以注释标识：
  - `// LAB3 YOUR CODE: ...` 或 `// LAB3 YOUR CODE BEGIN/END`。

### 定时器中断处理流程（简要）
1. 硬件触发 S 模式定时器中断，进入 `__alltraps` 保存上下文并切换至内核栈，然后跳转到 `trap()`。
2. `trap()` 调用 `trap_dispatch()`，根据 `tf->cause` 的最高位判断是中断还是异常；为中断则进入 `interrupt_handler()`。
3. 命中 `IRQ_S_TIMER` 分支后：
   - 调用 `clock_set_next_event()` 设定下一次中断（清除当前 STIP）。
   - `ticks++` 进行时钟节拍计数。
   - 若 `ticks % 100 == 0`：
     - 调用 `print_ticks()` 打印 `"100 ticks"`；
     - `tick_print_times++`；
     - 当 `tick_print_times >= 10` 时，调用关机接口（例如 `sbi_shutdown()`）。
4. 返回路径由 `trapentry.S` 完成寄存器恢复并执行 `sret`。

### 运行现象（预期）
- 运行系统后，大约每 1 秒打印一次 `100 ticks`，累计 10 行后自动关机（或在评分模式下以 `panic("EOT: kernel seems ok.")` 结束）。

### 备注
- `ticks` 由 `kern/driver/clock.c` 定义，并在 `clock.h` 中以 `extern volatile size_t ticks;` 暴露；`trap.c` 已包含 `<clock.h>`。
- `print_ticks()` 在 `trap.c` 内部实现，使用 `TICK_NUM` 控制打印节拍。
- 关机函数名称以 `libs/sbi.h` 中的实际声明为准（常见为 `sbi_shutdown()`）。

---

## 扩展练习 Challenge1：描述与理解中断流程
本节基于 `kern/trap/trapentry.S` 的实现进行剖析，并按四个小问作答。

### 1) 从异常/中断产生到处理完成的整体流程
- 触发：CPU 在 S 模式产生异常/中断后，硬件跳转到 `stvec` 指向的入口，本实验设置为 `__alltraps`。
- 入口 `__alltraps`：
  - 执行 `SAVE_ALL` 宏：
    - `csrw sscratch, sp` 临时保存“陷入前的 sp”到 `sscratch`，避免直接覆盖；
    - `addi sp, sp, -36*REGBYTES` 为陷入帧分配栈空间；
    - 依次 `STORE` 通用寄存器到以 `sp` 为基址的固定偏移；
    - `csrrw s0, sscratch, x0` 将“陷入前的 sp”读回到 `s0`，并把 `sscratch` 清零，标识“当前处于内核态陷入”；
    - 读取并保存 CSR：`sstatus`、`sepc`、`sbadaddr`、`scause` 到陷入帧尾部；
  - `move a0, sp` 把陷入帧指针作为第一个参数传给 C 例程；
  - `jal trap` 跳转至 `trap(struct trapframe* tf)` 做类型分发和具体处理；
- 返回：
  - C 处理结束回到 `__trapret`，执行 `RESTORE_ALL`：
    - 恢复 `sstatus`、`sepc`；
    - 按固定偏移恢复通用寄存器，最后用保存的槽位恢复 `sp`；
  - `sret` 从 S 模式陷入返回到被中断/异常的指令（或下一条）。

### 2) `move a0, sp` 的目的
- RISC-V 调用约定：第一个函数参数放在 `a0`。
- `SAVE_ALL` 后 `sp` 指向当前构造好的陷入帧（trapframe）。
- 因此 `move a0, sp` 的目的是“把 trapframe 的指针传给 C 的 `trap(tf)`”，便于 C 代码按结构体字段读取寄存器与 CSR 并进行处理。

### 3) `SAVE_ALL` 中寄存器在栈上的位置如何确定
- 采用固定偏移布局，由汇编与 C 侧的 `struct pushregs/struct trapframe` 共同约定并严格匹配：
  - 总共分配 `36*REGBYTES` 空间：
    - 通用寄存器区：索引 `0..31` 对应 `x0..x31`；其中 `x2(sp)` 的保存通过 `sscratch` 中转，最终写入索引 `2` 的槽位，以便恢复阶段统一 `LOAD x2, 2*REGBYTES(sp)`；
    - CSR 区：`sstatus`、`sepc`、`sbadaddr`、`scause` 依次位于索引 `32..35`；
  - 这些下标、顺序与偏移必须与 C 结构体一一对应，否则 `print_trapframe()`、`trap()` 的解析会错位。

### 4) `__alltraps` 是否需要对任何中断/异常都保存所有寄存器？理由是什么
- 结论（针对本实验）：采用“统一保存所有通用寄存器 + 必要 CSR”的做法是正确且更稳妥的。

- 关于最小需要保存的内容
  - CSR：`sstatus` 与 `sepc` 必须保存，否则无法正确恢复特权状态与返回地址；`scause`/`stval`（代码中名称为 `sbadaddr`）虽非恢复所必需，但对诊断与处理逻辑很重要。
  - 通用寄存器：至少需要保证被中断上下文在返回时“看见完全相同的寄存器值”。由于我们会调用 C 函数（`jal trap`），它可能破坏 caller-saved 甚至 callee-saved（取决于编译器与调用链）。为不对 C 侧建立脆弱假设，最安全的策略是统一保存并恢复所有 GPR（x0..x31）。
  - 注：x0 恒为 0，从语义上不需要保存；实验代码保存它主要是为了“布局整齐、索引统一”，方便 C 侧用固定下标访问整块寄存器区。

- 为什么不做“按需最小保存”？
  - 正确性：入口若仅保存 caller-saved，再视情况“可能”保存 callee-saved，会引入多路径与条件竞争（尤其是编译优化、内联、LTO 可能改变寄存器分配）。
  - 可维护性与可调试性：统一 trapframe 结构便于打印、栈回溯、嵌套陷入与未来特性扩展；按需保存导致不同陷入帧形状，调试与工具支持复杂化。
  - 嵌套/抢占：若计划在处理中（或稍后）打开中断以支持嵌套、定时器抢占，必须确保当前上下文帧“完整可靠”，否则再次陷入会破坏尚未保存的寄存器。

- 性能与时延的权衡：
  - 统一全保存确实增加了存取次数与陷入时延，在本次实验中，这一开销通常是可接受的，换来的是健壮性与简洁实现。
  - 只有在强约束的低时延场景（硬实时、极高 QPS 中断）才会严肃考虑“最小保存”或“分层保存”。



## 扩增练习 Challenge2：理解上下文切换机制（占位）
待完成。

## 扩展练习 Challenge3：完善异常中断（占位）
待完成。

---

## 本实验关键知识点与原理映射（占位）
待补充。

## OS 原理中未覆盖但重要的知识点（占位）
待补充。
