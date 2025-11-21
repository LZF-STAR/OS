# 实验 4 报告

## 实验目的

-   熟悉进程控制块（PCB）结构及其初始化
-   理解内核线程创建（fork）过程中需要复制与分配的资源
-   实现进程切换（proc_run）并掌握中断和页表切换的配合
-   深入理解分页模式与页表项操作（get_pte）

---

## 练习 0：已有实验合并

要求：本实验依赖 lab2/lab3，请将你在 lab2、lab3 中的实现合并到 lab4 中 `LAB2`、`LAB3` 注释标注的位置。

关于lab2的内容不需要额外填写，将上次lab3中的时钟中断代码迁移过来即可

---

## 练习 1：alloc_proc 的实现与说明

任务：在 `kern/process/proc.c` 中完成 `alloc_proc` 函数，对新分配的 `struct proc_struct` 做基本初始化。

请在此处填写你的实现说明：

### alloc_proc 函数实现说明

`alloc_proc` 函数的主要功能是分配并初始化一个新的进程结构体 `proc_struct`。以下是实现的详细说明：

1. **内存分配**：
   ```c
   struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
   ```
   - 使用 `kmalloc` 分配一块内存，用于存储一个 `proc_struct` 结构体。
   - 如果分配失败，`kmalloc` 返回 `NULL`，函数直接返回。

2. **字段初始化**：
   ```c
   proc->state = PROC_UNINIT;
   proc->pid = -1;
   proc->runs = 0;
   proc->kstack = 0;
   proc->need_resched = 0;
   proc->parent = NULL;
   proc->mm = NULL;
   proc->tf = NULL;
   proc->pgdir = boot_pgdir_pa;
   proc->flags = 0;
   memset(&(proc->context), 0, sizeof(struct context));
   memset(proc->name, 0, PROC_NAME_LEN);
   ```
   - **`state`**: 设置为 `PROC_UNINIT`，表示进程未初始化。
   - **`pid`**: 设置为 `-1`，表示进程 ID 尚未分配。
   - **`runs`**: 初始化为 `0`，表示进程的运行次数为 0。
   - **`kstack`**: 初始化为 `0`，表示内核栈地址尚未分配。
   - **`need_resched`**: 初始化为 `0`，表示进程不需要重新调度。
   - **`parent`**: 设置为 `NULL`，表示没有父进程。
   - **`mm`**: 设置为 `NULL`，表示进程的内存管理结构尚未分配。
   - **`tf`**: 设置为 `NULL`，表示进程的中断帧尚未分配。
   - **`pgdir`**: 设置为 `boot_pgdir_pa`，表示页表基地址。
   - **`flags`**: 初始化为 `0`，表示进程标志位清零。
   - **`context`**: 使用 `memset` 将 `context` 结构体清零，确保上下文切换时的初始状态。
   - **`name`**: 使用 `memset` 将进程名称清零。

3. **返回结果**：
   ```c
   return proc;
   ```
   - 如果内存分配成功并初始化完成，返回指向 `proc_struct` 的指针。
   - 如果内存分配失败，返回 `NULL`。

### 总结
`alloc_proc` 函数是进程管理的基础，确保每个新创建的进程结构体都被正确初始化，为后续的进程调度和运行奠定了基础。

问题回答：

1. 请说明 `proc_struct` 中 `struct context context` 和 `struct trapframe *tf` 成员的含义及在本实验中的作用。

-   struct context context：

    -   含义：用于保存内核线程在上下文切换（`switch_to`）时需要保存的寄存器状态。它只包含必须由被调用者（callee-saved）保存的寄存器，在 RISC-V 中包括返回地址 `ra`、栈指针 `sp` 和 `s0-s11` 寄存器。
    -   在本实验中的作用：当进程 A 被切换出 CPU 时，其 `context` 结构中保存了它在内核态执行的断点。当 `switch_to` 函数被调用时，它会将当前 CPU 的 callee-saved 寄存器存入旧进程的 `context`，并从新进程的 `context` 中恢复寄存器。对于一个新创建的线程，它的 `context.ra` 被设置为 `forkret` 函数地址，`context.sp` 指向其内核栈顶，确保它第一次被调度时能正确启动。

