#include <defs.h>
#include <list.h>
#include <proc.h>
#include <assert.h>
#include <default_sched.h>

/*
 * ==================== Round-Robin (RR) 时间片轮转调度算法实现 ====================
 * 
 * 【算法概述】
 * RR调度算法是一种公平的调度算法，为每个进程分配相等的时间片。
 * 当进程的时间片用完后，将其放到队列尾部，选择队列头部的进程运行。
 * 
 * 【本文件用到的关键函数说明】
 * - list_init(list): 初始化双向循环链表，使prev和next都指向自己
 * - list_add_before(listelm, elm): 将elm插入到listelm之前
 * - list_del_init(listelm): 从链表中删除节点并重新初始化
 * - list_next(listelm): 获取链表中的下一个节点
 * - list_empty(list): 检查链表是否为空
 * - le2proc(le, member): 从链表节点指针获取包含它的进程控制块指针
 * - assert(condition): 断言检查，条件不满足时触发panic
 */

/*
 * 【函数】RR_init - 初始化RR调度器的运行队列
 * 【用途】在调度器初始化时被调用，设置运行队列的初始状态
 * 
 * 【概要设计思路】
 * RR调度使用双向循环链表作为就绪队列数据结构。
 * 初始化时需要：
 * 1. 将链表头节点初始化为空链表（prev和next都指向自己）
 * 2. 将进程计数器清零
 * 
 * 【参数】
 * - rq: 指向运行队列结构体的指针
 */
static void
RR_init(struct run_queue *rq)
{
    // LAB6: 2311474
    
    // list_init: libs/list.h中定义的链表初始化函数
    // 作用: 将链表节点的prev和next指针都指向自己，形成空的循环链表
    // 这样后续可以通过检查 list_next(&rq->run_list) == &rq->run_list 判断队列是否为空
    list_init(&(rq->run_list));
    
    // 初始化进程计数为0，表示当前运行队列中没有等待调度的进程
    rq->proc_num = 0;
}

/*
 * 【函数】RR_enqueue - 将进程加入RR调度器的运行队列
 * 【用途】当进程变为就绪态时（如被唤醒、时间片用完重新入队），将其加入队列尾部
 * 
 * 【概要设计思路】
 * RR是FIFO式公平调度，新就绪的进程应该排在队列尾部等待：
 * 1. 首先检查进程不在任何队列中（防止重复入队）
 * 2. 使用list_add_before将进程插入到头节点之前（即队列尾部）
 * 3. 如果进程时间片为0或异常值，重置为最大时间片
 * 4. 更新进程的运行队列指针和队列计数
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * - proc: 指向要入队的进程控制块的指针
 */
static void
RR_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: 2311474
    
    // assert + list_empty: 断言检查进程的run_link节点是空的
    // list_empty检查节点的prev和next是否都指向自己（即未加入任何链表）
    // 用途: 确保同一个进程不会被重复加入运行队列，防止链表结构被破坏
    assert(list_empty(&(proc->run_link)));
    
    // list_add_before: libs/list.h中定义的链表插入函数
    // 作用: 将第二个参数指向的节点插入到第一个参数指向的节点之前
    // 原理: 对于循环双向链表，头节点(run_list)的"前面"就是队列的尾部
    // 示例: 假设队列为 HEAD <-> A <-> B <-> HEAD
    //       list_add_before(&HEAD, &C) 后变为 HEAD <-> A <-> B <-> C <-> HEAD
    // 效果: 实现了FIFO队列的入队操作（从尾部入队）
    list_add_before(&(rq->run_list), &(proc->run_link));
    
    // 时间片处理逻辑:
    // - 如果time_slice为0: 说明进程刚用完时间片被调度出去，需要重新分配
    // - 如果time_slice大于max_time_slice: 异常情况，可能是未初始化，需要修正
    // 两种情况都将时间片重置为最大值，保证进程获得完整的运行周期
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
        proc->time_slice = rq->max_time_slice;
    }
    
    // 设置进程所属的运行队列指针
    // 用途: 后续dequeue时可以验证进程确实属于这个队列
    proc->rq = rq;
    
    // 增加运行队列的进程计数，用于统计和调试
    rq->proc_num++;
}

/*
 * 【函数】RR_dequeue - 将进程从RR调度器的运行队列中移除
 * 【用途】当进程被选中即将运行时，需要将其从就绪队列中移除
 * 
 * 【概要设计思路】
 * 从链表中删除进程节点并更新计数：
 * 1. 首先验证进程确实在队列中且属于当前队列
 * 2. 使用list_del_init将进程从链表中删除并重新初始化节点
 * 3. 更新队列计数
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * - proc: 指向要出队的进程控制块的指针
 */
