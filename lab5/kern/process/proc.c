#include <proc.h>
#include <kmalloc.h>
#include <string.h>
#include <sync.h>
#include <pmm.h>
#include <error.h>
#include <sched.h>
#include <elf.h>
#include <vmm.h>
#include <trap.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>

/* ------------- process/thread mechanism design&implementation -------------
(an simplified Linux process/thread mechanism )
introduction:
  ucore implements a simple process/thread mechanism. process contains the independent memory sapce, at least one threads
for execution, the kernel data(for management), processor state (for context switch), files(in lab6), etc. ucore needs to
manage all these details efficiently. In ucore, a thread is just a special kind of process(share process's memory).
------------------------------
process state       :     meaning               -- reason
    PROC_UNINIT     :   uninitialized           -- alloc_proc
    PROC_SLEEPING   :   sleeping                -- try_free_pages, do_wait, do_sleep
    PROC_RUNNABLE   :   runnable(maybe running) -- proc_init, wakeup_proc,
    PROC_ZOMBIE     :   almost dead             -- do_exit

-----------------------------
process state changing:

  alloc_proc                                 RUNNING
      +                                   +--<----<--+
      +                                   + proc_run +
      V                                   +-->---->--+
PROC_UNINIT -- proc_init/wakeup_proc --> PROC_RUNNABLE -- try_free_pages/do_wait/do_sleep --> PROC_SLEEPING --
                                           A      +                                                           +
                                           |      +--- do_exit --> PROC_ZOMBIE                                +
                                           +                                                                  +
                                           -----------------------wakeup_proc----------------------------------
-----------------------------
process relations
parent:           proc->parent  (proc is children)
children:         proc->cptr    (proc is parent)
older sibling:    proc->optr    (proc is younger sibling)
younger sibling:  proc->yptr    (proc is older sibling)
-----------------------------
related syscall for process:
SYS_exit        : process exit,                           -->do_exit
SYS_fork        : create child process, dup mm            -->do_fork-->wakeup_proc
SYS_wait        : wait process                            -->do_wait
SYS_exec        : after fork, process execute a program   -->load a program and refresh the mm
SYS_clone       : create child thread                     -->do_fork-->wakeup_proc
SYS_yield       : process flag itself need resecheduling, -- proc->need_sched=1, then scheduler will rescheule this process
SYS_sleep       : process sleep                           -->do_sleep
SYS_kill        : kill process                            -->do_kill-->proc->flags |= PF_EXITING
                                                                 -->wakeup_proc-->do_wait-->do_exit
SYS_getpid      : get the process's pid

*/

// the process set's list
list_entry_t proc_list;

#define HASH_SHIFT 10
#define HASH_LIST_SIZE (1 << HASH_SHIFT)
#define pid_hashfn(x) (hash32(x, HASH_SHIFT))

// has list for process set based on pid
static list_entry_t hash_list[HASH_LIST_SIZE];

// idle proc
struct proc_struct *idleproc = NULL;
// init proc
struct proc_struct *initproc = NULL;
// current proc
struct proc_struct *current = NULL;

static int nr_process = 0;

void kernel_thread_entry(void);
void forkrets(struct trapframe *tf);
void switch_to(struct context *from, struct context *to);

// alloc_proc - alloc a proc_struct and init all fields of proc_struct
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        // LAB4:EXERCISE1 YOUR CODE
        /*
         * below fields in proc_struct need to be initialized
         *       enum proc_state state;                      // Process state
         *       int pid;                                    // Process ID
         *       int runs;                                   // the running times of Proces
         *       uintptr_t kstack;                           // Process kernel stack
         *       volatile bool need_resched;                 // bool value: need to be rescheduled to release CPU?
         *       struct proc_struct *parent;                 // the parent process
         *       struct mm_struct *mm;                       // Process's memory management field
         *       struct context context;                     // Switch here to run process
         *       struct trapframe *tf;                       // Trap frame for current interrupt
         *       uintptr_t pgdir;                            // the base addr of Page Directroy Table(PDT)
         *       uint32_t flags;                             // Process flag
         *       char name[PROC_NAME_LEN + 1];               // Process name
         */
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

        /*
         * ========== LAB5 更新：进程家族关系字段初始化 ==========
         * 
         * 【背景】LAB5引入了用户进程支持，需要维护进程间的父子/兄弟关系
         * 这些关系用于：
         *   1. wait系统调用 - 父进程等待子进程退出
         *   2. exit系统调用 - 子进程退出时通知父进程  
         *   3. 进程资源回收 - 只有父进程才能回收子进程资源
         *
         * 【字段说明】
         *   wait_state: 进程等待状态标志
         *     - 0: 进程不在等待任何事件
         *     - WT_CHILD (0x00000001): 父进程正在wait()等待子进程退出
         *     - 配合do_wait/do_exit使用，实现父子进程同步
         *
         *   cptr (children pointer): 子进程指针
         *     - 指向该进程的"最新创建的子进程"
         *     - 类似于子进程链表的头指针
         *
         *   yptr (younger sibling pointer): 弟弟指针  
         *     - 指向比自己晚创建的兄弟进程
         *
         *   optr (older sibling pointer): 哥哥指针
         *     - 指向比自己早创建的兄弟进程
         *
         * 【进程家族链表结构示意】
         *           parent
         *             | cptr
         *             v
         *          child3 ---optr---> child2 ---optr---> child1 --> NULL
         *          (最新)   <---yptr--- (较早) <---yptr--- (最早)
         *          NULL<-yptr
         *
         * 【初始化原因】
         *   - wait_state = 0: 新进程不在等待任何事件
         *   - cptr = NULL: 新进程还没有子进程
         *   - optr = NULL: 新进程还没有设置兄弟关系(在set_links中设置)
         *   - yptr = NULL: 新进程是最新创建的，暂时没有弟弟
         */
        // LAB5 2311456 : (update LAB4 steps)
        /*
         * below fields(add in LAB5) in proc_struct need to be initialized
         *       uint32_t wait_state;                        // waiting state
         *       struct proc_struct *cptr, *yptr, *optr;     // relations between processes
         */
        // 【LAB5新增】初始化进程等待状态
        // wait_state = 0 表示进程当前不在等待任何事件
        // 当父进程调用wait()时，wait_state会被设置为WT_CHILD(=1)
        // do_exit()会检查parent->wait_state，若为WT_CHILD则唤醒父进程
        proc->wait_state = 0;
        // 【LAB5新增】初始化进程家族关系指针
        // cptr (children pointer): 指向第一个子进程（最新创建的）
        // optr (older sibling pointer): 指向哥哥（比自己早创建的兄弟）
        // yptr (younger sibling pointer): 指向弟弟（比自己晚创建的兄弟）
        // 新创建的进程没有子进程和兄弟，所以都初始化为NULL
        // 真正的兄弟关系会在do_fork的set_links()中建立
        proc->cptr = proc->optr = proc->yptr = NULL;
    }
    return proc;
}

