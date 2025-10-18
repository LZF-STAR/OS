# Buddy System（伙伴系统）分配算法设计文档

## 1. 实验概述

### 1.1 实验目标

实现一个基于伙伴系统（Buddy System）的物理内存分配器，用于uCore操作系统的物理内存管理。该分配器需要满足以下要求：

- ✅ 高效管理物理内存页面，支持快速分配和释放
- ✅ 自动合并相邻空闲块，减少外部碎片
- ✅ 保证分配的内存块大小为2的幂次方
- ✅ 通过完整的测试用例验证正确性

### 1.2 Buddy System核心思想

**分层管理**: 将内存划分为大小为 2^k 页的块，其中 k ∈ [0, MAX_ORDER-1]

**关键机制**：
1. **按需拆分**: 当没有合适大小的块时，拆分更大的块
2. **伙伴合并**: 释放时自动与伙伴块合并，形成更大的块
3. **对齐保证**: 每个块在其大小的整数倍地址上对齐

**示例**：
```
初始: [1024页块]
分配3页: 
  1024→[512][512] → [512][256][256] → [512][256][128][128]
  → [512][256][128][64][64] → [512][256][128][64][32][32]
  → [512][256][128][64][32][16][16] → [512][256][128][64][32][16][8][8]
  → [512][256][128][64][32][16][8][4][4]
  最终分配4页块（满足≥3页的最小2的幂次）
```

### 1.3 关键参数

```c
#define MAX_ORDER 11  // 支持的最大阶数
// 块大小范围: 2^0 ~ 2^10 页 = 1页 ~ 1024页 = 4KB ~ 4MB
```

---

## 2. 数据结构设计

### 2.1 空闲区域管理结构

```c
typedef struct {
    list_entry_t free_list[MAX_ORDER];  // 每个阶对应一个空闲链表
    unsigned int nr_free[MAX_ORDER];    // 每个阶的空闲块数量
} buddy_free_area_t;
```

**设计说明**：
- `free_list[k]`: 双向链表，存储大小为 2^k 页的所有空闲块
- `nr_free[k]`: 快速查询该阶的空闲块数量

**内存布局示例**（初始化31929页后）：
```
Order 0:  [1页] → NULL                  (1块)
Order 3:  [8页] → NULL                  (1块)
Order 4:  [16页] → NULL                 (1块)
Order 5:  [32页] → NULL                 (1块)
Order 7:  [128页] → NULL                (1块)
Order 10: [1024页] → [1024页] → ... → NULL  (31块)
```

### 2.2 页面结构体语义

利用现有的 `struct Page` 结构：

```c
struct Page {
    int ref;                 // 引用计数
    uint64_t flags;          // 页面状态标志
    unsigned int property;   // Buddy中记录块的阶数
    list_entry_t page_link;  // 链表节点
};
```

**Buddy System中的语义**：
- `property`: 块首页存储该块的阶数（order），非首页为0
- `PG_property` 标志: 为1表示这是一个空闲块的首页
- `page_link`: 将同阶的空闲块串联成链表

### 2.3 伙伴关系定义

**两个块互为伙伴的充要条件**：
1. 大小相同（同阶）
2. 物理地址相邻
3. 起始地址对齐到 2^(order+1) 的倍数

**伙伴索引计算公式**：
```c
buddy_index = index XOR (1 << order)
```

**计算原理**（以order=2为例）：
```
块大小 = 2^2 = 4页
对齐要求 = 2^3 = 8页

索引0的伙伴 = 0 XOR 4 = 4   ✓ (0-3 和 4-7)
索引4的伙伴 = 4 XOR 4 = 0   ✓ (互为伙伴)
索引8的伙伴 = 8 XOR 4 = 12  ✓ (8-11 和 12-15)
```

---

## 3. 核心算法实现

### 3.1 初始化 (`buddy_init`)

**功能**: 初始化Buddy System的数据结构

