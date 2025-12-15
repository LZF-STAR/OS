# Lab5 实验报告

## 练习0：填写已有实验

本实验依赖实验1/2/3/4。需要把做的实验里的代码填入本实验中代码中有"LAB1"/"LAB2"/"LAB3"/"LAB4"的注释相应部分。并确保编译通过。

## 练习1：加载应用程序并执行（需要编码）

### 实验目的
实现用户进程的加载和执行，具体是完成`load_icode`函数的第6步，设置正确的trapframe内容，确保用户进程能够正确执行。

### 设计实现过程

#### 1. trapframe的作用
trapframe保存了进程在用户态和内核态切换时的寄存器状态。当从内核态返回用户态时，会从trapframe中恢复寄存器状态，从而让进程从指定的位置开始执行。

#### 2. 需要设置的trapframe字段

在`load_icode`函数的第6步，我们需要设置以下trapframe字段：

```c
// (6) setup trapframe for user environment
struct trapframe *tf = current->tf;
// Keep sstatus
uintptr_t sstatus = tf->status;
memset(tf, 0, sizeof(struct trapframe));

tf->gpr.sp = USTACKTOP;           // 设置用户栈指针
tf->epc = elf->e_entry;           // 设置程序入口点
tf->status = sstatus & ~SSTATUS_SPP;  // 清除SPP位，表示返回用户态
tf->status |= SSTATUS_SPIE;       // 设置SPIE位，使能中断
```

#### 3. 各字段的含义

- **tf->gpr.sp**：用户栈顶指针，设置为`USTACKTOP`（用户栈的最高地址）
- **tf->epc**：程序计数器，设置为ELF文件的入口地址`elf->e_entry`，这是应用程序的第一条指令地址
- **tf->status**：处理器状态寄存器
  - `SSTATUS_SPP`：Supervisor Previous Privilege，如果为1表示之前在S模式，为0表示之前在U模式。我们要返回用户态，所以清除这一位
  - `SSTATUS_SPIE`：Supervisor Previous Interrupt Enable，设置为1表示返回用户态后使能中断

### 用户态进程执行的整个过程

用户态进程从被选中执行到开始执行应用程序第一条指令的完整过程如下：

#### 1. 进程创建和加载阶段
1. 通过`kernel_thread`创建用户进程的内核线程
2. 内核线程调用`do_execve`函数
3. `do_execve`调用`load_icode`加载ELF格式的应用程序
4. `load_icode`完成以下工作：
   - 创建新的内存管理结构mm
   - 解析ELF文件，建立用户虚拟地址空间
   - 加载程序的各个段（代码段、数据段等）到内存
   - 分配并设置用户栈
   - **设置trapframe**，准备从内核态切换到用户态的环境

#### 2. 调度执行阶段
1. 调度器`schedule()`选中该进程，进程状态变为RUNNING
2. 调用`proc_run()`切换到该进程：
   - 设置当前进程指针`current`
   - 加载进程的页目录表（通过`lsatp`切换页表）
   - 调用`switch_to`切换上下文

#### 3. 返回用户态阶段
1. 内核线程执行完成后，会触发一个特殊的断点异常（CAUSE_BREAKPOINT）
2. 在`exception_handler`中处理断点异常，调用`kernel_execve_ret`
3. `kernel_execve_ret`从trapframe中恢复寄存器状态：
   - 从`tf->epc`恢复程序计数器（指向应用程序入口）
   - 从`tf->gpr.sp`恢复栈指针
   - 从`tf->status`恢复处理器状态（SPP=0表示用户态，SPIE=1使能中断）
4. 执行`sret`指令返回用户态
5. CPU开始从`tf->epc`指向的地址执行应用程序的第一条指令

#### 4. 关键寄存器的作用
- **sepc**（Supervisor Exception Program Counter）：保存返回地址，即用户程序的入口地址
- **sstatus**：处理器状态，控制特权级别和中断使能
- **sp**：栈指针，用户程序使用的栈

