#include <defs.h>
#include <list.h>
#include <proc.h>
#include <assert.h>
#include <default_sched.h>
#include <stdio.h>
#include <skew_heap.h>

/*
 * ==================== Stride Scheduling 步进调度算法实现 ====================
 * 
 * 【算法概述】
 * Stride调度是一种确定性的比例份额调度算法，能够根据进程优先级
 * 精确地按比例分配CPU时间。优先级越高的进程获得越多的CPU时间。
 * 
 * 【核心思想】
 * 1. 每个进程有一个stride值（步进值）和priority值（优先级）
 * 2. 每次调度选择stride最小的进程运行
 * 3. 被选中的进程stride增加: stride += BIG_STRIDE / priority
 * 4. 优先级高的进程，步长小，stride增长慢，更容易被再次选中
 * 
 * 【本文件用到的关键函数说明】
 * - skew_heap_insert(heap, node, comp): 将节点插入斜堆，返回新堆根
 * - skew_heap_remove(heap, node, comp): 从斜堆删除节点，返回新堆根
 * - le2proc(le, member): 从结构体成员指针获取结构体指针
 * - list_init/list_add_before/list_del_init: 链表操作（备选实现）
 */

// USE_SKEW_HEAP: 编译选项，决定使用斜堆还是链表实现
// 斜堆: O(log n) 查找最小元素，适合进程数量多的情况
// 链表: O(n) 查找最小元素，实现简单
#define USE_SKEW_HEAP 1

/* 
 * 【常量】BIG_STRIDE - Stride调度算法中的大步长常量
 * 
 * 【设计思路】
 * stride值会不断累加，可能发生32位无符号整数溢出。
 * 为了正确比较两个可能溢出的stride值，我们使用有符号减法：
 *   (int32_t)(stride_a - stride_b)
 * 
 * 【数学证明】
 * 设 PASS_MAX = max{BIG_STRIDE / priority_i}，有：
 *   STRIDE_MAX - STRIDE_MIN <= PASS_MAX <= BIG_STRIDE (当priority >= 1)
 * 
 * 为保证 (stride_a - stride_b) 的结果在int32_t范围内：
 *   |stride_a - stride_b| <= 0x7FFFFFFF
 * 
 * 因此 BIG_STRIDE 应取 0x7FFFFFFF（32位有符号整数最大值）
 */
/* LAB6 2311474 */
#define BIG_STRIDE 0x7FFFFFFF

/*
 * 【函数】proc_stride_comp_f - 斜堆的比较函数
 * 【用途】比较两个进程的stride值，用于维护斜堆的最小堆性质
 * 
 * 【原理】
 * 使用有符号整数减法处理溢出问题：
 * 即使stride值溢出，只要差值在int32范围内，比较结果仍然正确
 * 
 * 【参数】
 * - a, b: 指向skew_heap_entry_t的指针
 * 
 * 【返回值】
 * - 正数: a的stride > b的stride
 * - 0: 相等
 * - 负数: a的stride < b的stride
 */
static int
proc_stride_comp_f(void *a, void *b)
{
     // le2proc: 从斜堆节点指针获取进程控制块指针
     // lab6_run_pool: 进程控制块中的斜堆节点成员名
     struct proc_struct *p = le2proc(a, lab6_run_pool);
     struct proc_struct *q = le2proc(b, lab6_run_pool);
     
     // 【关键】使用int32_t进行有符号减法
     // 原理: 无符号减法结果转为有符号后，可以正确反映逻辑大小关系
     // 例如: 无符号 98 - 65535 会得到一个很大的正数（溢出）
     //       但 (int32_t)(98 - 65535) = 99（正确的逻辑差值）
     //       说明在stride含义下，98 实际上"大于" 65535（因为65535已经溢出绕回了）
     int32_t c = p->lab6_stride - q->lab6_stride;
     
     // 返回比较结果给斜堆使用
     if (c > 0)
          return 1;   // p的stride更大，应该排在后面
     else if (c == 0)
          return 0;   // 相等
     else
          return -1;  // p的stride更小，应该排在前面（更优先）
}

/*
 * 【函数】stride_init - 初始化Stride调度器的运行队列
 * 【用途】在调度器初始化时被调用，设置运行队列的初始状态
 * 
 * 【概要设计思路】
 * Stride调度使用斜堆（skew heap）作为优先队列，快速获取stride最小的进程。
 * 初始化时需要：
 * 1. 初始化链表（备选实现或其他用途）
 * 2. 将斜堆根指针设为NULL（空堆）
 * 3. 将进程计数器清零
 * 
 * 【参数】
 * - rq: 指向运行队列结构体的指针
 */
