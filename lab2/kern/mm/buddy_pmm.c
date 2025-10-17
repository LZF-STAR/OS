#include <pmm.h>
#include <list.h>
#include <string.h>
#include <buddy_pmm.h>
#include <stdio.h>

/* ============================================================================
 * Buddy System 物理内存管理器实现
 * 
 * 核心思想：
 * 1. 内存块大小为2的幂次方（2^0, 2^1, 2^2, ..., 2^MAX_ORDER页）
 * 2. 每个大小级别维护一个空闲链表
 * 3. 分配时找到最小满足需求的块，必要时拆分大块
 * 4. 释放时尝试与伙伴块合并，形成更大的块
 * 
 * 数据结构：
 * - buddy_free_area: 包含MAX_ORDER个链表，free_list[i]存储2^i大小的空闲块
 * - Page.property: 记录该块的阶数（order），2^order = 块大小
 * 
 * 学号：2311474
 * ============================================================================ */

/* 全局变量：Buddy System的空闲区域管理器 */
static buddy_free_area_t buddy_free_area;

/* 宏定义：简化代码 */
#define free_list(order) (buddy_free_area.free_list[order])
#define nr_free(order) (buddy_free_area.nr_free[order])

/* ============================================================================
 * 辅助函数：计算需要的阶数
 * 
 * 功能：给定需要n个页面，计算最小的order使得2^order >= n
 * 
 * 参数：
 *   n - 需要的页面数
 * 
 * 返回：
 *   需要的阶数order
 * 
 * 示例：
 *   n=1  -> order=0 (2^0=1)
 *   n=2  -> order=1 (2^1=2)
 *   n=3  -> order=2 (2^2=4)
 *   n=5  -> order=3 (2^3=8)
 * ============================================================================ */
size_t buddy_get_order(size_t n) {
    size_t order = 0;
    size_t size = 1;
    
    // 不断将size翻倍，直到size >= n
    while (size < n) {
        size <<= 1;  // size *= 2
        order++;
    }
    
    return order;
}

/* ============================================================================
 * 辅助函数：计算伙伴页的索引
 * 
 * 功能：给定一个页的索引和阶数，计算其伙伴页的索引
 * 
 * 伙伴关系：
 *   - 两个大小相同的块
 *   - 物理地址相邻
 *   - 地址对齐到2^(order+1)边界
 * 
 * 计算公式：
 *   buddy_index = index XOR (1 << order)
 * 
 * 示例（order=1，块大小=2页）：
 *   index=0 -> buddy=2   (0 XOR 2 = 2)
 *   index=2 -> buddy=0   (2 XOR 2 = 0)
 *   index=4 -> buddy=6   (4 XOR 2 = 6)
 * ============================================================================ */
size_t buddy_get_buddy_index(size_t index, size_t order) {
    return index ^ (1 << order);
}

/* ============================================================================
 * 函数：buddy_init
 * 
 * 功能：初始化Buddy System的数据结构
 * 
 * 实现步骤：
 *   1. 初始化所有阶的空闲链表（MAX_ORDER个链表）
 *   2. 将所有阶的空闲块计数器清零
 * 
 * 调用时机：pmm_init() -> init_pmm_manager() -> buddy_init()
 * 
 * 学号：2311474
 * ============================================================================ */
static void buddy_init(void) {
    // 遍历所有阶数，初始化每个阶的空闲链表和计数器
    for (int i = 0; i < MAX_ORDER; i++) {
        list_init(&free_list(i));  // 初始化链表为空
        nr_free(i) = 0;             // 空闲块数量置0
    }
    
    cprintf("Buddy System initialized: MAX_ORDER=%d\n", MAX_ORDER);
}

/* ============================================================================
 * 函数：buddy_init_memmap
 * 
 * 功能：将一块连续的物理内存初始化并加入Buddy System管理
 * 
 * 参数：
 *   base - 起始页面指针
 *   n    - 连续页面的数量
 * 
 * 实现策略：
 *   由于n可能不是2的幂次，需要将其拆分成多个2的幂次块
 *   例如：n=13页 = 8页 + 4页 + 1页 = 2^3 + 2^2 + 2^0
 * 
 * 实现步骤：
 *   1. 初始化所有页面的基本属性
 *   2. 从高阶到低阶，尽可能分配大块
 *   3. 将每个块加入对应阶的空闲链表
 * 
 * 调用链：
 *   kern_init() -> pmm_init() -> page_init() -> init_memmap() 
 *   -> pmm_manager->init_memmap() -> buddy_init_memmap()
 * 
 * 学号：2311474
 * ============================================================================ */