**实现**：
```c
static void buddy_init(void) {
    for (int i = 0; i < MAX_ORDER; i++) {
        list_init(&free_list(i));
        nr_free(i) = 0;
    }
}
```

**时间复杂度**: O(MAX_ORDER) = O(1)

### 3.2 内存映射初始化 (`buddy_init_memmap`)

**功能**: 将连续物理内存分解为2的幂次块并加入管理

**算法**：
```
输入: base（起始页）, n（页数）

1. 初始化所有页面: flags=0, property=0, ref=0
2. remaining ← n, current_index ← 0
3. for order from (MAX_ORDER-1) down to 0:
       block_size ← 2^order
       while remaining >= block_size:
           page ← base + current_index
           page->property ← order
           SetPageProperty(page)
           加入 free_list[order]
           nr_free[order]++
           current_index += block_size
           remaining -= block_size
```

**示例**: 初始化31929页
```
31929 = 31×1024 + 128 + 32 + 16 + 8 + 1
     = 31×2^10 + 2^7 + 2^5 + 2^4 + 2^3 + 2^0

结果: 
  Order 10: 31块 (31×1024 = 31744页)
  Order 7:  1块  (128页)
  Order 5:  1块  (32页)
  Order 4:  1块  (16页)
  Order 3:  1块  (8页)
  Order 0:  1块  (1页)
  总计: 31929页 ✓
```

**时间复杂度**: O(n)

### 3.3 分配算法 (`buddy_alloc_pages`)

**功能**: 分配至少n个页面

**算法流程**：
```
输入: n（请求页数）
输出: Page*（块首页）或 NULL

1. order ← 计算最小的k使得2^k >= n
2. if order >= MAX_ORDER: return NULL
3. current_order ← order
4. // 向上查找第一个非空链表
   while current_order < MAX_ORDER:
       if free_list[current_order]非空:
           page ← 从链表取出首块
           nr_free[current_order]--
           ClearPageProperty(page)
           break
       current_order++
5. if page == NULL: return NULL
6. // 拆分至目标大小
   while current_order > order:
       page ← split(page)
       current_order--
7. return page
```

**块拆分函数** (`split`):
```c
static struct Page *split(struct Page *page) {
    size_t order = page->property;
    size_t new_order = order - 1;
    
    // 右半块加入空闲链表
    struct Page *buddy = page + (1 << new_order);
    buddy->property = new_order;
    SetPageProperty(buddy);
    list_add(&free_list(new_order), &buddy->page_link);
    nr_free(new_order)++;
    
    // 左半块继续使用或拆分
    page->property = new_order;
    return page;
}
```

**示例**: 分配3页
```
请求3页 → order=2 (2^2=4)

假设初始状态只有1个order-4的16页块:
1. 在order-4找到16页块
2. 拆分16→[8][8]，右8页→order-3链表
3. 拆分左8→[4][4]，右4页→order-2链表
4. 返回左4页块 ✓
```

**时间复杂度**: O(log n)

### 3.4 释放算法 (`buddy_free_pages`) ⭐

**功能**: 释放n个页面并尝试合并伙伴块

**关键设计**: 支持释放任意大小n（会自动拆分为2的幂次块）

**算法流程**：
```
输入: base（起始页）, n（页数）

1. 清理所有页面: flags=0, property=0, ref=0
2. cur ← base, remaining ← n
3. while remaining > 0:
       idx ← page2ppn(cur) - nbase  // 相对索引
       
       // 计算最大对齐阶
       align ← 0
       while (idx & (1<<align)) == 0 AND align+1 < MAX_ORDER:
           align++
       
       // 计算最大能释放的阶
       max_fit ← 使得2^max_fit <= remaining的最大值
       
       order ← min(align, max_fit)
       
       // 释放并合并
       blk ← cur
       blk->property ← order
       SetPageProperty(blk)
       
       head ← blk, cur_order ← order
       while cur_order + 1 < MAX_ORDER:
           head_idx ← page2ppn(head) - nbase
           buddy_idx ← head_idx XOR (1 << cur_order)
           buddy ← pages + buddy_idx  // ✓ 关键修复
           
           if buddy越界 OR !PageProperty(buddy) OR 
              buddy->property != cur_order:
               break
           
           // 合并
           从 free_list[cur_order] 移除buddy
           nr_free[cur_order]--
           ClearPageProperty(buddy)
           head ← min(head, buddy)
           cur_order++
           head->property ← cur_order
       
       list_add(&free_list[cur_order], &head->page_link)
       nr_free(cur_order)++
       
       cur += (1 << order)
       remaining -= (1 << order)
```