整个过程实现了从内核态到用户态的特权级切换，让用户程序能够在用户空间安全地执行。

---

## 练习2：父进程复制自己的内存空间给子进程（需要编码）

### 实验目的
实现`copy_range`函数，完成父进程内存空间到子进程的拷贝，使得`fork`系统调用能够正确创建子进程。

### 设计实现过程

#### 1. copy_range函数的作用
`copy_range`函数将父进程（进程A）的某段虚拟内存区域[start, end)的内容复制到子进程（进程B）中。这是实现`fork`系统调用的核心功能之一。

#### 2. 实现步骤

在`kern/mm/pmm.c`的`copy_range`函数中，我们需要完成以下工作：

```c
// (1) find src_kvaddr: the kernel virtual address of page
void *src_kvaddr = page2kva(page);

// (2) find dst_kvaddr: the kernel virtual address of npage
void *dst_kvaddr = page2kva(npage);

// (3) memory copy from src_kvaddr to dst_kvaddr, size is PGSIZE
memcpy(dst_kvaddr, src_kvaddr, PGSIZE);

// (4) build the map of phy addr of npage with the linear addr start
ret = page_insert(to, npage, start, perm);
```

#### 3. 各步骤详解

**步骤1：获取源页面的内核虚拟地址**
- `page2kva(page)`：将父进程的物理页面转换为内核虚拟地址
- 这样我们就可以在内核中访问父进程的页面内容

**步骤2：获取目标页面的内核虚拟地址**
- `page2kva(npage)`：将新分配给子进程的物理页面转换为内核虚拟地址
- 这是复制的目标地址

**步骤3：内存拷贝**
- `memcpy(dst_kvaddr, src_kvaddr, PGSIZE)`：将父进程页面的全部内容（PGSIZE字节）复制到子进程的新页面
- 这是实际的数据复制操作

**步骤4：建立虚拟地址到物理地址的映射**
- `page_insert(to, npage, start, perm)`：
  - `to`：子进程的页目录表
  - `npage`：新分配的物理页面
  - `start`：虚拟地址
  - `perm`：页面权限（从父进程继承）
- 这一步在子进程的页表中建立映射，使得子进程能够通过相同的虚拟地址访问复制的内容

#### 4. 整体流程

`copy_range`函数在一个循环中按页面逐一复制：

1. 通过`get_pte`找到父进程的页表项
2. 为子进程分配新的物理页面
3. 复制页面内容
4. 在子进程的页表中建立映射
5. 继续处理下一个页面，直到复制完整个内存区域

#### 5. 调用关系

```
do_fork()
  └─> copy_mm()
       └─> dup_mmap()
            └─> copy_range()  // 按页面复制内存内容
```

### 实现的意义

通过`copy_range`函数，我们实现了"写时复制"（Copy-on-Write）之前的朴素复制方法。fork创建的子进程拥有和父进程完全相同的内存内容，但是存储在不同的物理页面中，因此父子进程的修改互不影响。这保证了进程的独立性和隔离性。

---

## 练习3：阅读分析fork/exec/wait/exit函数的实现

### 3.1 fork 函数执行流程

#### 用户态部分

```c
// user/libs/ulib.c
int fork(void) {
    return sys_fork();  // 调用系统调用包装函数
}

// user/libs/syscall.c
int sys_fork(void) {
    return syscall(SYS_fork);  // 通过 ecall 触发系统调用
}
```

#### 内核态部分

```
__alltraps -> trap() -> exception_handler() -> syscall() -> sys_fork() -> do_fork()
```

**do_fork 核心流程：**

1. **alloc_proc()** - 分配并初始化进程控制块
2. **setup_kstack()** - 分配内核栈（2 页）
3. **copy_mm()** - 复制内存管理结构
    - 在 COW 模式下，调用 `dup_mmap()` -> `copy_range()` 共享物理页面