static void buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    cprintf("Buddy init_memmap: base=%p, n=%d pages\n", base, n);
    
    /* ========== 第一步：初始化所有页面的基本属性 ========== */
    struct Page *p = base;
    for (; p != base + n; p++) {
        assert(PageReserved(p));  // 确保页面之前是保留状态
        
        /*LAB2 CHALLENGE1: 2311474*/
        // 清空页面的标志位和属性
        p->flags = 0;              // 清除所有标志（Reserved, Property等）
        p->property = 0;           // 清空property（稍后只在块首页设置）
        set_page_ref(p, 0);        // 引用计数置0（未被使用）
    }
    
    /* ========== 第二步：将n个页面拆分成2的幂次块 ========== */
    size_t remaining = n;          // 剩余待分配的页面数
    size_t current_index = 0;      // 当前处理到的页面索引
    
    // 从高阶到低阶遍历，尽量分配大块（减少碎片）
    for (int order = MAX_ORDER - 1; order >= 0; order--) {
        size_t block_size = (1 << order);  // 当前阶对应的块大小：2^order
        
        // 当剩余页面数 >= 当前块大小时，可以分配这个阶的块
        while (remaining >= block_size) {
            /*LAB2 CHALLENGE1: 2311474*/
            // 获取当前块的首页指针
            struct Page *page = base + current_index;
            
            // 设置块首页的property为当前阶数
            page->property = order;
            
            // 标记这是一个空闲块的首页
            SetPageProperty(page);
            
            // 将该块加入对应阶的空闲链表尾部
            list_add_before(&free_list(order), &(page->page_link));
            
            // 更新该阶的空闲块计数
            nr_free(order)++;
            
            // 更新索引和剩余页面数
            current_index += block_size;
            remaining -= block_size;
            
            cprintf("  Added block: order=%d, size=%d pages, page=%p\n", 
                    order, block_size, page);
        }
    }
    
    /* ========== 第三步：输出初始化结果 ========== */
    cprintf("Buddy init_memmap completed:\n");
    for (int i = 0; i < MAX_ORDER; i++) {
        if (nr_free(i) > 0) {
            cprintf("  Order %d: %d blocks (each %d pages)\n", 
                    i, nr_free(i), (1 << i));
        }
    }
}

/* ============================================================================
 * 函数：buddy_nr_free_pages
 * 
 * 功能：计算Buddy System中总的空闲页面数
 * 
 * 实现：遍历所有阶，累加 nr_free[i] * 2^i
 * 
 * 学号：2311474
 * ============================================================================ */
static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    
    // 遍历所有阶
    for (int i = 0; i < MAX_ORDER; i++) {
        // 该阶的空闲页数 = 块数量 * 每块页数
        total += nr_free(i) * (1 << i);
    }
    
    return total;
}

/* ============================================================================
 * 以下函数由队友实现
 * ============================================================================ */

/* 分配函数：由队友实现 */
/* ============================================================================
 * 函数：buddy_alloc_pages
 * 
 * 功能：从Buddy System分配n个页面
 * 
 * 参数：
 *   n - 请求的页面数
 * 
 * 返回：
 *   成功：指向分配块首页的指针
 *   失败：NULL（请求过大或没有能满足要求的空闲块）
 * 
 * 算法流程：
 *   1. 计算需要的阶数 order，使得 2^order >= n
 *   2. 从 order 开始向上查找第一个非空链表
 *   3. 如果找到的块阶数大于 order，递归拆分至目标大小
 *   4. 返回分配的页面指针
 * 
 * 示例：
 *   请求 3 页 -> order=2 (2^2=4页)
 *   如果 order 2 链表为空，但 order 3 有 8 页块：
 *     - 拆分 8 页 -> [4页] + [4页]
 *     - 分配左边 4 页，右边 4 页放回 order 2 链表
 * 
 * 学号：2310764
 * ============================================================================ */

static struct Page *buddy_alloc_pages(size_t n) {
    assert(n > 0);
    // 所需要的阶数
    size_t order = buddy_get_order(n);
    if(order >= MAX_ORDER){ // 最大阶数只有到 MAX_ORDER - 1
        cprintf("buddy_alloc_pages: request too large (order %d >= MAX_ORDER %d)\n", 
            order, MAX_ORDER);
        return NULL;
    }

