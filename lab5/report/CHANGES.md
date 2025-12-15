# Lab5 代码修改记录

本文档记录了我对 lab5 代码的所有修改。所有修改都是**增量修改**，保留了原有的 `LAB EXERCISE YOUR CODE` 注释。

## 修改概述

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| [kern/process/proc.c](kern/process/proc.c) | **关键修复** | 修复 do_wait/do_exit 竞态条件 |
| [kern/mm/vmm.c](kern/mm/vmm.c) | COW实现 | 添加 COW 页错误处理 |
| [kern/mm/pmm.c](kern/mm/pmm.c) | COW实现 | copy_range 实现 COW 共享 |
| [kern/mm/mmu.h](kern/mm/mmu.h) | COW实现 | 添加 PTE_COW 标志定义 |
| [kern/trap/trap.c](kern/trap/trap.c) | 调度修复 | 定时器中断设置 need_resched |
| [kern/syscall/syscall.c](kern/syscall/syscall.c) | 系统调用 | 添加注释 |

---

## 详细修改

### 1. kern/process/proc.c - 竞态条件修复

#### 1.1 do_exit 修复 (约第558行)

**问题**: 设置 `PROC_ZOMBIE` 状态和唤醒父进程不在同一个临界区，可能导致父进程永远等待。

**修复**: 将 `current->state = PROC_ZOMBIE` 移入 `local_intr_save` 临界区内。

```c
// 【修改前】
current->state = PROC_ZOMBIE;
current->exit_code = error_code;
local_intr_save(intr_flag);
{
    // 唤醒父进程...
}

// 【修改后】
local_intr_save(intr_flag);
{
    current->state = PROC_ZOMBIE;      // 移入临界区
    current->exit_code = error_code;   // 移入临界区
    // 唤醒父进程...
}
```

#### 1.2 do_wait 修复 (约第903行)

**问题**: 检查子进程状态和设置父进程睡眠态不是原子操作。

**修复**: 将整个检查-设置过程放入 `local_intr_save` 临界区。

```c
// 【修改前】
if (pid != 0) {
    // 检查子进程...
} else {
    // 遍历子进程...
}
if (haskid) {
    current->state = PROC_SLEEPING;  // 设置睡眠
    current->wait_state = WT_CHILD;
    schedule();
}

// 【修改后】
local_intr_save(intr_flag);
{
    if (pid != 0) {
        // 检查子进程...
    } else {
        // 遍历子进程...
    }
    if (haskid) {
        current->state = PROC_SLEEPING;  // 在临界区内设置
        current->wait_state = WT_CHILD;
    }
}
local_intr_restore(intr_flag);
if (haskid) {
    schedule();
    // ...
}
```

---

### 2. kern/mm/vmm.c - COW 页错误处理

#### 2.1 添加 COW 处理 (do_pgfault 函数，约第400-450行)

在 `do_pgfault` 中添加对 COW 页面写操作的处理：

```c
// 检测到 COW 页面的写操作
if ((*ptep & PTE_COW) && (error_code & 0x2)) {
    struct Page *page = pte2page(*ptep);
    
    // 使用中断保护检查引用计数
    local_intr_save(intr_flag);
    {
        int ref = page_ref(page);
        if (ref > 1) {
            // 多进程共享，需要复制
            struct Page *new_page = alloc_page();
            memcpy(page2kva(new_page), page2kva(page), PGSIZE);
            page_ref_dec(page);
            page_insert(mm->pgdir, new_page, addr, PTE_W | PTE_U);
        } else {
            // 只有一个进程，直接取消 COW
            *ptep = (*ptep & ~PTE_COW) | PTE_W;
            tlb_invalidate(mm->pgdir, addr);
        }
    }
    local_intr_restore(intr_flag);
    return 0;
}
```

---

### 3. kern/mm/pmm.c - COW copy_range 实现

#### 3.1 copy_range 修改 (约第387-433行)

将原来的页面复制改为 COW 共享：

```c
// 【原来】分配新页面并复制内容
struct Page *page = alloc_page();
memcpy(page2kva(page), page2kva(pte2page(*ptep)), PGSIZE);
page_insert(to, page, start, perm);

// 【改为】共享页面，设置 COW 标志
struct Page *page = pte2page(*ptep);
page_ref_inc(page);                              // 增加引用计数
page_insert(to, page, start, PTE_U | PTE_COW);   // 子进程只读+COW
*ptep = (*ptep & ~PTE_W) | PTE_COW;              // 父进程也只读+COW
tlb_invalidate(from, start);
```

---

### 4. kern/mm/mmu.h - COW 标志定义

#### 4.1 添加 PTE_COW 定义 (约第50行后)

```c
#define PTE_COW   0x100  // bit 8: Copy-on-Write 标志
```

---

### 5. kern/trap/trap.c - 定时器中断修复

#### 5.1 trap_dispatch 修改 (IRQ_S_TIMER 分支)

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;
    if (ticks % TICK_NUM == 0) {
        // assert(googleplex is handsome);
        print_ticks();
    }
    run_timer_list();
    current->need_resched = 1;  // 【添加】触发调度
    break;
```

---

### 6. kern/syscall/syscall.c - 添加注释

主要添加了系统调用的中文注释，无功能性修改。

---

## 竞态条件分析

### 问题场景 (修复前)

```
时间 ->

父进程(do_wait):     检查子进程状态 ... [中断] ... 设置SLEEPING
子进程(do_exit):              设置ZOMBIE ... 检查parent->wait_state ... 不唤醒!
                                              (此时父进程还没设置SLEEPING)
结果: 父进程永远等待，子进程变成僵尸
```

### 修复后

```
时间 ->

父进程(do_wait):     [关中断] 检查子进程 + 设置SLEEPING [开中断] schedule()
子进程(do_exit):              [关中断] 设置ZOMBIE + 唤醒父进程 [开中断] schedule()

无论谁先执行:
- 父进程先: 设置SLEEPING后被唤醒
- 子进程先: 父进程检查时就发现ZOMBIE，直接回收
```

---

## 验证结果

```
make grade
Total Score: 130/130
```

forktest 从之前的 11.8 秒超时变为 1.1 秒完成。