// set_proc_name - set the name of proc
char *
set_proc_name(struct proc_struct *proc, const char *name)
{
    memset(proc->name, 0, sizeof(proc->name));
    return memcpy(proc->name, name, PROC_NAME_LEN);
}

// get_proc_name - get the name of proc
char *
get_proc_name(struct proc_struct *proc)
{
    static char name[PROC_NAME_LEN + 1];
    memset(name, 0, sizeof(name));
    return memcpy(name, proc->name, PROC_NAME_LEN);
}

// set_links - set the relation links of process
static void
set_links(struct proc_struct *proc)
{
    list_add(&proc_list, &(proc->list_link));
    proc->yptr = NULL;
    if ((proc->optr = proc->parent->cptr) != NULL)
    {
        proc->optr->yptr = proc;
    }
    proc->parent->cptr = proc;
    nr_process++;
}

// remove_links - clean the relation links of process
static void
remove_links(struct proc_struct *proc)
{
    list_del(&(proc->list_link));
    if (proc->optr != NULL)
    {
        proc->optr->yptr = proc->yptr;
    }
    if (proc->yptr != NULL)
    {
        proc->yptr->optr = proc->optr;
    }
    else
    {
        proc->parent->cptr = proc->optr;
    }
    nr_process--;
}

// get_pid - alloc a unique pid for process
static int
get_pid(void)
{
    static_assert(MAX_PID > MAX_PROCESS);
    struct proc_struct *proc;
    list_entry_t *list = &proc_list, *le;
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID)
    {
        last_pid = 1;
        goto inside;
    }
    if (last_pid >= next_safe)
    {
    inside:
        next_safe = MAX_PID;
    repeat:
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid)
            {
                if (++last_pid >= next_safe)
                {
                    if (last_pid >= MAX_PID)
                    {
                        last_pid = 1;
                    }
                    next_safe = MAX_PID;
                    goto repeat;
                }
            }
            else if (proc->pid > last_pid && next_safe > proc->pid)
            {
                next_safe = proc->pid;
            }
        }
    }
    return last_pid;
}

// proc_run - make process "proc" running on cpu
// NOTE: before call switch_to, should load  base addr of "proc"'s new PDT
void proc_run(struct proc_struct *proc)
{
    if (proc != current)
    {
        // LAB4:EXERCISE3 YOUR CODE
        /*
         * Some Useful MACROs, Functions and DEFINEs, you can use them in below implementation.
         * MACROs or Functions:
         *   local_intr_save():        Disable interrupts
         *   local_intr_restore():     Enable Interrupts
         *   lsatp():                   Modify the value of satp register
         *   switch_to():              Context switching between two processes
         */
        bool intr_flag;
        struct proc_struct *prev = current, *next = proc;
        local_intr_save(intr_flag);
        current = proc;
        lsatp(next->pgdir);
        switch_to(&(prev->context), &(next->context));
        local_intr_restore(intr_flag);
    }
}

// forkret -- the first kernel entry point of a new thread/process
// NOTE: the addr of forkret is setted in copy_thread function
//       after switch_to, the current proc will execute here.
static void
forkret(void)
{
    forkrets(current->tf);
}

// hash_proc - add proc into proc hash_list
static void
hash_proc(struct proc_struct *proc)
{
    list_add(hash_list + pid_hashfn(proc->pid), &(proc->hash_link));
}

// unhash_proc - delete proc from proc hash_list
static void
unhash_proc(struct proc_struct *proc)
{
    list_del(&(proc->hash_link));
}

// find_proc - find proc frome proc hash_list according to pid
struct proc_struct *
find_proc(int pid)
{
    if (0 < pid && pid < MAX_PID)
    {
        list_entry_t *list = hash_list + pid_hashfn(pid), *le = list;
        while ((le = list_next(le)) != list)
        {
            struct proc_struct *proc = le2proc(le, hash_link);
            if (proc->pid == pid)
            {
                return proc;
            }
        }
    }
    return NULL;
}

// kernel_thread - create a kernel thread using "fn" function
// NOTE: the contents of temp trapframe tf will be copied to
//       proc->tf in do_fork-->copy_thread function
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
    struct trapframe tf;
    memset(&tf, 0, sizeof(struct trapframe));
    tf.gpr.s0 = (uintptr_t)fn;
    tf.gpr.s1 = (uintptr_t)arg;
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE;
    tf.epc = (uintptr_t)kernel_thread_entry;
    return do_fork(clone_flags | CLONE_VM, 0, &tf);
}

