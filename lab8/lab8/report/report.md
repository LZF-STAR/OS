# Lab8 文件系统 实验报告

## 练习 0：填写已有实验

本实验依赖实验 2/3/4/5/6/7。需要把之前实验里的代码填入本实验中代码中有"LAB2"/"LAB3"/"LAB4"/"LAB5"/"LAB6"/"LAB7"的注释相应部分，并确保编译通过。

主要涉及的代码包括：

-   **LAB2**：物理内存管理相关代码
-   **LAB3**：中断处理相关代码
-   **LAB4**：进程管理、`alloc_proc`函数中进程控制块的初始化
-   **LAB5**：用户进程加载、`load_icode`函数
-   **LAB6**：进程调度相关代码
-   **LAB7**：同步互斥相关代码

在 Lab8 中还需要额外初始化`filesp`字段：

```c
// lab8 add:
proc->filesp = NULL;
```

---

## 练习 1：完成读文件操作的实现（需要编码）

### 实验目的

实现`sfs_io_nolock`函数，完成对文件的读写操作。该函数负责将文件内容从磁盘块读取到内存缓冲区，或将内存缓冲区内容写入磁盘块。

### 设计实现过程

#### 1. 函数原型与参数说明

```c
static int
sfs_io_nolock(struct sfs_fs *sfs, struct sfs_inode *sin, void *buf,
              off_t offset, size_t *alenp, bool write)
```

参数说明：

-   `sfs`：SFS 文件系统结构
-   `sin`：文件对应的内存 inode
-   `buf`：读写数据的缓冲区
-   `offset`：文件内的偏移量
-   `alenp`：需要读写的长度（输入），实际读写的长度（输出）
-   `write`：false 表示读操作，true 表示写操作

#### 2. 实现思路

文件在磁盘上是按块存储的，每个块大小为`SFS_BLKSIZE`（4096 字节）。读写操作需要处理三种情况：

1. **首块不对齐**：如果起始位置不是块的开头，需要特殊处理
2. **中间对齐块**：可以直接按整块读写
3. **尾块不对齐**：如果结束位置不是块的末尾，需要特殊处理

#### 3. 核心代码实现

```c
int ret = 0;
size_t size, alen = 0;
uint32_t ino;
uint32_t blkno = offset / SFS_BLKSIZE;          // 起始块号
uint32_t nblks = endpos / SFS_BLKSIZE - blkno;  // 需要读写的块数

// (1) 处理首块（如果偏移不对齐）
if ((blkoff = offset % SFS_BLKSIZE) != 0) {
    size = (nblks != 0) ? (SFS_BLKSIZE - blkoff) : (endpos - offset);
    if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
        goto out;
    }
    if ((ret = sfs_buf_op(sfs, buf, size, ino, blkoff)) != 0) {
        goto out;
    }
    alen += size;
    buf += size;
    if (nblks == 0) {
        goto out;
    }
    blkno++;
    nblks--;
}

// (2) 处理中间对齐块
while (nblks > 0) {
    if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
        goto out;
    }
    if ((ret = sfs_block_op(sfs, buf, ino, 1)) != 0) {
        goto out;
    }
    alen += SFS_BLKSIZE;
    buf += SFS_BLKSIZE;
    blkno++;
    nblks--;
}

// (3) 处理尾块（如果结束位置不对齐）
if ((size = endpos % SFS_BLKSIZE) != 0) {
    if ((ret = sfs_bmap_load_nolock(sfs, sin, blkno, &ino)) != 0) {
        goto out;
    }
    if ((ret = sfs_buf_op(sfs, buf, size, ino, 0)) != 0) {
        goto out;
    }
    alen += size;
}
```

#### 4. 关键函数说明

-   **`sfs_bmap_load_nolock`**：根据文件内的块号，获取对应的磁盘块号
-   **`sfs_buf_op`**：读写部分块（用于首块和尾块不对齐的情况）
-   **`sfs_block_op`**：读写整块（用于中间对齐块）

#### 5. 注意事项

在初始代码中存在一个 bug：步骤 1-3 被重复执行了两遍，导致读取的数据量翻倍，触发`iob->io_resid >= n`断言失败。修复方法是删除重复的代码块。

---

## 练习 2：完成基于文件系统的执行程序机制的实现（需要编码）

### 实验目的

改写`proc.c`中的`load_icode`函数和相关函数，实现基于文件系统的执行程序机制，使得用户程序能够从文件系统加载并执行。

### 设计实现过程

#### 1. 与 Lab5 的区别

Lab5 中，用户程序是通过内存中的二进制数据加载的。Lab8 中需要从文件系统读取程序文件，主要变化：