4. **copy_thread()** - 复制线程上下文（trapframe 和 context）
5. **hash_proc() + set_links()** - 将进程加入管理结构
6. **wakeup_proc()** - 设置进程为 RUNNABLE 状态

#### 返回值传递

-   子进程：trapframe->gpr.a0 = 0（子进程返回 0）
-   父进程：返回子进程的 pid

---

### 3.2 exec 函数执行流程

#### 用户态部分

```c
int execve(const char *name, const char **argv, const char **envp);
```

#### 内核态部分

```
trap -> syscall() -> sys_exec() -> do_execve()
```

**do_execve 核心流程：**

1. 清理旧的用户内存空间（mm）
2. 调用 `load_icode()` 加载新程序：
    - 创建新的 mm 结构
    - 解析 ELF 文件头
    - 为代码段、数据段创建 VMA
    - 分配物理页面并复制程序内容
    - 设置用户栈
    - 设置页目录
3. 设置 trapframe 使进程返回时从新程序入口开始执行

---

### 3.3 wait 函数执行流程

#### 用户态部分

```c
int wait(void) {
    return sys_wait(0, NULL);  // 等待任意子进程
}
```

#### 内核态部分

```
trap -> syscall() -> sys_wait() -> do_wait()
```

**do_wait 核心流程：**

1. 遍历子进程链表，查找 ZOMBIE 状态的子进程
2. 如果找到 ZOMBIE 子进程：
    - 获取退出码
    - 调用 `unhash_proc()` 和 `remove_links()` 移除进程
    - 释放内核栈和 proc 结构
3. 如果没有 ZOMBIE 子进程：
    - 设置当前进程为 SLEEPING 状态
    - 设置 `wait_state = WT_CHILD`
    - 调用 `schedule()` 让出 CPU
4. 被唤醒后重新检查

**竞态条件修复：**
我们发现原始代码存在竞态条件，将检查子进程状态和设置睡眠态放入了同一个临界区：

```c
local_intr_save(intr_flag);
{
    // 检查子进程状态
    // 如果没有 ZOMBIE，设置 SLEEPING
    current->state = PROC_SLEEPING;
    current->wait_state = WT_CHILD;
}
local_intr_restore(intr_flag);
schedule();
```

---

### 3.4 exit 函数执行流程

#### 用户态部分

```c
void exit(int error_code) {
    sys_exit(error_code);
    // 永不返回
}
```

#### 内核态部分

```
trap -> syscall() -> sys_exit() -> do_exit()
```

**do_exit 核心流程：**

1. **释放内存空间**：
    - 切换到内核页表
    - 减少 mm 引用计数，如果为 0 则释放所有资源
2. **设置僵尸状态**：
    - `state = PROC_ZOMBIE`
    - 保存退出码
3. **唤醒父进程**：
    - 检查父进程是否在 wait
    - 如果是，调用 `wakeup_proc()` 唤醒
4. **处理子进程（托孤）**：
    - 将所有子进程转移给 init 进程
5. **调度**：
    - 调用 `schedule()` 切换到其他进程

**竞态条件修复：**
我们发现设置 ZOMBIE 状态和唤醒父进程之间存在竞态条件，将它们放入同一个临界区：

```c
local_intr_save(intr_flag);
{
    current->state = PROC_ZOMBIE;
    current->exit_code = error_code;

    if (parent->wait_state == WT_CHILD) {
        wakeup_proc(parent);
    }
    // 托孤处理...
}
local_intr_restore(intr_flag);
schedule();
```

---

### 3.5 用户态与内核态交互分析

| 阶段         | 位置   | 说明                            |
| ------------ | ------ | ------------------------------- |
| 系统调用发起 | 用户态 | 通过 ecall 指令触发             |
| 陷入处理     | 内核态 | trapentry.S 保存上下文          |
| 系统调用分发 | 内核态 | syscall.c 根据调用号分发        |
| 具体实现     | 内核态 | do_fork/do_exec/do_wait/do_exit |
| 返回准备     | 内核态 | 设置 trapframe->gpr.a0 为返回值 |
| 返回用户态   | 用户态 | sret 指令恢复上下文             |

