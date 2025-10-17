#ifndef __KERN_MM_BUDDY_PMM_H__
#define __KERN_MM_BUDDY_PMM_H__

#include <pmm.h>

/* Buddy System常量定义 */
#define MAX_ORDER 11  // 最大阶数：2^10 = 1024页 = 4MB（可根据实际内存调整）(2^0 ~ 2^10, 共11个阶)

/* Buddy System空闲区域管理结构 */
typedef struct {
    list_entry_t free_list[MAX_ORDER]; // 每个阶对应一个空闲链表
    unsigned int nr_free[MAX_ORDER]; // 每个阶的空闲块数量
} buddy_free_area_t;

/* 导出pmm_manager结构供外部使用 */
extern const struct pmm_manager buddy_pmm_manager;

/* 辅助函数声明（供内部和测试使用） */
size_t buddy_get_order(size_t n); // 计算需要的阶数
size_t buddy_get_buddy_index(size_t index, size_t order); // 计算伙伴页索引

#endif /* !__KERN_MM_BUDDY_PMM_H__ */