| Lab5               | Lab8                 |
| ------------------ | -------------------- |
| 从内存地址读取 ELF | 从文件描述符读取 ELF |
| 直接 memcpy        | 使用 load_icode_read |

#### 2. load_icode_read 辅助函数

```c
static int
load_icode_read(int fd, void *buf, size_t len, off_t offset) {
    int ret;
    if ((ret = sysfile_seek(fd, offset, LSEEK_SET)) != 0) {
        return ret;
    }
    if ((ret = sysfile_read(fd, buf, len)) != len) {
        return (ret < 0) ? ret : -1;
    }
    return 0;
}
```

#### 3. load_icode 函数实现

```c
static int
load_icode(int fd, int argc, char **kargv) {
    // (1) 创建新的mm结构
    if (current->mm != NULL) {
        panic("load_icode: current->mm must be empty.\n");
    }
    struct mm_struct *mm;
    if ((mm = mm_create()) == NULL) {
        goto bad_mm;
    }

    // (2) 创建页目录表
    if (setup_pgdir(mm) != 0) {
        goto bad_pgdir_cleanup_mm;
    }

    // (3) 读取并解析ELF头
    struct elfhdr elf;
    if ((ret = load_icode_read(fd, &elf, sizeof(struct elfhdr), 0)) != 0) {
        goto bad_elf_cleanup_pgdir;
    }
    if (elf.e_magic != ELF_MAGIC) {
        ret = -E_INVAL_ELF;
        goto bad_elf_cleanup_pgdir;
    }

    // (4) 加载各个程序段
    for (i = 0; i < elf.e_phnum; i++) {
        // 读取程序头
        load_icode_read(fd, &ph, sizeof(struct proghdr),
                        elf.e_phoff + i * sizeof(struct proghdr));

        if (ph.p_type != ELF_PT_LOAD) continue;

        // 建立VMA映射
        mm_map(mm, ph.p_va, ph.p_memsz, vm_flags, NULL);

        // 分配页面并读取文件内容
        while (start < end) {
            page = pgdir_alloc_page(mm->pgdir, la, perm);
            load_icode_read(fd, page2kva(page) + off, size,
                           ph.p_offset + start - ph.p_va);
            start += size;
        }

        // 处理BSS段（清零）
        // ...
    }

    // (5) 设置用户栈
    mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, VM_READ | VM_WRITE | VM_STACK, NULL);
    pgdir_alloc_page(mm->pgdir, USTACKTOP - PGSIZE, PTE_USER);
    // ...

    // (6) 设置当前进程的mm和页目录
    mm_count_inc(mm);
    current->mm = mm;
    current->pgdir = mm->pgdir;
    lsatp(PADDR(mm->pgdir));

    // (7) 设置用户栈参数（argc, argv）
    // 将参数字符串压入栈中
    // 将参数指针数组压入栈中

    // (8) 设置trapframe
    struct trapframe *tf = current->tf;
    memset(tf, 0, sizeof(struct trapframe));
    tf->gpr.sp = stacktop;          // 栈指针
    tf->epc = elf.e_entry;          // 程序入口
    tf->gpr.a0 = argc;              // 参数个数
    tf->gpr.a1 = (uintptr_t)argv_base;  // 参数数组指针
    tf->status = read_csr(sstatus);
    tf->status &= ~SSTATUS_SPP;     // 返回用户态
    tf->status |= SSTATUS_SPIE;     // 使能中断

    return 0;
}
```

#### 4. 缺页处理的支持

为了支持用户程序的正常执行，还需要在`trap.c`中正确处理缺页异常：

```c
case CAUSE_LOAD_PAGE_FAULT:
    if (current != NULL && current->mm != NULL &&
        do_pgfault(current->mm, tf->cause, tf->tval) == 0) {
        break;  // 处理成功
    }
    cprintf("Load page fault\n");
    print_trapframe(tf);
    do_exit(-E_KILLED);
    break;

case CAUSE_STORE_PAGE_FAULT:
    if (current != NULL && current->mm != NULL &&
        do_pgfault(current->mm, tf->cause, tf->tval) == 0) {
        break;  // 处理成功
    }
    cprintf("Store/AMO page fault\n");
    print_trapframe(tf);
    do_exit(-E_KILLED);
    break;
```

#### 5. do_pgfault 函数实现

在`vmm.c`中实现缺页处理函数：

