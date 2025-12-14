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

（待补充）

---

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