// setup_kstack - alloc pages with size KSTACKPAGE as process kernel stack
static int
setup_kstack(struct proc_struct *proc)
{
    struct Page *page = alloc_pages(KSTACKPAGE);
    if (page != NULL)
    {
        proc->kstack = (uintptr_t)page2kva(page);
        return 0;
    }
    return -E_NO_MEM;
}

// put_kstack - free the memory space of process kernel stack
static void
put_kstack(struct proc_struct *proc)
{
    free_pages(kva2page((void *)(proc->kstack)), KSTACKPAGE);
}

// setup_pgdir - alloc one page as PDT
static int
setup_pgdir(struct mm_struct *mm)
{
    struct Page *page;
    if ((page = alloc_page()) == NULL)
    {
        return -E_NO_MEM;
    }
    pde_t *pgdir = page2kva(page);
    memcpy(pgdir, boot_pgdir_va, PGSIZE);

    mm->pgdir = pgdir;
    return 0;
}

// put_pgdir - free the memory space of PDT
static void
put_pgdir(struct mm_struct *mm)
{
    free_page(kva2page(mm->pgdir));
}

// copy_mm - process "proc" duplicate OR share process "current"'s mm according clone_flags
//         - if clone_flags & CLONE_VM, then "share" ; else "duplicate"
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    struct mm_struct *mm, *oldmm = current->mm;

    /* current is a kernel thread */
    if (oldmm == NULL)
    {
        return 0;
    }
    if (clone_flags & CLONE_VM)
    {
        mm = oldmm;
        goto good_mm;
    }
    int ret = -E_NO_MEM;
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    if (setup_pgdir(mm) != 0)
    {
        goto bad_pgdir_cleanup_mm;
    }
    lock_mm(oldmm);
    {
        ret = dup_mmap(mm, oldmm);
    }
    unlock_mm(oldmm);

    if (ret != 0)
    {
        goto bad_dup_cleanup_mmap;
    }

good_mm:
    mm_count_inc(mm);
    proc->mm = mm;
    proc->pgdir = PADDR(mm->pgdir);
    return 0;
bad_dup_cleanup_mmap:
    exit_mmap(mm);
    put_pgdir(mm);
bad_pgdir_cleanup_mm:
    mm_destroy(mm);
bad_mm:
    return ret;
}

// copy_thread - setup the trapframe on the  process's kernel stack top and
//             - setup the kernel entry point and stack of process
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf)
{
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1;
    *(proc->tf) = *tf;

    // Set a0 to 0 so a child process knows it's just forked
    proc->tf->gpr.a0 = 0;
    proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;

    proc->context.ra = (uintptr_t)forkret;
    proc->context.sp = (uintptr_t)(proc->tf);
}