```c
int do_pgfault(struct mm_struct *mm, uint32_t error_code, uintptr_t addr) {
    if (mm == NULL) return -E_INVAL;

    uintptr_t la = ROUNDDOWN(addr, PGSIZE);
    struct vma_struct *vma = find_vma(mm, la);
    if (vma == NULL || vma->vm_start > la) {
        return -E_INVAL;
    }

    // 设置页面权限
    uint32_t perm = PTE_U | PTE_V;
    if (vma->vm_flags & VM_WRITE) perm |= PTE_W;
    if (vma->vm_flags & VM_READ) perm |= PTE_R;
    if (vma->vm_flags & VM_EXEC) perm |= PTE_X;

    pte_t *ptep = get_pte(mm->pgdir, la, 1);
    if (ptep == NULL) return -E_NO_MEM;

    if (*ptep == 0) {
        // 页面不存在，分配新页面（demand paging）
        if (pgdir_alloc_page(mm->pgdir, la, perm) == NULL) {
            return -E_NO_MEM;
        }
    } else {
        // 页面存在但权限问题（可能是COW）
        // 处理COW...
    }
    return 0;
}
```

### 运行结果

执行`make qemu`后，可以看到 shell 正常运行：

```
kernel_execve: pid = 2, name = "sh".
user sh is running!!!
$ hello
Hello world!!.
I am process 4.
hello pass.
$ exit
```

执行`make grade`，测试全部通过：

```
  -sh execve:                                OK
  -user sh :                                 OK
Total Score: 100/100
```

---

## 扩展练习 Challenge1：完成基于"UNIX 的 PIPE 机制"的设计方案

### 1. 概述

UNIX 管道（Pipe）是一种进程间通信（IPC）机制，允许一个进程的输出作为另一个进程的输入。管道是一个单向的、先进先出（FIFO）的数据通道。

### 2. 数据结构设计

```c
// 管道缓冲区大小
#define PIPE_BUF_SIZE 4096

// 管道结构
struct pipe {
    char buffer[PIPE_BUF_SIZE];   // 环形缓冲区
    uint32_t read_pos;             // 读位置
    uint32_t write_pos;            // 写位置
    uint32_t count;                // 缓冲区中的数据量

    semaphore_t sem_read;          // 读信号量（阻塞读者）
    semaphore_t sem_write;         // 写信号量（阻塞写者）
    semaphore_t mutex;             // 互斥锁（保护缓冲区）

    int read_open;                 // 读端是否打开
    int write_open;                // 写端是否打开

    wait_queue_t read_queue;       // 等待读的进程队列
    wait_queue_t write_queue;      // 等待写的进程队列
};

// 管道文件结构（用于文件描述符）
struct pipe_file {
    struct pipe *pipe;             // 关联的管道
    int is_read_end;               // 是否是读端
};
```

### 3. 接口设计

```c
// 创建管道，返回两个文件描述符
// pipefd[0] - 读端, pipefd[1] - 写端
int pipe(int pipefd[2]);

// 从管道读取数据
ssize_t pipe_read(struct pipe *p, void *buf, size_t count);

// 向管道写入数据
ssize_t pipe_write(struct pipe *p, const void *buf, size_t count);

// 关闭管道的一端
int pipe_close(struct pipe_file *pf);
```

### 4. 同步互斥处理

1. **互斥访问**：使用`mutex`信号量保护对缓冲区的并发访问
2. **读者阻塞**：当缓冲区为空时，读者在`read_queue`上等待
3. **写者阻塞**：当缓冲区满时，写者在`write_queue`上等待
4. **唤醒机制**：
    - 写入数据后唤醒等待的读者
    - 读取数据后唤醒等待的写者
5. **关闭处理**：当写端关闭时，唤醒所有等待的读者，返回 EOF

### 5. 实现要点

```c
ssize_t pipe_read(struct pipe *p, void *buf, size_t count) {
    down(&p->mutex);

    while (p->count == 0) {
        if (!p->write_open) {
            // 写端已关闭，返回EOF
            up(&p->mutex);
            return 0;
        }
        // 等待数据
        up(&p->mutex);
        wait_current_set(&p->read_queue, ...);
        schedule();
        down(&p->mutex);
    }

    // 从缓冲区读取数据
    size_t bytes_read = min(count, p->count);
    // 复制数据...

    // 唤醒等待的写者
    wakeup_queue(&p->write_queue, ...);

    up(&p->mutex);
    return bytes_read;
}
```

---

## 扩展练习 Challenge2：完成基于"UNIX 的软连接和硬连接机制"的设计方案

### 1. 硬链接（Hard Link）

#### 概念

硬链接是文件系统中多个目录项指向同一个 inode 的机制。所有硬链接共享同一个 inode，因此共享同一份数据。

#### 数据结构

