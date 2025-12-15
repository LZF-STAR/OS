/* 系统调用处理模块
 * 
 * 【练习3分析 - 系统调用机制】
 * 
 * 用户态与内核态的交互流程：
 * 
 * 用户态程序调用库函数（如fork()）
 *     ↓
 * 库函数准备参数，执行ecall指令
 *     ↓
 * CPU陷入内核态，跳转到__alltraps
 *     ↓
 * 保存上下文到trapframe
 *     ↓
 * 调用trap() -> exception_handler() -> syscall()
 *     ↓
 * 根据系统调用号分发到对应处理函数
 *     ↓
 * 执行内核操作（如do_fork）
 *     ↓
 * 返回值存入tf->gpr.a0
 *     ↓
 * 恢复上下文，执行sret返回用户态
 *     ↓
 * 用户态程序从a0寄存器获取返回值
 */

#include <unistd.h>
#include <proc.h>
#include <syscall.h>
#include <trap.h>
#include <stdio.h>
#include <pmm.h>
#include <assert.h>

/* sys_exit - 退出系统调用
 * 用户态: exit(code) -> 内核态: do_exit()
 * 注意：此调用永不返回
 */
static int
sys_exit(uint64_t arg[]) {
    int error_code = (int)arg[0];
    return do_exit(error_code);
}

/* sys_fork - 创建子进程系统调用
 * 用户态: fork() -> 内核态: do_fork()
 * 返回值: 父进程返回子进程PID，子进程返回0
 * 
 * 【COW集成】do_fork -> copy_mm -> copy_range 使用COW机制
 */
static int
sys_fork(uint64_t arg[]) {
    struct trapframe *tf = current->tf;
    uintptr_t stack = tf->gpr.sp;  // 获取用户栈指针
    return do_fork(0, stack, tf);   // clone_flags=0，复制内存空间（使用COW）
}

/* sys_wait - 等待子进程系统调用
 * 用户态: wait()/waitpid() -> 内核态: do_wait()
 * 可能阻塞直到有子进程退出
 */
static int
sys_wait(uint64_t arg[]) {
    int pid = (int)arg[0];
    int *store = (int *)arg[1];
    return do_wait(pid, store);
}

/* sys_exec - 执行新程序系统调用
 * 用户态: exec() -> 内核态: do_execve()
 * 成功后不返回，执行新程序
 */
static int
sys_exec(uint64_t arg[]) {
    const char *name = (const char *)arg[0];
    size_t len = (size_t)arg[1];
    unsigned char *binary = (unsigned char *)arg[2];
    size_t size = (size_t)arg[3];
    return do_execve(name, len, binary, size);
}

static int
sys_yield(uint64_t arg[]) {
    return do_yield();
}

static int
sys_kill(uint64_t arg[]) {
    int pid = (int)arg[0];
    return do_kill(pid);
}

static int
sys_getpid(uint64_t arg[]) {
    return current->pid;
}

static int
sys_putc(uint64_t arg[]) {
    int c = (int)arg[0];
    cputchar(c);
    return 0;
}

static int
sys_pgdir(uint64_t arg[]) {
    //print_pgdir();
    return 0;
}

/* 系统调用分发表
 * 根据系统调用号索引到对应的处理函数
 */
static int (*syscalls[])(uint64_t arg[]) = {
    [SYS_exit]              sys_exit,
    [SYS_fork]              sys_fork,
    [SYS_wait]              sys_wait,
    [SYS_exec]              sys_exec,
    [SYS_yield]             sys_yield,
    [SYS_kill]              sys_kill,
    [SYS_getpid]            sys_getpid,
    [SYS_putc]              sys_putc,
    [SYS_pgdir]             sys_pgdir,
};

#define NUM_SYSCALLS        ((sizeof(syscalls)) / (sizeof(syscalls[0])))

/* syscall - 系统调用分发函数
 * 
 * 【内核态执行结果返回机制】
 * 1. 从trapframe获取系统调用号（a0）和参数（a1-a5）
 * 2. 调用对应的处理函数
 * 3. 将返回值写回tf->gpr.a0
 * 4. 返回后，__trapret恢复寄存器，a0中的值就是用户态的返回值
 */
void
syscall(void) {
    struct trapframe *tf = current->tf;
    uint64_t arg[5];
    int num = tf->gpr.a0;  // 系统调用号
    
    if (num >= 0 && num < NUM_SYSCALLS) {
        if (syscalls[num] != NULL) {
            // 获取参数（RISC-V调用约定：a1-a5）
            arg[0] = tf->gpr.a1;
            arg[1] = tf->gpr.a2;
            arg[2] = tf->gpr.a3;
            arg[3] = tf->gpr.a4;
            arg[4] = tf->gpr.a5;
            
            // 调用处理函数，返回值存入a0
            tf->gpr.a0 = syscalls[num](arg);
            return ;
        }
    }
    print_trapframe(tf);
    panic("undefined syscall %d, pid = %d, name = %s.\n",
            num, current->pid, current->name);
}