/* do_fork -     parent process for a new child process
 * @clone_flags: used to guide how to clone the child process
 * @stack:       the parent's user stack pointer. if stack==0, It means to fork a kernel thread.
 * @tf:          the trapframe info, which will be copied to child process's proc->tf
 * 
 * 【练习3分析 - fork系统调用的内核实现】
 * 
 * 执行流程（用户态 -> 内核态 -> 用户态）：
 * 用户态: fork() -> sys_fork() -> ecall指令 ->
 * 内核态: trap -> syscall() -> sys_fork() -> do_fork() ->
 *         [创建子进程] -> wakeup_proc() -> 返回 ->
 * 用户态: 父进程返回子进程PID，子进程返回0
 * 
 * 【COW集成点】
 * 当clone_flags不含CLONE_VM时，copy_mm会调用dup_mmap->copy_range
 * copy_range中实现了COW机制，不实际复制页面，而是共享并标记COW
 */
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;
    
    // 检查进程数量是否达到上限
    if (nr_process >= MAX_PROCESS)
    {
        goto fork_out;
    }
    ret = -E_NO_MEM;
    // LAB4:EXERCISE2 YOUR CODE
    /*
     * Some Useful MACROs, Functions and DEFINEs, you can use them in below implementation.
     * MACROs or Functions:
     *   alloc_proc:   create a proc struct and init fields (lab4:exercise1)
     *   setup_kstack: alloc pages with size KSTACKPAGE as process kernel stack
     *   copy_mm:      process "proc" duplicate OR share process "current"'s mm according clone_flags
     *                 if clone_flags & CLONE_VM, then "share" ; else "duplicate"
     *   copy_thread:  setup the trapframe on the  process's kernel stack top and
     *                 setup the kernel entry point and stack of process
     *   hash_proc:    add proc into proc hash_list
     *   get_pid:      alloc a unique pid for process
     *   wakeup_proc:  set proc->state = PROC_RUNNABLE
     * VARIABLES:
     *   proc_list:    the process set's list
     *   nr_process:   the number of process set
     */

    //    1. call alloc_proc to allocate a proc_struct
    //    2. call setup_kstack to allocate a kernel stack for child process
    //    3. call copy_mm to dup OR share mm according clone_flag
    //    4. call copy_thread to setup tf & context in proc_struct
    //    5. insert proc_struct into hash_list && proc_list
    //    6. call wakeup_proc to make the new child process RUNNABLE
    //    7. set ret vaule using child proc's pid

    /*
     * ========== LAB5 更新说明：进程家族关系的建立 ==========
     *
     * 【LAB4 vs LAB5 的区别】
     * LAB4: 只有内核线程，没有父子关系的完整管理
     * LAB5: 引入用户进程，需要完整的进程家族关系管理
     *
     * 【步骤1 更新内容】设置父子关系
     *   - proc->parent = current: 新进程的父进程是当前正在执行的进程
     *   - assert(current->wait_state == 0): 一致性检查
     *     * 正在执行fork的进程不可能同时在wait中睡眠
     *     * 如果wait_state != 0，说明状态机出错
     *
     * 【步骤5 更新内容】使用set_links代替直接操作
     *   - LAB4: 直接 list_add 和 nr_process++
     *   - LAB5: 调用 set_links(proc) 函数，它会：
     *     1. list_add(&proc_list, &(proc->list_link)) - 加入进程链表
     *     2. 设置 optr/yptr 兄弟关系
     *     3. 更新 parent->cptr 指向新子进程
     *     4. nr_process++
     *
     * 【set_links 详解】
     *   proc->yptr = NULL;                     // 新进程是最年轻的，没有弟弟
     *   proc->optr = proc->parent->cptr;       // 原来的大儿子变成自己的哥哥
     *   if (proc->optr != NULL)
     *       proc->optr->yptr = proc;           // 哥哥的弟弟指向自己
     *   proc->parent->cptr = proc;             // 自己成为父进程的新大儿子
     *
     * 【为什么需要进程家族关系？】
     *   1. wait(): 父进程需要遍历所有子进程找ZOMBIE
     *   2. exit(): 子进程需要通知父进程，并把自己的子进程托孤给init
     *   3. kill(): 需要确保只能kill自己的子进程
     */
    // LAB5  : 2310764(update LAB4 steps)
    // TIPS: you should modify your written code in lab4(step1 and step5), not add more code.
    /* Some Functions
     *    set_links:  set the relation links of process.  ALSO SEE: remove_links:  lean the relation links of process
     *    -------------------
     *    update step 1: set child proc's parent to current process, make sure current process's wait_state is 0
     *    update step 5: insert proc_struct into hash_list && proc_list, set the relation links of process
     */

    // ========== 步骤1: 分配并初始化进程控制块 ==========
    if ((proc = alloc_proc()) == NULL) {
        goto fork_out;
    }
    // 设置父子关系（LAB5更新）
    // 【LAB5步骤1更新】建立父子关系
    // proc->parent = current 的含义：
    //   - proc 是新创建的子进程
    //   - current 是当前正在执行fork的进程（即父进程）
    //   - 这一行建立了"谁是谁的父亲"的关系
    //   - fork返回后，子进程可以通过getppid()获取父进程PID
    proc->parent = current;
    assert(current->wait_state == 0);  
    // 【一致性断言检查】
    // current->wait_state == 0 的含义：
    //   - wait_state != 0 表示进程正在等待某个事件（如等子进程退出）
    //   - 如果父进程正在wait()中睡眠，它不可能同时执行fork()
    //   - 这是一个逻辑一致性检查，如果失败说明内核有bug

    // ========== 步骤2: 分配内核栈 ==========
    if (setup_kstack(proc) != 0) {
        goto bad_fork_cleanup_proc;
    }

    // ========== 步骤3: 复制/共享内存空间 ==========
    // 【重要】这里调用copy_mm，最终会调用copy_range实现COW
    if (copy_mm(clone_flags, proc) != 0) {
        goto bad_fork_cleanup_kstack;
    }

    // ========== 步骤4: 复制线程上下文 ==========
    // 设置子进程的trapframe和context
    // 子进程的a0寄存器被设为0，这就是fork()返回0的原因
    copy_thread(proc, stack, tf);

    // ========== 步骤5: 加入进程管理结构（LAB5更新：使用set_links） ==========
    // 需要关中断保护临界区
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        // 【分配进程ID】调用get_pid()获取一个唯一的PID
        // get_pid()会遍历proc_list，找到一个未被使用的PID值
        // PID范围: 1 ~ MAX_PID-1, 避开0(idle)和已使用的值
        proc->pid = get_pid();
        // 【加入PID哈希表】用于通过PID快速查找进程
        // hash_proc(): 根据PID计算哈希值，加入hash_list
        // 之后可以通过find_proc(pid)在O(1)时间内找到进程
        hash_proc(proc);
        // 【LAB5新增：建立进程家族关系】
        // set_links(proc)做了4件事：
        //   1. list_add(&proc_list, &proc->list_link) - 加入全局进程链表
        //   2. proc->optr = proc->parent->cptr - 原来的大儿子变成自己的哥哥
        //   3. if(proc->optr) proc->optr->yptr = proc - 让哥哥知道自己是他弟弟
        //   4. proc->parent->cptr = proc - 自己成为父进程的新"大儿子"
        //   5. nr_process++ - 全局进程计数加1
        set_links(proc);
    }
    local_intr_restore(intr_flag);

    // ========== 步骤6: 唤醒子进程 ==========
    wakeup_proc(proc);  // 设置为PROC_RUNNABLE状态
    
    // ========== 步骤7: 返回子进程PID给父进程 ==========
    ret = proc->pid;

fork_out:
    return ret;

bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}

// do_exit - called by sys_exit
//   1. call exit_mmap & put_pgdir & mm_destroy to free the almost all memory space of process
//   2. set process' state as PROC_ZOMBIE, then call wakeup_proc(parent) to ask parent reclaim itself.
//   3. call scheduler to switch to other process
/* 
 * 【练习3分析 - exit系统调用的内核实现】
 * 
 * 执行流程（用户态 -> 内核态，不返回）：
 * 用户态: exit(code) -> sys_exit() -> ecall指令 ->
 * 内核态: trap -> syscall() -> sys_exit() -> do_exit() ->
 *         [释放资源] -> PROC_ZOMBIE -> schedule() -> 永不返回
 * 
 * 注意：此函数永不返回！进程的最终资源回收由父进程的do_wait完成
 */