static void
stride_init(struct run_queue *rq)
{
     /* LAB6 2311474 */
     
     // list_init: 初始化双向循环链表
     // 虽然使用斜堆实现，但仍初始化链表以保持数据结构一致性
     // 也可用于备选的链表实现（当USE_SKEW_HEAP=0时）
     list_init(&(rq->run_list));
     
     // lab6_run_pool: 斜堆的根节点指针
     // 设为NULL表示空堆，斜堆不需要额外的初始化操作
     // 斜堆是一种自平衡的堆结构，插入和删除时自动维护堆性质
     rq->lab6_run_pool = NULL;
     
     // 初始化进程计数为0
     rq->proc_num = 0;
}

/*
 * 【函数】stride_enqueue - 将进程加入Stride调度器的运行队列
 * 【用途】当进程变为就绪态时，将其加入斜堆优先队列
 * 
 * 【概要设计思路】
 * 使用斜堆维护就绪进程，保证能快速获取stride最小的进程：
 * 1. 使用skew_heap_insert将进程的斜堆节点插入堆中
 * 2. 斜堆会自动根据比较函数维护最小堆性质
 * 3. 初始化进程的时间片
 * 4. 更新进程的运行队列指针和队列计数
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * - proc: 指向要入队的进程控制块的指针
 */
static void
stride_enqueue(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 2311474 */
     
#if USE_SKEW_HEAP
     // ========== 斜堆实现 ==========
     // skew_heap_insert: libs/skew_heap.h中定义的斜堆插入函数
     // 
     // 【函数原型】
     // skew_heap_entry_t *skew_heap_insert(
     //     skew_heap_entry_t *a,  // 当前堆的根节点
     //     skew_heap_entry_t *b,  // 要插入的节点
     //     compare_f comp         // 比较函数
     // );
     // 
     // 【返回值】插入后新的堆根节点指针（可能改变）
     // 
     // 【原理】斜堆通过合并操作实现插入，时间复杂度O(log n)摊还
     // 插入后自动维护最小堆性质（根节点stride最小）
     rq->lab6_run_pool = skew_heap_insert(rq->lab6_run_pool, 
                                          &(proc->lab6_run_pool), 
                                          proc_stride_comp_f);
#else
     // ========== 链表实现（备选方案）==========
     // 使用链表时，入队操作简单但pick_next需要O(n)遍历
     list_add_before(&(rq->run_list), &(proc->run_link));
#endif

     // 时间片处理（与RR相同）
     // Stride调度同样使用时间片限制单次运行时间
     // 如果时间片为0或异常值，重置为最大时间片
     if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
          proc->time_slice = rq->max_time_slice;
     }
     
     // 设置进程所属的运行队列指针
     proc->rq = rq;
     
     // 增加进程计数
     rq->proc_num++;
}

/*
 * 【函数】stride_dequeue - 将进程从Stride调度器的运行队列中移除
 * 【用途】当进程被选中即将运行时，需要将其从斜堆中移除
 * 
 * 【概要设计思路】
 * 使用skew_heap_remove从斜堆中删除指定节点：
 * 1. 斜堆支持O(log n)的任意节点删除
 * 2. 删除后堆会自动重新平衡
 * 3. 更新队列计数
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * - proc: 指向要出队的进程控制块的指针
 */
static void
stride_dequeue(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 2311474 */
     
#if USE_SKEW_HEAP
     // ========== 斜堆实现 ==========
     // skew_heap_remove: libs/skew_heap.h中定义的斜堆删除函数
     // 
     // 【函数原型】
     // skew_heap_entry_t *skew_heap_remove(
     //     skew_heap_entry_t *a,  // 当前堆的根节点
     //     skew_heap_entry_t *b,  // 要删除的节点
     //     compare_f comp         // 比较函数
     // );
     // 
     // 【返回值】删除后新的堆根节点指针（可能改变，可能为NULL）
     // 
     // 【原理】删除节点后，将其左右子树合并，重新维护堆性质
     rq->lab6_run_pool = skew_heap_remove(rq->lab6_run_pool, 
                                          &(proc->lab6_run_pool), 
                                          proc_stride_comp_f);
#else
     // ========== 链表实现（备选方案）==========
     // 断言检查进程确实在队列中
     assert(!list_empty(&(proc->run_link)) && proc->rq == rq);
     // 从链表中删除并重新初始化节点
     list_del_init(&(proc->run_link));
#endif

     // 减少进程计数
     rq->proc_num--;
}
/*
 * 【函数】stride_pick_next - 从运行队列中选择stride最小的进程
 * 【用途】在schedule()函数中被调用，选择下一个运行的进程并更新其stride
 * 
 * 【概要设计思路】
 * Stride调度的核心逻辑：
 * 1. 选择stride值最小的进程（使用斜堆时直接取根节点）
 * 2. 更新被选中进程的stride值: stride += BIG_STRIDE / priority
 * 3. 返回被选中的进程
 * 
 * 【优先级与stride的关系】
 * - pass（步长）= BIG_STRIDE / priority
 * - 优先级越高 -> 步长越小 -> stride增长越慢 -> 更容易被再次选中
 * - 这样实现了CPU时间与优先级成正比的分配
 * 
 * 【参数】
 * - rq: 指向运行队列的指针
 * 
 * 【返回值】
 * - 成功: 返回stride最小的进程的proc_struct指针
 * - 队列为空: 返回NULL
 */