-   struct trapframe \*tf：

    -   含义：`tf` 是一个指向陷阱帧（trapframe）的指针。陷阱帧保存了发生中断、异常或系统调用时，用户态（或内核态）的**所有**寄存器状态，包括通用寄存器 `x1-x31`、程序计数器 `epc` 和状态寄存器 `sstatus` 等。
    -   在本实验中的作用：`trapframe` 使得中断/异常处理结束后能精确返回到原来的执行流。在 `do_fork` 创建新内核线程时，`kernel_thread` 函数会预先设置一个 `trapframe`，其中 `epc` 指向内核线程的入口点（`kernel_thread_entry`），`s0` 和 `s1` 存放线程要执行的函数和参数。这个 `tf` 被复制到新线程的内核栈上，当新线程启动并执行 `forkrets` 时，就会利用 `tf` 恢复寄存器，最终跳转到 `epc` 指定的入口函数开始执行。同时，`tf` 也用于在父子进程间传递返回值（例如，子进程的 `a0` 寄存器被设置为 0）。

（可在此处补充你通过读代码或调试观察到的更具体细节，如哪些寄存器被包含、tf 在何处分配和使用等。）

---

## 练习 2：do_fork 的实现与说明

任务：在 `kern/process/proc.c` 中完成 `do_fork` 函数，实现为新内核线程分配资源并复制父进程状态。

请在此处填写你的实现说明：

-   设计与实现要点（建议按步骤写清楚）：

    1.  **调用 `alloc_proc` 获得一个新的 PCB**：分配并初始化进程控制块，失败时直接返回错误
    2.  **调用 `setup_kstack` 分配内核栈**：为子进程分配 `KSTACKPAGE` 大小的内核栈空间
    3.  **调用 `copy_mm` 复制内存管理信息**：根据 `clone_flags` 决定是复制还是共享内存空间（本实验中为空实现）
    4.  **调用 `copy_thread` 设置中断帧和上下文**：
        -   在内核栈顶设置 `trapframe`，复制父进程的 `tf` 内容
        -   将子进程的 `a0` 寄存器设置为 0（fork 返回值）
        -   设置 `context.ra` 为 `forkret` 函数地址，`context.sp` 指向 `trapframe`
    5.  **在临界区中完成进程注册**：
        -   禁用中断保证原子性
        -   调用 `get_pid()` 分配唯一 PID
        -   调用 `hash_proc()` 将进程加入哈希表
        -   将进程加入全局进程链表 `proc_list`
        -   增加进程计数 `nr_process`
    6.  **调用 `wakeup_proc` 唤醒子进程**：设置进程状态为 `PROC_RUNNABLE`
    7.  **返回子进程 PID**：成功时返回新进程的 PID

-   测试与验证：通过 `proc_init()` 函数中的 `kernel_thread(init_main, "Hello world!!", 0)` 创建第一个内核线程，运行 `make qemu` 可以在控制台看到输出：
    -   `alloc_proc() correct!` - 验证 `alloc_proc` 正确性
    -   `this initproc, pid = 1, name = "init"` - 验证 `do_fork` 成功创建进程

问题回答：

1. ucore 是否确保每个新 fork 的线程有唯一的 id？请说明分析和理由。

**答案：是的，ucore 通过多重机制确保每个新 fork 的线程都有唯一的 PID。**

**分析 `get_pid()` 函数的实现机制：**

ucore 使用一个精巧的 PID 分配算法，主要涉及两个静态变量：

-   `last_pid`：上次分配的 PID
-   `next_safe`：下一个"安全"的 PID 值

**算法工作原理：**

1. **快速路径**：如果 `++last_pid < next_safe`，直接返回 `last_pid`，无需检查冲突
2. **慢速路径**：当 `last_pid >= next_safe` 时，需要遍历进程链表检查冲突：
    - 遍历 `proc_list` 中的所有进程
    - 如果发现 `proc->pid == last_pid`，说明冲突，`last_pid++` 并重新检查
    - 同时更新 `next_safe` 为最小的大于 `last_pid` 的已占用 PID
3. **PID 回绕**：当 `last_pid >= MAX_PID` 时，重置为 1（PID 0 保留给 idle 进程）

**`last_pid` 和 `next_safe` 的作用：**

-   **`last_pid`**：记录上次分配的 PID，作为下次分配的起点，实现递增分配
-   **`next_safe`**：维护一个"安全区间" `[last_pid+1, next_safe)`，在此区间内的 PID 保证未被占用，可以快速分配而无需检查冲突

**唯一性保证机制：**