static void
RR_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: 2311474
    
    // assert: 双重断言检查
    // 1. !list_empty(&(proc->run_link)): 确保进程的run_link不为空，即确实在某个队列中
    // 2. proc->rq == rq: 确保进程所属的队列就是当前操作的队列rq
    // 用途: 防止错误地从错误的队列中删除进程，或删除不在队列中的进程
    assert(!list_empty(&(proc->run_link)) && proc->rq == rq);
    
    // list_del_init: libs/list.h中定义的链表删除函数
    // 作用: 将节点从链表中删除，并将该节点重新初始化为空节点
    // 原理: 
    //   1. 修改前驱节点的next指向后继节点
    //   2. 修改后继节点的prev指向前驱节点
    //   3. 将当前节点的prev和next都指向自己（初始化为空）
    // 好处: 删除后节点处于干净状态，可以安全地再次入队而不会破坏链表结构
    list_del_init(&(proc->run_link));
    
    // 减少运行队列的进程计数
    rq->proc_num--;
}

/*
 * 【函数】RR_pick_next - 从运行队列中选择下一个要运行的进程
 * 【用途】在schedule()函数中被调用，选择队首进程作为下一个运行的进程
 * 
 * 【概要设计思路】
 * RR调度的核心思想是FIFO，总是选择最早入队（等待时间最长）的进程：
 * 1. 获取链表头的下一个节点（即队首元素）
 * 2. 检查队列是否为空（下一个节点是否就是头节点本身）
 * 3. 使用le2proc宏从链表节点获取进程控制块指针
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * 
 * 【返回值】
 * - 成功: 返回队首进程的proc_struct指针
 * - 队列为空: 返回NULL
 */
static struct proc_struct *
RR_pick_next(struct run_queue *rq)
{
    // LAB6: 2311474
    
    // list_next: libs/list.h中定义的宏，获取链表中指定节点的后继节点
    // 原理: 返回 elm->next
    // 这里获取run_list头节点的下一个节点，即队列中的第一个进程
    // 队列结构示意: HEAD <-> proc1 <-> proc2 <-> ... <-> HEAD
    //              list_next(&HEAD) 返回 proc1 的 run_link
    list_entry_t *le = list_next(&(rq->run_list));
    
    // 边界条件检查：判断队列是否为空
    // 原理: 对于循环双向链表，如果 list_next(&HEAD) == &HEAD
    //       说明头节点的下一个就是自己，即链表中只有头节点，队列为空
    if (le != &(rq->run_list)) {
        // le2proc: kern/process/proc.h中定义的宏
        // 用途: 从链表节点指针获取包含该节点的进程控制块指针
        // 原理: 使用offsetof计算run_link成员在proc_struct中的偏移
        //       然后用链表节点地址减去偏移得到结构体起始地址
        // 参数: le - 链表节点指针, run_link - 节点在proc_struct中的成员名
        // 展开: to_struct(le, struct proc_struct, run_link)
        return le2proc(le, run_link);
    }
    
    // 队列为空，没有可调度的进程，返回NULL
    // 调用者（schedule函数）会检查返回值，如果为NULL则运行idle进程
    return NULL;
}

/*
 * 【函数】RR_proc_tick - 处理时钟中断，更新进程时间片
 * 【用途】每次时钟中断时被调用，减少当前运行进程的时间片，用尽时触发调度
 * 
 * 【概要设计思路】
 * 时间片轮转的核心机制：
 * 1. 每次时钟中断减少当前进程的时间片计数
 * 2. 当时间片减为0时，设置need_resched标志
 * 3. 该标志会在中断返回前被检查，触发schedule()进行进程切换
 * 
 * 【参数】
 * - rq: 指向运行队列的指针（本函数未使用，保持接口一致性）
 * - proc: 指向当前运行进程的指针
 * 
 * 【注意】
 * 这是实现抢占式调度的关键函数，通过need_resched标志实现间接调度
 */
static void
RR_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
    // LAB6: 2311474
    
    // 首先检查时间片是否大于0，防止减成负数
    // 虽然理论上不应该出现time_slice为负的情况，但这是一个安全检查
    if (proc->time_slice > 0) {
        // 时间片减1，表示进程又消耗了一个时钟周期的CPU时间
        // 一个时间片通常对应一次时钟中断的间隔
        proc->time_slice--;
    }
    
    // 检查时间片是否用尽
    if (proc->time_slice == 0) {
        // need_resched: 进程控制块中的调度标志位
        // 用途: 标记该进程需要被调度（让出CPU给其他进程）
        // 
        // 【为什么不在这里直接调用schedule()？】
        // 1. 当前处于中断上下文中，直接调度可能导致问题
        // 2. 需要等待中断处理完成后，在安全的时机进行调度
        // 3. trap返回前会检查此标志，如果为1则调用schedule()
        // 
        // 这是实现抢占式调度的关键：
        // 时钟中断 -> proc_tick设置标志 -> 中断返回前检查 -> schedule()
        proc->need_resched = 1;
    }
}

/*
 * 【RR调度类结构体】
 * 将上述函数打包成一个调度类，供调度框架使用
 * 通过函数指针实现多态，使得调度框架可以使用不同的调度算法
 */
struct sched_class default_sched_class = {
    .name = "RR_scheduler",      // 调度器名称，用于标识和调试输出
    .init = RR_init,             // 初始化函数
    .enqueue = RR_enqueue,       // 入队函数
    .dequeue = RR_dequeue,       // 出队函数
    .pick_next = RR_pick_next,   // 选择下一个进程函数
    .proc_tick = RR_proc_tick,   // 时钟中断处理函数
};