int do_exit(int error_code)
{
    // idle和init进程不能退出
    if (current == idleproc)
    {
        panic("idleproc exit.\n");
    }
    if (current == initproc)
    {
        panic("initproc exit.\n");
    }

    // ========== 步骤1: 释放内存空间 ==========
    bool intr_flag;
    local_intr_save(intr_flag);
    {
    struct mm_struct *mm = current->mm;
    if (mm != NULL)
    {
        // 切换到内核页表（避免释放正在使用的页表）
        lsatp(boot_pgdir_pa);
        
        // 减少mm引用计数，如果为0则释放
        // 【COW相关】exit_mmap会释放所有页面，对于COW页面会减少引用计数
        if (mm_count_dec(mm) == 0)
        {
            exit_mmap(mm);   // 解除所有映射，释放/减少引用计数
            put_pgdir(mm);   // 释放页目录
            mm_destroy(mm);  // 销毁mm结构
        }
        current->mm = NULL;
    }
    
    struct proc_struct *proc;
    
    // 【关键修复】将设置ZOMBIE状态和唤醒父进程放在同一个临界区内
    // 避免竞态条件：
    // 1. 子进程先设置ZOMBIE，但还没唤醒父进程
    // 2. 父进程do_wait检查时发现不是ZOMBIE（因为还在遍历），然后设置SLEEPING
    // 3. 子进程检查wait_state时父进程还没设置SLEEPING，所以不唤醒
    // 4. 结果：子进程变成ZOMBIE，父进程永远SLEEPING

        // ========== 步骤2: 设置僵尸状态 ==========
        current->state = PROC_ZOMBIE;    // 变成僵尸进程
        current->exit_code = error_code;  // 保存退出码
        
        // ========== 步骤3: 唤醒父进程 ==========
        proc = current->parent;
        if (proc->wait_state == WT_CHILD)
        {
            // 父进程正在wait，唤醒它
            wakeup_proc(proc);
        }
        
        // ========== 步骤4: 处理子进程（托孤给init） ==========
        while (current->cptr != NULL)
        {
            proc = current->cptr;
            current->cptr = proc->optr;

            // 将子进程的父进程改为init
            proc->yptr = NULL;
            if ((proc->optr = initproc->cptr) != NULL)
            {
                initproc->cptr->yptr = proc;
            }
            proc->parent = initproc;
            initproc->cptr = proc;
            
            // 如果子进程已经是僵尸，唤醒init去回收
            if (proc->state == PROC_ZOMBIE)
            {
                if (initproc->wait_state == WT_CHILD)
                {
                    wakeup_proc(initproc);
                }
            }
        }
    }
    local_intr_restore(intr_flag);
    
    // ========== 步骤5: 调度到其他进程 ==========
    schedule();
    
    // 此函数永不返回！
    panic("do_exit will not return!! %d.\n", current->pid);
}

/* load_icode - load the content of binary program(ELF format) as the new content of current process
 * @binary:  the memory addr of the content of binary program
 * @size:  the size of the content of binary program
 */