1. **原子性保护**：在 `do_fork()` 中，PID 分配和进程注册在 `local_intr_save/restore` 临界区中完成，确保操作原子性
2. **冲突检测**：`get_pid()` 通过遍历现有进程列表检测并避免 PID 冲突
3. **安全区间优化**：`next_safe` 机制减少了重复检查的开销，提高分配效率

**关键代码分析（proc.c 第 140-180 行）：**

```c
static int get_pid(void) {
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID) {
        last_pid = 1;  // PID回绕
        goto inside;
    }
    if (last_pid >= next_safe) {  // 需要重新计算安全区间
    inside:
        next_safe = MAX_PID;
    repeat:
        // 遍历进程链表检查冲突
        while ((le = list_next(le)) != list) {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid) {  // 发现冲突
                if (++last_pid >= next_safe) goto repeat;
            }
            else if (proc->pid > last_pid && next_safe > proc->pid) {
                next_safe = proc->pid;  // 更新安全边界
            }
        }
    }
    return last_pid;
}
```

**结论**：ucore 的 PID 分配机制通过冲突检测、原子操作和安全区间优化，确保了每个进程都有唯一的 PID，同时具有良好的性能。

---

## 练习 3：proc_run 的实现与说明

任务：实现 `proc_run` 函数，将指定进程切换上 CPU。实现要点列在练习说明中。

请在此处填写你的实现说明：

-   设计要点与实现细节：

    -   检查目标进程是否等于当前进程（若相同无需切换）
    -   使用 `local_intr_save(intr_flag)` 禁止中断并保存之前中断状态
    -   更新 `current` 或类似的当前进程指针
    -   切换页表（调用 `lsatp` 或 `write_csr(satp, ...)` 等），并执行 `sfence.vma` 如需要
    -   调用 `switch_to(&old->context, &new->context)` 完成上下文切换
    -   恢复中断状态 `local_intr_restore(intr_flag)`

-   关键代码片段（粘贴核心实现或路径参考）
-   测试与验证：如何运行并观察进程调度行为（例如：运行 `make qemu`，在串口日志或 printk 输出看到多个内核线程被调度）

问题回答：

1. 在本实验执行过程中，创建且运行了几个内核线程？

-   请在此列出你实际创建并运行的线程数量与名称（例如：init 线程、若干 worker 线程、idle 线程等），并简要说明其作用与创建位置。

---

## 扩展练习（Challenge）

1.  请说明语句 `local_intr_save(intr_flag); ... local_intr_restore(intr_flag);` 是如何实现开关中断的？

        - 实现要点（参考 `kern/sync/sync.h`）：

        	- `local_intr_save(x)` 实际调用 `__intr_save()`：该函数读取 CSR `sstatus`，检查其中的 `SSTATUS_SIE`（Supervisor Interrupt Enable）位。如果该位为 1（表示中断当前允许），`__intr_save()` 会调用 `intr_disable()` 关闭中断并返回 1；若该位为 0，则直接返回 0。`local_intr_save` 将返回值保存到 `intr_flag` 中，从而记录进入临界区前的中断状态。

        	- `local_intr_restore(x)` 实际调用 `__intr_restore(x)`：该函数根据传入的 `intr_flag` 值决定是否调用 `intr_enable()` 恢复中断。只有当 `intr_flag` 为 1（进入前中断是开启的）时才重新开启中断；为 0 则保持关闭状态。

        - 为什么要保存并恢复（而不是简单调用 disable/enable）？

        	- 保存/恢复机制能正确处理嵌套临界区。举例：若外层函数 A 在进入时保存到 `fa=1` 并关闭中断，内层函数 B 再次调用 `local_intr_save(fb)` 会得到 `fb=0`（因为中断已经被关闭），B 退出时执行 `local_intr_restore(fb)` 将不会开启中断，避免破坏 A 的临界区。只有 A 最外层的 `local_intr_restore(fa)` 会真正恢复中断。示例代码：

        		```c
        		void A() {
        				local_intr_save(fa); // 若之前开启 -> 关闭，fa = 1
        				...
        				B();
        				...
        				local_intr_restore(fa); // 若 fa=1 恢复开启
        		}

        		void B() {
        				local_intr_save(fb); // 之前已关闭 -> fb = 0
        				...
        				local_intr_restore(fb); // fb=0 不恢复
        		}
        		```

        - 具体实现依赖的原语：`intr_disable()`/`intr_enable()` 通常通过修改 `sstatus` CSR 的中断使能位（例如 SIE/SPIE）来关闭/开启本地中断；`__intr_save()`/`__intr_restore()` 只是对这些原语的薄封装并加入状态保存逻辑。

        - 小结：`local_intr_save/restore` 提供了一种保存-恢复式的本地中断屏蔽机制，能安全地进入临界区并在退出时恢复进入前的中断状态，避免因嵌套保护导致的中断错开问题。这是内核中实现短临界区和保护共享数据结构的常用模式。