static struct proc_struct *
stride_pick_next(struct run_queue *rq)
{
     /* LAB6 2311474 */
     
#if USE_SKEW_HEAP
     // ========== 斜堆实现 ==========
     
     // 检查斜堆是否为空
     if (rq->lab6_run_pool == NULL) {
          return NULL;
     }
     
     // 斜堆的性质：根节点就是最小元素
     // 直接从根节点获取stride最小的进程，时间复杂度O(1)
     // 
     // le2proc: 从斜堆节点指针获取进程控制块指针
     // lab6_run_pool: 斜堆节点在proc_struct中的成员名
     struct proc_struct *p = le2proc(rq->lab6_run_pool, lab6_run_pool);
#else
     // ========== 链表实现（备选方案）==========
     // 需要O(n)遍历找到stride最小的进程
     
     list_entry_t *le = list_next(&(rq->run_list));
     // 检查链表是否为空
     if (le == &(rq->run_list)) {
          return NULL;
     }
     
     // 初始化：假设第一个进程是stride最小的
     struct proc_struct *p = le2proc(le, run_link);
     le = list_next(le);
     
     // 遍历链表，找到stride最小的进程
     while (le != &(rq->run_list)) {
          struct proc_struct *q = le2proc(le, run_link);
          // 使用有符号比较处理溢出
          // 如果q的stride小于p的stride，则更新p
          if ((int32_t)(q->lab6_stride - p->lab6_stride) < 0) {
               p = q;
          }
          le = list_next(le);
     }
#endif

     // 【关键】更新被选中进程的stride值
     // 公式: stride += pass = BIG_STRIDE / priority
     // 
     // 边界处理: 如果优先级为0（未设置或非法值）
     // 则步长设为BIG_STRIDE，相当于最低优先级
     if (p->lab6_priority == 0) {
          // 优先级为0时，给最大步长
          // 这样该进程的stride增长最快，最不容易被再次选中
          p->lab6_stride += BIG_STRIDE;
     } else {
          // 正常情况：步长与优先级成反比
          // 优先级越高（数值越大），步长越小，stride增长越慢
          // 增长慢的进程更容易保持stride最小，从而更频繁地被调度
          p->lab6_stride += BIG_STRIDE / p->lab6_priority;
     }
     
     return p;
}

/*
 * 【函数】stride_proc_tick - 处理时钟中断，更新进程时间片
 * 【用途】每次时钟中断时被调用，减少当前运行进程的时间片
 * 
 * 【概要设计思路】
 * 与RR调度相同的时间片机制：
 * 1. 每次时钟中断减少当前进程的时间片
 * 2. 时间片用尽时设置need_resched标志触发调度
 * 3. 这保证了进程不会无限占用CPU
 * 
 * 【注意】
 * Stride调度的"按比例分配"是通过多次调度实现的，
 * 每次调度后进程运行一个时间片，时间片大小对所有进程相同
 * 
 * 【参数】
 * - rq: 指向运行队列的指针（本函数未使用）
 * - proc: 指向当前运行进程的指针
 */
static void
stride_proc_tick(struct run_queue *rq, struct proc_struct *proc)
{
     /* LAB6 2311474 */
     
     // 如果时间片大于0，减少时间片
     // 每次时钟中断表示进程消耗了一个时钟周期的CPU时间
     if (proc->time_slice > 0) {
          proc->time_slice--;
     }
     
     // 如果时间片用尽，设置调度标志
     // need_resched标志会在trap返回前被检查，触发schedule()
     if (proc->time_slice == 0) {
          proc->need_resched = 1;
     }
}

/*
 * 【Stride调度类结构体】
 * 将上述函数打包成一个调度类，供调度框架使用
 * 通过修改sched.c中的sched_class指针可以切换到此调度器
 */
struct sched_class stride_sched_class = {
    .name = "stride_scheduler",    // 调度器名称
    .init = stride_init,           // 初始化函数
    .enqueue = stride_enqueue,     // 入队函数
    .dequeue = stride_dequeue,     // 出队函数
    .pick_next = stride_pick_next, // 选择下一个进程函数
    .proc_tick = stride_proc_tick, // 时钟中断处理函数
};
