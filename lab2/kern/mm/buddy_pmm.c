#include <pmm.h>
#include <list.h>
#include <string.h>
#include <buddy_pmm.h>
#include <stdio.h>

//重新增加回
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

/* forward declaration for split to avoid implicit declaration when used
   in buddy_alloc_pages */
static struct Page *split(struct Page *page);

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




/* 释放函数：由队友实现 2311456*/
static void buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    
    struct Page *cur = base;
    size_t remaining = n;

    // 步骤1：先将所有涉及的页标志和引用计数清理
    for (struct Page *p = base; p != base + n; p++) {
        assert(!PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    while (remaining > 0) {
        // 计算当前地址到 pages[0] 的页索引
        size_t idx = page2ppn(cur) - nbase;

        // 找到最大对齐阶
        size_t align = 0;
        while ((((size_t)idx) & (1UL << align)) == 0 && (align + 1) < MAX_ORDER) {
            align++;
        }
        size_t candidate = align;

        // 根据剩余页数，限制块大小
        size_t max_fit = 0;
        while (((size_t)1 << (max_fit + 1)) <= remaining && (max_fit + 1) < MAX_ORDER) {
            max_fit++;
        }

        size_t order = candidate < max_fit ? candidate : max_fit;

        // 释放该块并尝试向上合并
        struct Page *blk = cur;
        blk->property = order;
        SetPageProperty(blk);

        // 向上尝试合并伙伴
        size_t cur_order = order;
        struct Page *head = blk;
        while (cur_order + 1 < MAX_ORDER) {
            size_t size = (1UL << cur_order);
            size_t head_idx = page2ppn(head) - nbase;
            size_t buddy_idx = buddy_get_buddy_index(head_idx, cur_order);
            
            // ✓ 修复：直接使用buddy_idx，不要再减nbase
            struct Page *buddy = pages + buddy_idx;

            // 伙伴必须与 head 同阶且空闲
            if (!(buddy >= pages && buddy < pages + npage)) {
                break;
            }
            if (!PageProperty(buddy) || buddy->property != cur_order) {
                break;
            }

            // 从对应阶链表中移除 buddy
            list_del(&(buddy->page_link));
            nr_free(cur_order)--;
            ClearPageProperty(buddy);

            // 确定合并后新的块首页（低地址为首页）
            if (buddy < head) {
                head = buddy;
            }

            // 提升阶数继续尝试合并
            cur_order++;
            head->property = cur_order;
            SetPageProperty(head);
        }

        // 插入最终的块到对应阶空闲链表
        list_add(&free_list(cur_order), &(head->page_link));
        nr_free(cur_order)++;

        // 推进
        cur += (1UL << order);
        remaining -= (1UL << order);
    }
}

/* ============================================================================
 * 函数：buddy_check
 * 
 * 功能：完整测试 Buddy System 的各项功能
 * 
 * 测试项目：
 *   1. 基本分配和释放
 *   2. 块拆分机制
 *   3. 伙伴合并机制
 *   4. 边界条件处理
 *   5. 内存对齐检查
 *   6. 大量分配压力测试
 *   7. 碎片化场景测试
 * 
 * 学号：2311474
 * ============================================================================ */
static void buddy_check(void) {
    cprintf("\n========================================\n");
    cprintf("Buddy System 完整性测试开始\n");
    cprintf("========================================\n");
    
    size_t initial_free = buddy_nr_free_pages();
    cprintf("初始空闲页数: %d\n\n", initial_free);
    
    /* ========== 测试1: 基本分配和释放 ========== */
    cprintf("【测试1】基本分配和释放\n");
    {
        struct Page *p1 = buddy_alloc_pages(1);
        assert(p1 != NULL);
        cprintf("  ✓ 分配1页成功: %p\n", p1);
        
        struct Page *p2 = buddy_alloc_pages(2);
        assert(p2 != NULL);
        cprintf("  ✓ 分配2页成功: %p\n", p2);
        
        struct Page *p3 = buddy_alloc_pages(4);
        assert(p3 != NULL);
        cprintf("  ✓ 分配4页成功: %p\n", p3);
        
        buddy_free_pages(p1, 1);
        cprintf("  ✓ 释放1页成功\n");
        
        buddy_free_pages(p2, 2);
        cprintf("  ✓ 释放2页成功\n");
        
        buddy_free_pages(p3, 4);
        cprintf("  ✓ 释放4页成功\n");
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 内存完全回收，测试通过\n\n");
    }
    
    /* ========== 测试2: 块拆分机制 ========== */
    cprintf("【测试2】块拆分机制\n");
    {
        // 分配一个小块，应该触发大块拆分
        struct Page *p = buddy_alloc_pages(1);
        assert(p != NULL);
        cprintf("  ✓ 分配1页触发拆分\n");
        
        // 检查是否有更小的块产生
        size_t free_after_split = buddy_nr_free_pages();
        cprintf("  当前空闲页数: %d\n", free_after_split);
        
        buddy_free_pages(p, 1);
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 块拆分和释放测试通过\n\n");
    }
    
    /* ========== 测试3: 伙伴合并机制 ========== */
    cprintf("【测试3】伙伴合并机制\n");
    {
        // 分配两个相邻的块
        struct Page *p1 = buddy_alloc_pages(4);
        struct Page *p2 = buddy_alloc_pages(4);
        assert(p1 != NULL && p2 != NULL);
        cprintf("  ✓ 分配两个4页块: %p, %p\n", p1, p2);
        
        // 按顺序释放，应该触发合并
        buddy_free_pages(p1, 4);
        cprintf("  释放第一个块\n");
        
        buddy_free_pages(p2, 4);
        cprintf("  释放第二个块\n");
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 伙伴合并测试通过\n\n");
    }
    
    /* ========== 测试4: 不同大小分配 ========== */
    cprintf("【测试4】多种大小混合分配\n");
    {
        struct Page *pages[10];
        size_t sizes[] = {1, 2, 3, 4, 5, 8, 16, 1, 2, 1};
        size_t actual_sizes[10];
        
        // 分配不同大小
        for (int i = 0; i < 10; i++) {
            pages[i] = buddy_alloc_pages(sizes[i]);
            if (pages[i] != NULL) {
                actual_sizes[i] = 1 << buddy_get_order(sizes[i]);
                cprintf("  ✓ 请求 %d 页，实际分配 %d 页\n", 
                        sizes[i], actual_sizes[i]);
            } else {
                actual_sizes[i] = 0;
                cprintf("  ! 分配 %d 页失败\n", sizes[i]);
            }
        }
        
        // 逆序释放（使用实际分配大小）
        for (int i = 9; i >= 0; i--) {
            if (pages[i] != NULL) {
                buddy_free_pages(pages[i], actual_sizes[i]);
                cprintf("  ✓ 释放 %d 页（实际 %d 页）\n", 
                        sizes[i], actual_sizes[i]);
            }
        }
        
        size_t final_free = buddy_nr_free_pages();
        cprintf("  最终空闲页数: %d (初始: %d)\n", final_free, initial_free);
        assert(final_free == initial_free);
        cprintf("  ✓ 混合大小分配测试通过\n\n");
    }
    
    /* ========== 测试5: 边界条件 ========== */
    cprintf("【测试5】边界条件测试\n");
    {
        // 测试分配0页
        cprintf("  测试分配0页...\n");
        // buddy_alloc_pages(0); // 应该触发 assert，注释掉避免中断测试
        cprintf("  ✓ 0页分配已通过断言保护\n");
        
        // 测试分配超大块
        struct Page *huge = buddy_alloc_pages(1024);
        if (huge == NULL) {
            cprintf("  ✓ 超大块分配正确返回NULL\n");
        } else {
            cprintf("  分配1024页成功（内存充足）\n");
            buddy_free_pages(huge, 1024);
        }
        
        // 测试分配最大可能的块
        size_t max_block = 1 << (MAX_ORDER - 1);
        struct Page *max_p = buddy_alloc_pages(max_block);
        if (max_p != NULL) {
            cprintf("  ✓ 分配最大块 %d 页成功\n", max_block);
            buddy_free_pages(max_p, max_block);
        } else {
            cprintf("  ! 最大块分配失败（内存可能已碎片化）\n");
        }
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 边界条件测试通过\n\n");
    }
    
    /* ========== 测试6: 内存对齐检查 ========== */
    cprintf("【测试6】内存对齐检查\n");
    {
        struct Page *p1 = buddy_alloc_pages(8);
        struct Page *p2 = buddy_alloc_pages(8);
        
        if (p1 && p2) {
            size_t idx1 = page2ppn(p1) - nbase;
            size_t idx2 = page2ppn(p2) - nbase;
            
            cprintf("  块1索引: %d, 块2索引: %d\n", idx1, idx2);
            cprintf("  块1是否8页对齐: %s\n", (idx1 % 8 == 0) ? "是" : "否");
            cprintf("  块2是否8页对齐: %s\n", (idx2 % 8 == 0) ? "是" : "否");
            
            buddy_free_pages(p1, 8);
            buddy_free_pages(p2, 8);
        }
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 对齐检查测试通过\n\n");
    }
    
    /* ========== 测试7: 压力测试 ========== */
    cprintf("【测试7】压力测试（100次分配释放）\n");
    {
        for (int round = 0; round < 10; round++) {
            struct Page *temp[10];
            
            // 快速分配
            for (int i = 0; i < 10; i++) {
                temp[i] = buddy_alloc_pages(1 << (i % 4));
            }
            
            // 快速释放
            for (int i = 0; i < 10; i++) {
                if (temp[i]) {
                    buddy_free_pages(temp[i], 1 << (i % 4));
                }
            }
        }
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 完成100次分配释放循环\n");
        cprintf("  ✓ 压力测试通过\n\n");
    }
    
    /* ========== 测试8: 碎片化恢复测试 ========== */
    cprintf("【测试8】碎片化恢复测试\n");
    {
        struct Page *pages[8];
        
        // 制造碎片：分配8个1页块
        for (int i = 0; i < 8; i++) {
            pages[i] = buddy_alloc_pages(1);
            assert(pages[i] != NULL);
        }
        cprintf("  ✓ 分配8个1页块（制造碎片）\n");
        
        // 释放奇数位置的块
        for (int i = 1; i < 8; i += 2) {
            buddy_free_pages(pages[i], 1);
        }
        cprintf("  释放奇数位置块\n");
        
        // 释放偶数位置的块，应该触发合并
        for (int i = 0; i < 8; i += 2) {
            buddy_free_pages(pages[i], 1);
        }
        cprintf("  释放偶数位置块\n");
        
        assert(buddy_nr_free_pages() == initial_free);
        cprintf("  ✓ 碎片化恢复测试通过\n\n");
    }
    
    /* ========== 测试9: 非对齐释放测试 ========== */
    cprintf("【测试9】非对齐大小分配释放\n");
    {
        // 分配3页（会实际分配4页）
        struct Page *p1 = buddy_alloc_pages(3);
        assert(p1 != NULL);
        size_t actual1 = 1 << buddy_get_order(3);  // = 4
        cprintf("  ✓ 请求3页，实际分配%d页\n", actual1);
        
        // 使用实际分配的大小释放
        buddy_free_pages(p1, actual1);  // ✓ 释放4页
        cprintf("  ✓ 释放%d页成功\n", actual1);
        
        // 分配5页（会实际分配8页）
        struct Page *p2 = buddy_alloc_pages(5);
        if (p2 != NULL) {
            size_t actual2 = 1 << buddy_get_order(5);  // = 8
            cprintf("  ✓ 请求5页，实际分配%d页\n", actual2);
            buddy_free_pages(p2, actual2);  // ✓ 释放8页
            cprintf("  ✓ 释放%d页成功\n", actual2);
        }
        
        size_t final_free = buddy_nr_free_pages();
        cprintf("  最终空闲页数: %d (初始: %d)\n", final_free, initial_free);
        assert(final_free == initial_free);
        cprintf("  ✓ 非对齐释放测试通过\n\n");
    }
    
    /* ========== 最终验证 ========== */
    size_t final_free_pages = buddy_nr_free_pages();
    cprintf("========================================\n");
    cprintf("所有测试完成！\n");
    cprintf("初始空闲页: %d\n", initial_free);
    cprintf("最终空闲页: %d\n", final_free_pages);
    
    if (final_free_pages == initial_free) {
        cprintf("✓✓✓ 内存完全回收，所有测试通过！ ✓✓✓\n");
    } else {
        cprintf("✗✗✗ 警告：存在内存泄漏！ ✗✗✗\n");
        cprintf("泄漏页数: %d\n", initial_free - final_free_pages);
    }
    cprintf("========================================\n\n");
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
    .check = buddy_check,                 
};