**示例**: 释放5页（非2的幂次）
```
base索引=8，释放5页：

步骤1: idx=8, 对齐order=3, 但remaining=5
       → order = min(3, 2) = 2 (2^2=4)
       释放索引8-11的4页块
       
步骤2: cur移到索引12, remaining=1
       释放索引12的1页块
       
结果: 5页被拆分为[4页块]+[1页块]分别释放 ✓
```

**时间复杂度**: O(n × log n)

### 3.5 查询函数

**统计空闲页数**:
```c
static size_t buddy_nr_free_pages(void) {
    size_t total = 0;
    for (int i = 0; i < MAX_ORDER; i++) {
        total += nr_free(i) * (1 << i);
    }
    return total;
}
```

---

## 4. 测试用例设计与结果

| 测试 | 内容 | 目的 | 结果 |
|------|------|------|------|
| 测试1 | 基本分配释放 | 验证1,2,4页的分配释放 | ✅ 通过 |
| 测试2 | 块拆分机制 | 验证split()函数 | ✅ 通过 |
| 测试3 | 伙伴合并机制 | 验证free时的合并逻辑 | ✅ 通过 |
| 测试4 | 多种大小混合分配 | 测试3,5等非2^k大小 | ✅ 通过 |
| 测试5 | 边界条件 | 0页、1024页、超大块 | ✅ 通过 |
| 测试6 | 内存对齐检查 | 验证2^k对齐特性 | ✅ 通过 |
| 测试7 | 压力测试 | 100次随机分配释放 | ✅ 通过 |
| 测试8 | 碎片化恢复 | 验证碎片合并能力 | ✅ 通过 |
| 测试9 | 非对齐大小 | 测试释放实际分配大小 | ✅ 通过 |



---

## 5. 实验结论

### 5.1 完成情况

- ✅ 成功实现Buddy System核心功能
- ✅ 支持任意大小的分配请求（自动上取整到2的幂次）
- ✅ 实现块拆分和伙伴合并机制
- ✅ 通过全部9项测试，无内存泄漏

### 5.2 性能评估

| 指标 | 数值 |
|------|------|
| 支持最大块 | 1024页 = 4MB |
| 分配速度 | O(log n) |
| 释放速度 | O(n log n) 最坏，O(log n) 平均 |
| 元数据开销 | < 1% |
| 测试通过率 | 100% (9/9) |

---

## 附录：完整代码结构

```
kern/mm/
├── buddy_pmm.h           # 头文件（MAX_ORDER=11，结构体定义）
├── buddy_pmm.c           # 实现文件（788行）
│   ├── buddy_init()               [已实现] 初始化
│   ├── buddy_init_memmap()        [已实现] 内存映射初始化
│   ├── buddy_alloc_pages()        [已实现] 分配算法（学号2310764）
│   ├── split()                    [已实现] 块拆分（学号2310764）
│   ├── buddy_free_pages()         [已实现] 释放算法（学号2311456）
│   ├── buddy_nr_free_pages()      [已实现] 查询函数
│   ├── buddy_check()              [已实现] 9项完整测试
│   └── buddy_pmm_manager          [已实现] PMM接口
└── pmm.c                 # 调用入口
```