2.  分页模式思考题：

**Challenge 2 第一部分：`get_pte()` 函数分析**

**RISC-V 分页模式比较（sv32、sv39、sv48）：**

| 分页模式 | 地址位数 | 页表级数 | 每级索引位数 | 页大小 |
| -------- | -------- | -------- | ------------ | ------ |
| sv32     | 32 位    | 2 级     | 10 位        | 4KB    |
| sv39     | 39 位    | 3 级     | 9 位         | 4KB    |
| sv48     | 48 位    | 4 级     | 9 位         | 4KB    |

**`get_pte()` 中两段相似代码的原因分析：**

当前 lab4 使用的是 **sv39** 模式（3 级页表），`get_pte()` 函数中的两段相似代码分别处理不同级别的页表：

```c
// 第一段：处理第一级页表（PDX1）
pde_t *pdep1 = &pgdir[PDX1(la)];
if (!(*pdep1 & PTE_V)) {
    struct Page *page;
    if (!create || (page = alloc_page()) == NULL) {
        return NULL;
    }
    set_page_ref(page, 1);
    uintptr_t pa = page2pa(page);
    memset(KADDR(pa), 0, PGSIZE);
    *pdep1 = pte_create(page2ppn(page), PTE_U | PTE_V);
}

// 第二段：处理第二级页表（PDX0）
pde_t *pdep0 = &((pte_t *)KADDR(PDE_ADDR(*pdep1)))[PDX0(la)];
if (!(*pdep0 & PTE_V)) {
    // ... 相同的处理逻辑
}
```

**相似性原因：**

1. **多级页表的层次性**：每一级页表的处理逻辑本质相同，都需要：

    - 检查页表项是否有效（`PTE_V` 位）
    - 如果无效且 `create=true`，分配新的页面作为下一级页表
    - 初始化新分配的页表（清零）
    - 设置页表项指向新分配的页面

2. **统一的页表项格式**：无论哪一级，页表项的格式都相同，包含有效位、权限位和物理页号

3. **递归的地址转换过程**：
    - sv39: VA → L2 页表 → L1 页表 → L0 页表 → 物理页
    - 每级转换都是"索引 → 检查 → 可能分配 → 获取下级地址"

**为什么不同分页模式有相似的处理流程：**

-   **sv32（2 级）**：只需要一段这样的代码（处理页目录）
-   **sv39（3 级）**：需要两段这样的代码（处理 L2 和 L1 页表）
-   **sv48（4 级）**：需要三段这样的代码（处理 L3、L2 和 L1 页表）

每增加一级页表，就需要增加一段相似的处理代码，这体现了多级页表设计的规律性和可扩展性。

**是否应将页表查找与页表分配拆分为两个函数？**

**支持拆分的理由：**

1. **单一职责原则**：查找和分配是两个不同的操作
2. **代码复用**：可以单独调用查找功能而不触发分配
3. **更清晰的接口**：`get_pte()` 和 `alloc_pte()` 语义更明确
4. **便于调试**：可以分别测试查找和分配逻辑

**支持合并的理由：**

1. **性能考虑**：避免重复遍历页表层次
2. **原子性**：查找和分配作为一个原子操作，避免并发问题
3. **使用便利**：大多数情况下需要"查找，如果不存在就分配"的语义
4. **减少函数调用开销**：特别是在内核中，函数调用有一定开销

**结论**：当前的设计是合理的。通过 `create` 参数统一接口既满足了只查找的需求（`create=0`），又提供了查找+分配的功能（`create=1`），是一个很好的权衡。如果一定要拆分，建议保留当前接口作为便利函数，同时提供底层的分离接口供特殊需求使用。

---

## 知识点映射（实验 ↔ OS 原理）

请列出：

**1) 在本实验中出现的重要知识点与 OS 原理的对应关系：**

