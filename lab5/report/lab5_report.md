# Lab5 实验报告 - 用户进程管理

## 练习 0：填写已有实验

已将 lab2/3/4 的代码正确填入 lab5 相应位置。

---

## 练习 1：加载应用程序并执行（由同学完成）

_此部分由队友完成 load_icode 的第 6 步实现。_

---

## 练习 2：父进程复制自己的内存空间给子进程（由同学完成）

_此部分由队友完成 copy_range 的实现。_

---

## 练习 3：分析 fork/exec/wait/exit 的实现


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

---

## 重要知识点总结

### 实验中的重要知识点

1. **进程控制块 (PCB)**: `proc_struct` 结构包含进程状态、内存管理、调度信息等
2. **系统调用机制**: 用户态通过 ecall 陷入内核，内核处理后通过 sret 返回
3. **进程状态机**: UNINIT → RUNNABLE ↔ RUNNING ↔ SLEEPING → ZOMBIE
4. **COW 机制**: 延迟复制优化，使用页表标志位和缺页中断实现
5. **同步与互斥**: 使用中断禁用保护临界区

### 与 OS 原理对应的知识点

| 实验概念        | OS 原理      | 关系说明                |
| --------------- | ------------ | ----------------------- |
| do_fork         | 进程创建     | fork 系统调用的具体实现 |
| do_wait/do_exit | 进程同步     | 父子进程间的等待与通知  |
| COW             | 内存管理优化 | 延迟复制减少开销        |
| schedule        | 进程调度     | 选择下一个运行进程      |
| trapframe       | 上下文切换   | 保存/恢复 CPU 状态      |

### 实验特有的知识点

1. **ELF 加载**: load_icode 解析 ELF 格式
2. **RISC-V 特定**: ecall/sret、页表格式（SV39）
3. **uCore 设计**: 进程链表管理、内核栈布局

---

## 测试结果

```
make grade
...
Total Score: 130/130
```

所有测试用例通过，包括 forktest（COW 机制正确工作）。