---

### 3.6 进程状态生命周期图

```
                        ┌─────────────┐
                        │  PROC_UNINIT │
                        │   (初始态)   │
                        └──────┬──────┘
                               │ alloc_proc()
                               ▼
                        ┌─────────────┐
              ┌────────►│PROC_RUNNABLE│◄───────────────────┐
              │         │  (就绪态)    │                    │
              │         └──────┬──────┘                    │
              │                │ schedule()                │
              │                │ 被调度执行                │
              │                ▼                           │
              │         ┌─────────────┐                    │
              │         │ PROC_RUNNING │                   │
              │         │  (运行态)    │                   │
              │         └──────┬──────┘                    │
              │                │                           │
              │    ┌───────────┼───────────┐               │
              │    │           │           │               │
              │    ▼           ▼           ▼               │
              │ 时间片用完  do_wait()   do_exit()          │
              │    │           │           │               │
              │    │           ▼           ▼               │
              │    │    ┌─────────────┐  ┌─────────────┐   │
              │    │    │PROC_SLEEPING│  │ PROC_ZOMBIE │   │
              │    │    │  (睡眠态)   │  │  (僵尸态)   │   │
              │    │    └──────┬──────┘  └──────┬──────┘   │
              │    │           │                │          │
              │    │           │ wakeup_proc()  │ 父进程   │
              │    │           │ (被子进程唤醒)  │ do_wait() │
              │    │           │                │ 回收资源  │
              │    │           │                ▼          │
              └────┴───────────┘         ┌─────────────┐   │
                                         │   释放资源   │   │
                                         │   进程消亡   │   │
                                         └─────────────┘   │
                                                           │
                    fork创建子进程 ─────────────────────────┘
```

**状态转换事件：**

-   `UNINIT → RUNNABLE`: `alloc_proc()` + `wakeup_proc()`
-   `RUNNABLE → RUNNING`: `schedule()` 选中该进程
-   `RUNNING → RUNNABLE`: 时间片用完或主动 yield
-   `RUNNING → SLEEPING`: `do_wait()` 等待子进程
-   `SLEEPING → RUNNABLE`: 子进程 `do_exit()` 时调用 `wakeup_proc()`
-   `RUNNING → ZOMBIE`: `do_exit()` 进程退出
-   `ZOMBIE → 消亡`: 父进程 `do_wait()` 回收资源

---
## 扩展练习 Challenge：实现 Copy on Write (COW) 机制

### 设计概述

COW 机制允许父子进程在 fork 时共享物理页面，只有当某个进程尝试写入时才进行实际的页面复制。

### 实现方案

#### 1. 定义 COW 标志位

在 `kern/mm/mmu.h` 中定义 PTE_COW 标志：

```c
#define PTE_COW   0x100  // bit 8: Copy-on-Write 标志
```

#### 2. copy_range 修改（fork 时设置 COW）

```c
int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share)
{
    // ...
    // 获取源页表项
    pte_t *ptep = get_pte(from, start, 0);

    // 获取物理页面
    struct Page *page = pte2page(*ptep);

    // 增加页面引用计数（父子共享）
    page_ref_inc(page);

    // 设置目标页表项：共享物理页、只读、带 COW 标志
    uintptr_t pa = page2pa(page);
    page_insert(to, page, start, PTE_U | PTE_COW);  // 子进程：只读+COW

    // 修改源页表项：也变成只读+COW
    *ptep = (*ptep & ~PTE_W) | PTE_COW;
    // ...
}
```

#### 3. do_pgfault 处理 COW 缺页