```c
// 在sfs_disk_inode中添加链接计数
struct sfs_disk_inode {
    uint32_t size;                 // 文件大小
    uint16_t type;                 // 文件类型
    uint16_t nlinks;               // 硬链接计数
    uint32_t blocks;               // 数据块数
    uint32_t direct[SFS_NDIRECT];  // 直接块指针
    uint32_t indirect;             // 间接块指针
};
```

#### 接口

```c
// 创建硬链接
// oldpath: 已存在文件的路径
// newpath: 新链接的路径
int link(const char *oldpath, const char *newpath);

// 删除链接（减少链接计数，计数为0时删除文件）
int unlink(const char *pathname);
```

#### 实现要点

1. `link()`：在目标目录创建新目录项，指向同一个 inode，增加`nlinks`计数
2. `unlink()`：删除目录项，减少`nlinks`计数，若为 0 则释放 inode 和数据块
3. 硬链接不能跨文件系统，不能链接目录

### 2. 软链接（Symbolic Link / Soft Link）

#### 概念

软链接是一种特殊类型的文件，其内容是另一个文件的路径名。访问软链接时，系统会自动解析其指向的目标路径。

#### 数据结构

```c
// 新增文件类型
#define SFS_TYPE_LINK   3   // 符号链接

// 符号链接的inode
struct sfs_disk_inode {
    uint32_t size;          // 目标路径的长度
    uint16_t type;          // SFS_TYPE_LINK
    uint16_t nlinks;        // 链接计数（通常为1）
    // 目标路径存储在数据块中
    uint32_t direct[SFS_NDIRECT];
};
```

#### 接口

```c
// 创建符号链接
// target: 目标路径（可以是相对或绝对路径）
// linkpath: 符号链接的路径
int symlink(const char *target, const char *linkpath);

// 读取符号链接指向的路径
ssize_t readlink(const char *pathname, char *buf, size_t bufsiz);
```

#### 实现要点

1. 创建时：分配新 inode，类型为`SFS_TYPE_LINK`，将目标路径存入数据块
2. 访问时：在路径解析（`sfs_lookup`）中检测符号链接，递归解析目标路径
3. 循环检测：设置最大符号链接嵌套深度，防止无限循环
4. 软链接可以跨文件系统，可以指向不存在的目标

### 3. 同步互斥考虑

1. **inode 锁**：访问/修改 inode 时需要加锁
2. **目录锁**：创建/删除链接时需要锁定相关目录
3. **引用计数**：维护 inode 的引用计数，确保正确释放
4. **死锁预防**：按照固定顺序获取多个锁

---

## 重要知识点总结

### 实验中的重要知识点

1. **文件系统层次结构**

    - VFS（虚拟文件系统）：提供统一的文件操作接口
    - SFS（简单文件系统）：实际的磁盘文件系统
    - 设备层：将设备抽象为文件

2. **文件读写流程**

    - 用户程序调用`read()`/`write()`
    - 系统调用进入内核
    - VFS 层分发到具体文件系统
    - SFS 通过`sfs_io_nolock`操作磁盘块

3. **程序加载机制**

    - 从文件系统读取 ELF 文件
    - 解析程序头，建立虚拟地址空间
    - 通过缺页异常实现 demand paging

4. **缺页处理**
    - 检查地址合法性（是否在 VMA 范围内）
    - 分配物理页面
    - 建立页表映射
    - 支持 COW（Copy-on-Write）

### 与 OS 原理的对应

| 实验知识点 | OS 原理知识点            |
| ---------- | ------------------------ |
| VFS        | 文件系统接口抽象         |
| inode      | 文件元数据管理           |
| 目录结构   | 文件命名与组织           |
| 块设备操作 | I/O 子系统               |
| 文件描述符 | 进程的打开文件表         |
| load_icode | 程序加载与执行           |
| do_pgfault | 虚拟内存与 demand paging |

### 实验中较重要但原理中未涉及的知识点

1. **SFS 的具体实现细节**：如块位图管理、间接块索引等
2. **ELF 文件格式解析**：程序头、段加载等
3. **设备文件抽象**：stdin/stdout 作为文件处理
4. **RISC-V 特权级切换**：通过 trapframe 和 sret 指令实现

---

## 实验总结

本次 Lab8 实验成功实现了基于 SFS 文件系统的程序加载和执行机制。主要完成了：

1. **练习 1**：实现`sfs_io_nolock`函数，支持文件的块级读写操作
2. **练习 2**：改写`load_icode`函数，实现从文件系统加载用户程序

通过本次实验，深入理解了文件系统的层次结构、文件读写的底层实现、以及用户程序从磁盘加载到内存执行的完整流程。同时也理解了 VFS 抽象层的设计思想，以及如何将设备统一抽象为文件进行管理。

最终测试结果：**Total Score: 100/100**