static int
load_icode(unsigned char *binary, size_t size)
{
    if (current->mm != NULL)
    {
        panic("load_icode: current->mm must be empty.\n");
    }

    int ret = -E_NO_MEM;
    struct mm_struct *mm;
    //(1) create a new mm for current process
    if ((mm = mm_create()) == NULL)
    {
        goto bad_mm;
    }
    //(2) create a new PDT, and mm->pgdir= kernel virtual addr of PDT
    if (setup_pgdir(mm) != 0)
    {
        goto bad_pgdir_cleanup_mm;
    }
    //(3) copy TEXT/DATA section, build BSS parts in binary to memory space of process
    struct Page *page;
    //(3.1) get the file header of the bianry program (ELF format)
    struct elfhdr *elf = (struct elfhdr *)binary;
    //(3.2) get the entry of the program section headers of the bianry program (ELF format)
    struct proghdr *ph = (struct proghdr *)(binary + elf->e_phoff);
    //(3.3) This program is valid?
    if (elf->e_magic != ELF_MAGIC)
    {
        ret = -E_INVAL_ELF;
        goto bad_elf_cleanup_pgdir;
    }

    uint32_t vm_flags, perm;
    struct proghdr *ph_end = ph + elf->e_phnum;
    for (; ph < ph_end; ph++)
    {
        //(3.4) find every program section headers
        if (ph->p_type != ELF_PT_LOAD)
        {
            continue;
        }
        if (ph->p_filesz > ph->p_memsz)
        {
            ret = -E_INVAL_ELF;
            goto bad_cleanup_mmap;
        }
        if (ph->p_filesz == 0)
        {
            // continue ;
        }
        //(3.5) call mm_map fun to setup the new vma ( ph->p_va, ph->p_memsz)
        vm_flags = 0, perm = PTE_U | PTE_V;
        if (ph->p_flags & ELF_PF_X)
            vm_flags |= VM_EXEC;
        if (ph->p_flags & ELF_PF_W)
            vm_flags |= VM_WRITE;
        if (ph->p_flags & ELF_PF_R)
            vm_flags |= VM_READ;
        // modify the perm bits here for RISC-V
        if (vm_flags & VM_READ)
            perm |= PTE_R;
        if (vm_flags & VM_WRITE)
            perm |= (PTE_W | PTE_R);
        if (vm_flags & VM_EXEC)
            perm |= PTE_X;
        if ((ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL)) != 0)
        {
            goto bad_cleanup_mmap;
        }
        unsigned char *from = binary + ph->p_offset;
        size_t off, size;
        uintptr_t start = ph->p_va, end, la = ROUNDDOWN(start, PGSIZE);

        ret = -E_NO_MEM;

        //(3.6) alloc memory, and  copy the contents of every program section (from, from+end) to process's memory (la, la+end)
        end = ph->p_va + ph->p_filesz;
        //(3.6.1) copy TEXT/DATA section of bianry program
        while (start < end)
        {
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                goto bad_cleanup_mmap;
            }
            off = start - la, size = PGSIZE - off, la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            memcpy(page2kva(page) + off, from, size);
            start += size, from += size;
        }

        //(3.6.2) build BSS section of binary program
        end = ph->p_va + ph->p_memsz;
        if (start < la)
        {
            /* ph->p_memsz == ph->p_filesz */
            if (start == end)
            {
                continue;
            }
            off = start + PGSIZE - la, size = PGSIZE - off;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
            assert((end < la && start == end) || (end >= la && start == la));
        }
        while (start < end)
        {
            if ((page = pgdir_alloc_page(mm->pgdir, la, perm)) == NULL)
            {
                goto bad_cleanup_mmap;
            }
            off = start - la, size = PGSIZE - off, la += PGSIZE;
            if (end < la)
            {
                size -= la - end;
            }
            memset(page2kva(page) + off, 0, size);
            start += size;
        }
    }
    //(4) build user stack memory
    vm_flags = VM_READ | VM_WRITE | VM_STACK;
    if ((ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE, vm_flags, NULL)) != 0)
    {
        goto bad_cleanup_mmap;
    }
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 2 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 3 * PGSIZE, PTE_USER) != NULL);
    assert(pgdir_alloc_page(mm->pgdir, USTACKTOP - 4 * PGSIZE, PTE_USER) != NULL);

    //(5) set current process's mm, sr3, and set satp reg = physical addr of Page Directory
    mm_count_inc(mm);
    current->mm = mm;
    current->pgdir = PADDR(mm->pgdir);
    lsatp(PADDR(mm->pgdir));

    //(6) setup trapframe for user environment
    struct trapframe *tf = current->tf;
    // Keep sstatus
    uintptr_t sstatus = tf->status;
    memset(tf, 0, sizeof(struct trapframe));
    /*
     * ========== LAB5 练习1：设置用户态返回的trapframe ==========
     *
     * 【目标】使内核能够"返回"到用户态执行新加载的程序
     *
     * 【RISC-V 特权级切换机制】
     * 当执行 sret 指令时：
     *   1. PC <- sepc  (跳转到sepc保存的地址)
     *   2. 特权级 <- SPP位 (0=U-mode用户态, 1=S-mode内核态)
     *   3. SIE <- SPIE (恢复中断使能状态)
     *   4. SPIE <- 1, SPP <- 0
     *
     * 【需要设置的字段】
     *
     *   tf->gpr.sp = USTACKTOP:
     *     - 设置用户栈指针为用户栈顶
     *     - USTACKTOP 定义在 memlayout.h，是用户栈的最高地址
     *     - 用户程序从这里开始向下使用栈空间
     *
     *   tf->epc = elf->e_entry:
     *     - 设置程序入口点地址
     *     - elf->e_entry 是ELF文件头中指定的入口地址(如_start)
     *     - sret后CPU会跳转到这个地址开始执行用户程序
     *
     *   tf->status = sstatus & ~SSTATUS_SPP:
     *     - 清除SPP位(设为0)
     *     - SPP=0 表示sret后返回到用户态(U-mode)
     *     - 如果SPP=1，sret后仍在内核态(S-mode)
     *
     *   tf->status |= SSTATUS_SPIE:
     *     - 设置SPIE位(设为1)
     *     - sret执行时，SPIE会复制到SIE
     *     - 这确保返回用户态后中断是开启的
     *     - 用户程序需要时钟中断来实现进程调度
     *
     * 【执行流程】
     *   load_icode设置好trapframe后:
     *     -> forkret() 
     *     -> forkrets() 调用 sret
     *     -> CPU跳转到tf->epc(用户程序入口)
     *     -> 特权级切换到用户态
     *     -> 用户程序开始执行
     */
    /* LAB5:EXERCISE1 2311456
     * should set tf->gpr.sp, tf->epc, tf->status
     * NOTICE: If we set trapframe correctly, then the user level process can return to USER MODE from kernel. So
     *          tf->gpr.sp should be user stack top (the value of sp)
     *          tf->epc should be entry point of user program (the value of sepc)
     *          tf->status should be appropriate for user program (the value of sstatus)
     *          hint: check meaning of SPP, SPIE in SSTATUS, use them by SSTATUS_SPP, SSTATUS_SPIE(defined in risv.h)
     */
    // 【设置用户栈指针 sp】
    // USTACKTOP 是用户栈的最高地址（定义在memlayout.h）
    // 栈向下生长，所以从USTACKTOP开始向低地址使用
    // sret返回用户态后，sp寄存器会被设为这个值
    tf->gpr.sp = USTACKTOP;
    // 【设置程序入口点 epc】
    // elf->e_entry 是ELF文件头中指定的程序入口地址
    // 通常指向 _start 函数，然后调用 main()
    // sret指令执行时：PC <- sepc，即跳转到这个地址
    tf->epc = elf->e_entry;
    // 【设置特权级：清除SPP位，返回用户态】
    // SSTATUS_SPP 是 sstatus 寄存器中的 SPP 位(bit 8)
    // SPP = 0: sret后进入用户态(U-mode)
    // SPP = 1: sret后仍在内核态(S-mode)
    // ~SSTATUS_SPP 是取反，& 操作将SPP位清0
    tf->status = sstatus & ~SSTATUS_SPP;
    // 【设置中断使能：设置SPIE位，返回后开中断】
    // SSTATUS_SPIE 是 sstatus 寄存器中的 SPIE 位(bit 5)
    // sret执行时：SIE <- SPIE（即中断使能位被设为SPIE的值）
    // SPIE = 1 意味着返回用户态后，中断是开启的
    // 这很重要！用户程序需要时钟中断来实现进程调度
    tf->status |= SSTATUS_SPIE;

    ret = 0;