```c
int do_pgfault(struct mm_struct *mm, uint32_t error_code, uintptr_t addr)
{
    // ...
    // 检查是否是 COW 页面的写操作
    if ((*ptep & PTE_COW) && (error_code & 0x2))  // 写操作
    {
        struct Page *page = pte2page(*ptep);

        local_intr_save(intr_flag);  // 保护引用计数检查
        {
            int ref = page_ref(page);
            if (ref > 1)
            {
                // 多个进程共享，需要复制
                struct Page *new_page = alloc_page();
                memcpy(page2kva(new_page), page2kva(page), PGSIZE);
                page_ref_dec(page);  // 减少旧页面引用
                page_insert(mm->pgdir, new_page, addr, PTE_W | PTE_U);
            }
            else
            {
                // 只有一个进程使用，直接取消 COW 标志
                *ptep = (*ptep & ~PTE_COW) | PTE_W;
                tlb_invalidate(mm->pgdir, addr);
            }
        }
        local_intr_restore(intr_flag);

        return 0;
    }
    // ...
}
```

### 状态转换图

```
┌─────────────────────────────────────────────────────────────────┐
│                      COW 页面状态机                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐         fork()          ┌─────────────┐      │
│   │   正常页面   │ ────────────────────► │  COW 页面   │      │
│   │  (可读可写)  │   设置只读+PTE_COW     │   (只读)    │      │
│   │  ref = 1    │                        │  ref > 1    │      │
│   └─────────────┘                        └──────┬──────┘      │
│         ▲                                       │              │
│         │                                       │ 写操作触发   │
│         │                                       │ page fault   │
│         │                                       ▼              │
│         │                           ┌────────────────────┐     │
│         │                           │  检查引用计数 ref  │     │
│         │                           └─────────┬──────────┘     │
│         │                                     │                │
│         │              ┌──────────────────────┴───────┐        │
│         │              │                              │        │
│         │         ref > 1                         ref = 1      │
│         │              │                              │        │
│         │              ▼                              ▼        │
│         │    ┌─────────────────┐          ┌─────────────────┐  │
│         │    │   分配新页面     │          │ 清除 COW 标志   │  │
│         │    │   复制内容      │          │ 设置可写权限    │  │
│         │    │   减少旧ref     │          │                 │  │
│         │    │   映射新页面     │          │                 │  │
│         │    └────────┬────────┘          └────────┬────────┘  │
│         │             │                            │           │
│         └─────────────┴────────────────────────────┘           │
│                    进程获得独立可写页面                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 竞态条件修复

在调试过程中，我们发现了两个导致 forktest 不稳定的竞态条件：

#### 问题 1：do_wait 中的竞态条件

**原问题**：检查子进程状态和设置父进程睡眠态不是原子操作

```c
// 原代码（有问题）
for (proc = cptr; proc != NULL; proc = proc->optr)
    if (proc->state == PROC_ZOMBIE) goto found;

// 在此处可能被中断，子进程完成 exit 并尝试唤醒父进程
// 但父进程还没设置 SLEEPING，所以不会被唤醒

current->state = PROC_SLEEPING;  // 太晚了！
```

**修复**：将整个检查-设置过程放入临界区

```c
local_intr_save(intr_flag);
{
    for (proc = cptr; proc != NULL; proc = proc->optr)
        if (proc->state == PROC_ZOMBIE) {
            local_intr_restore(intr_flag);
            goto found;
        }
    current->state = PROC_SLEEPING;
    current->wait_state = WT_CHILD;
}
local_intr_restore(intr_flag);
schedule();
```

#### 问题 2：do_exit 中的竞态条件

**原问题**：设置 ZOMBIE 状态在临界区外

```c
// 原代码（有问题）
current->state = PROC_ZOMBIE;  // 先设置 ZOMBIE

// 可能被中断，父进程运行并检查到 ZOMBIE，但还没设置 SLEEPING

local_intr_save(intr_flag);
if (parent->wait_state == WT_CHILD)  // 检查时父进程还没睡眠
    wakeup_proc(parent);             // 不唤醒