-   **实验知识点：进程控制块（PCB）结构与初始化**

    -   OS 原理对应点：进程抽象与进程管理
    -   含义：`proc_struct` 包含进程状态、PID、内核栈、上下文等关键信息，是操作系统管理进程的核心数据结构
    -   关系与差异：实验中的 PCB 结构较简化，主要包含内核线程所需的基本字段，而实际 OS 中的 PCB 更复杂，包含更多资源管理信息（文件描述符、信号处理、资源限制等）

-   **实验知识点：上下文切换（context）与中断帧（trapframe）**

    -   OS 原理对应点：进程调度与 CPU 上下文保存/恢复
    -   含义：context 保存 callee-saved 寄存器用于进程切换，trapframe 保存完整的处理器状态用于中断处理
    -   关系与差异：实验清晰区分了两种不同场景的状态保存，体现了 RISC-V 架构的特点，比 x86 的统一上下文处理更加精细化

-   **实验知识点：进程创建（do_fork）**

    -   OS 原理对应点：进程创建与资源分配
    -   含义：通过复制父进程的资源和设置子进程的执行环境来创建新进程
    -   关系与差异：实验简化了内存管理部分（copy_mm 为空），主要关注内核线程创建，而真实系统需要处理复杂的地址空间复制、文件描述符继承等

-   **实验知识点：PID 分配算法（get_pid）**

    -   OS 原理对应点：系统资源分配与管理
    -   含义：使用安全区间优化的循环分配算法，保证 PID 唯一性
    -   关系与差异：实验实现了一个高效的 PID 分配算法，实际系统中可能使用更复杂的算法（如位图、哈希表等）来处理更大规模的进程管理

-   **实验知识点：多级页表（get_pte）**

    -   OS 原理对应点：虚拟内存管理与地址转换
    -   含义：通过多级页表实现虚拟地址到物理地址的转换，支持大地址空间的高效管理
    -   关系与差异：实验实现了 sv39 的三级页表，体现了 RISC-V 的分页机制，与 x86 的四级页表在结构上相似但在具体实现细节上有差异

-   **实验知识点：中断控制与临界区保护**
    -   OS 原理对应点：并发控制与同步机制
    -   含义：通过禁用中断来保护临界区，确保原子操作
    -   关系与差异：实验使用了基本的中断禁用机制，实际系统中还需要考虑多 CPU 环境下的锁机制、优先级继承等更复杂的同步原语

**2) OS 原理中重要但本实验未覆盖的知识点：**

-   **用户进程与系统调用**：本实验只实现了内核线程，未涉及用户态进程的创建和系统调用机制，将在后续实验中实现

-   **进程间通信（IPC）**：如管道、信号、共享内存、消息队列等，本实验未涉及，属于进程协作的高级主题

-   **内存管理的高级特性**：如需求分页、页面置换算法、内存压缩等，本实验的内存管理较为简单

-   **文件系统与 I/O 管理**：进程与文件系统的交互、设备驱动管理等，将在后续实验中涉及

-   **死锁处理与资源分配算法**：银行家算法、死锁检测与恢复等，本实验的资源管理相对简单

-   **实时调度与多级反馈队列**：本实验使用简单的轮转调度，未实现复杂的调度算法

这些知识点将在后续的 lab5（用户进程）、lab6（调度算法）、lab7（同步机制）、lab8（文件系统）等实验中逐步实现和学习。

---

## 验证与运行（如何复现实验）

在仓库根目录下运行：

```bash
make qemu
```

或按实验提供的 Makefile 指引编译并在 qemu 中运行。请在此处填写你实际的编译与运行结果，包括串口输出或关键日志摘录。

---

## 总结与心得

在此简要总结你完成本次实验的收获、遇到的难点、以及下一步打算。

---

## 常见问题与调试提示

-   若出现链接或重定位错误，请检查 `kernel.ld` 与段定义是否一致。
-   若新进程无法运行，检查：是否正确设置 `context` 中的返回地址 `ra`、堆栈指针 `sp`、以及 `trapframe` 中的返回值寄存器。

---

## 附录：参考代码片段与关键函数位置

-   `alloc_proc`：`lab4/kern/process/proc.c`
-   `do_fork`：`lab4/kern/process/proc.c`
-   `proc_run`：`lab4/kern/process/sched.c` 或 `proc.c`（视实现而定）
-   `get_pte`：`lab4/kern/mm/pmm.c`

请按需在附录中粘贴你自己的关键代码实现以备查阅。