out:
    return ret;
bad_cleanup_mmap:
    exit_mmap(mm);
bad_elf_cleanup_pgdir:
    put_pgdir(mm);
bad_pgdir_cleanup_mm:
    mm_destroy(mm);
bad_mm:
    goto out;
}

/* do_execve - 执行新程序，替换当前进程的内存空间
 * 
 * 【练习3分析 - exec系统调用的内核实现】
 * 
 * 执行流程（用户态 -> 内核态 -> 用户态新程序）：
 * 用户态: exec() -> sys_exec() -> ecall指令 ->
 * 内核态: trap -> syscall() -> sys_exec() -> do_execve() ->
 *         [释放旧内存空间] -> load_icode() [加载新程序] ->
 *         [设置trapframe] -> sret ->
 * 用户态: 从新程序的入口点开始执行（不返回原程序！）
 * 
 * @name:   新程序的名称
 * @len:    名称长度
 * @binary: ELF格式程序在内存中的地址
 * @size:   程序大小
 * 
 * 返回值: 成功不返回（开始执行新程序），失败返回负错误码
 * 
 * 注意：exec不创建新进程！它复用当前进程的PID、父子关系等，
 *       只是替换内存空间和执行代码。这就是"fork+exec"模式的意义。
 */
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size)
{
    struct mm_struct *mm = current->mm;
    
    // 验证用户传入的程序名指针有效性
    if (!user_mem_check(mm, (uintptr_t)name, len, 0))
    {
        return -E_INVAL;
    }
    if (len > PROC_NAME_LEN)
    {
        len = PROC_NAME_LEN;
    }

    // 复制程序名到内核空间（因为马上要释放用户空间）
    char local_name[PROC_NAME_LEN + 1];
    memset(local_name, 0, sizeof(local_name));
    memcpy(local_name, name, len);

    // ========== 步骤1: 释放当前进程的内存空间 ==========
    if (mm != NULL)
    {
        cputs("mm != NULL");
        lsatp(boot_pgdir_pa);  // 切换到内核页表
        
        // 减少引用计数，必要时释放内存
        // 【COW相关】如果有共享页面，只减少引用计数
        if (mm_count_dec(mm) == 0)
        {
            exit_mmap(mm);    // 解除映射
            put_pgdir(mm);    // 释放页目录
            mm_destroy(mm);   // 销毁mm结构
        }
        current->mm = NULL;
    }
    
    // ========== 步骤2: 加载新程序 ==========
    int ret;
    if ((ret = load_icode(binary, size)) != 0)
    {
        goto execve_exit;
    }
    
    // ========== 步骤3: 设置进程名 ==========
    set_proc_name(current, local_name);
    
    // 返回0，之后通过trapframe中设置的epc跳转到新程序入口
    return 0;

execve_exit:
    do_exit(ret);
    panic("already exit: %e.\n", ret);
}

// do_yield - ask the scheduler to reschedule
int do_yield(void)
{
    current->need_resched = 1;
    return 0;
}

// do_wait - wait one OR any children with PROC_ZOMBIE state, and free memory space of kernel stack
//         - proc struct of this child.
// NOTE: only after do_wait function, all resources of the child proces are free.
/* 
 * 【练习3分析 - wait系统调用的内核实现】
 * 
 * 执行流程（用户态 -> 内核态 -> 用户态）：
 * 用户态: wait()/waitpid() -> sys_wait() -> ecall指令 ->
 * 内核态: trap -> syscall() -> sys_wait() -> do_wait() ->
 *         [查找ZOMBIE子进程] -> [如无则睡眠] -> [回收资源] -> 返回 ->
 * 用户态: 返回子进程PID和退出码
 * 
 * 注意：只有在do_wait完成后，子进程的所有资源才被完全释放！
 */
int do_wait(int pid, int *code_store)
{
    struct mm_struct *mm = current->mm;
    
    // 验证用户空间指针的有效性
    if (code_store != NULL)
    {
        if (!user_mem_check(mm, (uintptr_t)code_store, sizeof(int), 1))
        {
            return -E_INVAL;
        }
    }

    struct proc_struct *proc;
    bool intr_flag, haskid;
    
repeat:  // 循环等待，直到找到ZOMBIE子进程
    haskid = 0;
    
    // 【关键修复】使用中断保护确保检查子进程状态和设置睡眠态是原子的
    // 避免竞态条件：子进程在检查完后、设置睡眠态前退出，导致父进程永远不被唤醒
    local_intr_save(intr_flag);
    {
        if (pid != 0)
        {
            // ========== 情况1: 等待指定PID的子进程 ==========
            proc = find_proc(pid);
            if (proc != NULL && proc->parent == current)
            {
                haskid = 1;  // 确认有这个子进程
                if (proc->state == PROC_ZOMBIE)
                {
                    local_intr_restore(intr_flag);
                    goto found;  // 子进程已退出，去回收
                }
            }
        }
        else
        {
            // ========== 情况2: 等待任意子进程 ==========
            proc = current->cptr;  // 遍历所有子进程
            for (; proc != NULL; proc = proc->optr)
            {
                haskid = 1;
                if (proc->state == PROC_ZOMBIE)
                {
                    local_intr_restore(intr_flag);
                    goto found;  // 找到已退出的子进程
                }
            }
        }
        
        // ========== 没有ZOMBIE子进程，进入睡眠等待 ==========
        if (haskid)
        {
            // 设置状态为SLEEPING，等待子进程退出唤醒
            // 在中断关闭状态下设置，确保不会错过子进程的唤醒
            current->state = PROC_SLEEPING;
            current->wait_state = WT_CHILD;
        }
    }
    local_intr_restore(intr_flag);
    
    if (haskid)
    {
        schedule();  // 让出CPU
        
        // 被唤醒后检查是否需要退出
        if (current->flags & PF_EXITING)
        {
            do_exit(-E_KILLED);
        }
        goto repeat;  // 重新检查
    }
    return -E_BAD_PROC;  // 没有子进程

found:
    // ========== 回收子进程资源 ==========
    if (proc == idleproc || proc == initproc)
    {
        panic("wait idleproc or initproc.\n");
    }
    
    // 获取子进程的退出码
    if (code_store != NULL)
    {
        *code_store = proc->exit_code;
    }
    
    // 从进程管理结构中移除
    local_intr_save(intr_flag);
    {
        unhash_proc(proc);    // 从哈希表移除
        remove_links(proc);   // 从进程树移除
    }
    local_intr_restore(intr_flag);
    
    // 释放最后的资源：内核栈和进程控制块
    put_kstack(proc);  // 释放内核栈
    kfree(proc);       // 释放proc结构
    
    return 0;
}