```

**修复**：将设置 ZOMBIE 也放入临界区

```c
local_intr_save(intr_flag);
{
    current->state = PROC_ZOMBIE;
    current->exit_code = error_code;

    if (parent->wait_state == WT_CHILD)
        wakeup_proc(parent);
    // ...
}
local_intr_restore(intr_flag);
```

### Dirty COW 漏洞分析

Dirty COW (CVE-2016-5013) 是 Linux 内核中的一个著名漏洞，允许本地用户提权。

**漏洞原理**：

1. 攻击者打开一个只读文件（如 /etc/passwd）
2. 使用 mmap 以私有方式映射
3. 在另一个线程中调用 madvise(MADV_DONTNEED) 丢弃页面
4. 同时尝试写入映射区域

**竞态条件**：

```
Thread 1: write() → COW 处理中 → 分配新页面 → 准备复制...
Thread 2: madvise(MADV_DONTNEED) → 丢弃页面映射
Thread 1: ...继续写入 → 写入了原始文件页面！
```

**uCore 中的防护**：
我们的 COW 实现使用 `local_intr_save/restore` 保护引用计数检查和页面复制过程，避免类似的竞态条件：

```c
local_intr_save(intr_flag);
{
    int ref = page_ref(page);
    if (ref > 1) {
        // 复制页面（受保护）
    }
}
local_intr_restore(intr_flag);
```

这确保了在检查引用计数和实际复制之间不会发生中断。



## 一些问题：

### 问题发现
在进行make grade测试时，发现spin测试用例失败。该测试用例中，父进程fork一个子进程，子进程在用户态死循环（while(1)），父进程在yield三次后调用kill终止子进程。

### 问题分析

#### 原始问题
1. 父进程调用`kill(pid)`将子进程标记为`PF_EXITING`
2. 子进程在用户态死循环，需要trap到内核态才能检查`PF_EXITING`标志
3. 在`trap.c`的`trap`函数中，返回用户态前会检查该标志并调用`do_exit`
4. **关键问题**：时钟中断发生后，没有设置`current->need_resched = 1`
5. 导致子进程一直在死循环中运行，父进程永远无法被调度

#### 解决方案

在时钟中断处理(IRQ_S_TIMER分支)中添加调度标记：

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;
    if (ticks % TICK_NUM == 0) {
        static int num = 0;
        print_ticks();
        num++;
        if (num == 10) {
            sbi_shutdown();
        }
    }
    // Set need_resched only when interrupt from user mode
    if (current && !trap_in_kernel(tf)) {
        current->need_resched = 1;
    }
    break;
```

### 实现要点

#### 1. 只在用户态中断时设置need_resched
- 检查`!trap_in_kernel(tf)`确保只在用户态发生时钟中断时设置标志
- 避免在内核态处理关键操作时被频繁标记为需要调度
- 保证了内核操作的原子性

#### 2. 时间片轮转的实现
- 每次用户态时钟中断（约10ms，100Hz）都会设置`need_resched`
- 在trap返回前检查该标志，如果为true则调用`schedule()`
- 实现了简单的时间片轮转调度算法

#### 3. 进程退出的流程
1. 子进程在用户态死循环
2. 父进程调用kill设置子进程的`PF_EXITING`标志
3. 时钟中断发生，子进程trap到内核态
4. 设置`need_resched`（因为是从用户态trap）
5. trap返回前检查`PF_EXITING`，调用`do_exit`
6. 子进程进入ZOMBIE状态，唤醒父进程
7. 父进程的waitpid返回，回收子进程资源

### 测试结果
修复后spin测试通过，所有测试用例得分：130/130

### 总结
通过在时钟中断处理中合理地设置`need_resched`标志，实现了时间片轮转调度，确保了：
1. 用户态进程能够被公平调度
2. 被kill的进程能够及时退出
3. 内核态操作不被中断
4. 所有进程都有机会运行

这是实现抢占式调度的基础，为后续实现更复杂的调度算法奠定了基础。