    size_t current_order = order;
    struct Page *page = NULL;

    // 向上找到第一个大小足够的的order
    for(; current_order <  MAX_ORDER; current_order++){
        if(!list_empty(&free_list(current_order))){
            // 找到符合的，将其移出空闲链表
            list_entry_t *le = list_next(&free_list(current_order));
            page = le2page(le, page_link);
            
            // 维护空闲链表以及空闲块数量
            list_del(le);
            nr_free(current_order)--;

            // 不空闲了
            ClearPageProperty(page);

            cprintf("  Found block at order %d\n", current_order);
            break;
        }
    }
    // 没找到可用的块
    if (page == NULL) {
        cprintf("buddy_alloc_pages: no available memory\n");
        return page;
    }


    // 调用split不断拆分直到阶数为order。
    for(; current_order > order; current_order--){
        page = split(page);
    }


    // 调试信息
    cprintf("buddy_alloc_pages: allocated %d pages at %p\n", (1 << order), page);
    return page;  
}

/* ============================================================================
 * 函数：split
 * 
 * 功能：将一个块拆分成两个大小相等的伙伴块
 * 
 * 参数：
 *   page - 待拆分块的首页指针（必须是块首页，且page->property > 0）
 * 
 * 返回：
 *   拆分后左半部分的首页指针（用于分配或继续拆分）
 * 
 * 实现逻辑：
 *   1. 计算右半部分的起始位置
 *   2. 初始化右半部分并加入空闲链表
 *   3. 更新左半部分的属性
 *   4 返回左半部分
 * 
 * 内存布局示例：
 *   拆分前 (order=3, 8页)：
 *   [PPPPPPPP]
 *    ↑
 *    page
 *   
 *   拆分后 (order=2, 各4页)：
 *   [PPPP][FFFF]
 *    ↑    ↑
 *    返回  free_half (加入链表)
 * 
 * 
 * 注意事项：
 *   - 拆分前的阶数必须 >= 1 且< MAX_ORDER
 * 
 * 学号：2310764
 * ============================================================================ */
static struct Page *split(struct  Page *page)
{
    // 把当前页拆分成两个页， 其中一个返回，另一个放入空闲页表
    size_t order = page->property;
    // order一定是 >= 1  < MAX_ORDER 的。
    assert(order >= 1 && order < MAX_ORDER);
    // 位运算貌似比除法快...
    size_t cur_order = order - 1;

    // 处理空闲的半边，加入空闲链表
    struct Page *free_half = page +  (1 << cur_order);  
    free_half->property = cur_order;
    SetPageProperty(free_half);
    list_add(&free_list(cur_order), &free_half->page_link);
    nr_free(cur_order)++;

    // 更新property, 返回被使用的左半边
    page->property = cur_order;
    cprintf("  Split: order %d -> two order %d blocks\n", 
               order , cur_order);

    return page;
};




/* 释放函数：由队友实现 */
static void buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    
    /* TODO: 队友在这里实现释放逻辑
     * 
     * 实现步骤提示：
     * 1. 计算块的阶数：order = buddy_get_order(n)
     * 2. 清空页面属性，重新初始化
     * 3. 尝试与伙伴块合并（递归向上合并）
     *    - 计算伙伴索引：buddy_get_buddy_index()
     *    - 检查伙伴块是否空闲且同阶
     *    - 如果可以合并，从链表移除两个块，合并成更大的块
     * 4. 将最终的块加入对应阶的链表
     * 
     * 参考：可以查看default_free_pages的合并逻辑
     */
    
    cprintf("buddy_free_pages: TODO - implement by teammate\n");
}

/* 测试函数：由队友实现 */
static void buddy_check(void) {
    /* TODO: 队友在这里实现测试用例
     * 
     * 测试内容建议：
     * 1. 基本分配和释放
     * 2. 块的拆分和合并
     * 3. 边界情况（分配最大块、最小块）
     * 4. 内存碎片测试
     * 
     * 参考：可以查看best_fit_check()的测试结构
     */
    
    cprintf("buddy_check: TODO - implement by teammate\n");
}

/* ============================================================================
 * PMM Manager结构体定义
 * 
 * 说明：将Buddy System的各个函数注册到pmm_manager框架中
 * ============================================================================ */
const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,      // 队友实现
    .free_pages = buddy_free_pages,        // 队友实现
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,                  // 队友实现
};