// do_kill - kill process with pid by set this process's flags with PF_EXITING
int do_kill(int pid)
{
    struct proc_struct *proc;
    if ((proc = find_proc(pid)) != NULL)
    {
        if (!(proc->flags & PF_EXITING))
        {
            proc->flags |= PF_EXITING;
            if (proc->wait_state & WT_INTERRUPTED)
            {
                wakeup_proc(proc);
            }
            return 0;
        }
        return -E_KILLED;
    }
    return -E_INVAL;
}

// kernel_execve - do SYS_exec syscall to exec a user program called by user_main kernel_thread
static int
kernel_execve(const char *name, unsigned char *binary, size_t size)
{
    int64_t ret = 0, len = strlen(name);
    //   ret = do_execve(name, len, binary, size);
    asm volatile(
        "li a0, %1\n"
        "lw a1, %2\n"
        "lw a2, %3\n"
        "lw a3, %4\n"
        "lw a4, %5\n"
        "li a7, 10\n"
        "ebreak\n"
        "sw a0, %0\n"
        : "=m"(ret)
        : "i"(SYS_exec), "m"(name), "m"(len), "m"(binary), "m"(size)
        : "memory");
    cprintf("ret = %d\n", ret);
    return ret;
}

#define __KERNEL_EXECVE(name, binary, size) ({           \
    cprintf("kernel_execve: pid = %d, name = \"%s\".\n", \
            current->pid, name);                         \
    kernel_execve(name, binary, (size_t)(size));         \
})

#define KERNEL_EXECVE(x) ({                                    \
    extern unsigned char _binary_obj___user_##x##_out_start[], \
        _binary_obj___user_##x##_out_size[];                   \
    __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,    \
                    _binary_obj___user_##x##_out_size);        \
})

#define __KERNEL_EXECVE2(x, xstart, xsize) ({   \
    extern unsigned char xstart[], xsize[];     \
    __KERNEL_EXECVE(#x, xstart, (size_t)xsize); \
})

#define KERNEL_EXECVE2(x, xstart, xsize) __KERNEL_EXECVE2(x, xstart, xsize)

// user_main - kernel thread used to exec a user program
static int
user_main(void *arg)
{
#ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    KERNEL_EXECVE(exit);
#endif
    panic("user_main execve failed.\n");
}

// init_main - the second kernel thread used to create user_main kernel threads
static int
init_main(void *arg)
{
    size_t nr_free_pages_store = nr_free_pages();
    size_t kernel_allocated_store = kallocated();

    int pid = kernel_thread(user_main, NULL, 0);
    if (pid <= 0)
    {
        panic("create user_main failed.\n");
    }

    while (do_wait(0, NULL) == 0)
    {
        schedule();
    }

    cprintf("all user-mode processes have quit.\n");
    assert(initproc->cptr == NULL && initproc->yptr == NULL && initproc->optr == NULL);
    assert(nr_process == 2);
    assert(list_next(&proc_list) == &(initproc->list_link));
    assert(list_prev(&proc_list) == &(initproc->list_link));

    cprintf("init check memory pass.\n");
    return 0;
}

// proc_init - set up the first kernel thread idleproc "idle" by itself and
//           - create the second kernel thread init_main
void proc_init(void)
{
    int i;

    list_init(&proc_list);
    for (i = 0; i < HASH_LIST_SIZE; i++)
    {
        list_init(hash_list + i);
    }

    if ((idleproc = alloc_proc()) == NULL)
    {
        panic("cannot alloc idleproc.\n");
    }

    idleproc->pid = 0;
    idleproc->state = PROC_RUNNABLE;
    idleproc->kstack = (uintptr_t)bootstack;
    idleproc->need_resched = 1;
    set_proc_name(idleproc, "idle");
    nr_process++;

    current = idleproc;

    int pid = kernel_thread(init_main, NULL, 0);
    if (pid <= 0)
    {
        panic("create init_main failed.\n");
    }

    initproc = find_proc(pid);
    set_proc_name(initproc, "init");

    assert(idleproc != NULL && idleproc->pid == 0);
    assert(initproc != NULL && initproc->pid == 1);
}

// cpu_idle - at the end of kern_init, the first kernel thread idleproc will do below works
void cpu_idle(void)
{
    while (1)
    {
        if (current->need_resched)
        {
            schedule();
        }
    }
}
