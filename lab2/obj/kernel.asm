
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	6e450513          	addi	a0,a0,1764 # ffffffffc0201730 <etext+0x2>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	6ee50513          	addi	a0,a0,1774 # ffffffffc0201750 <etext+0x22>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	6c058593          	addi	a1,a1,1728 # ffffffffc020172e <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	6fa50513          	addi	a0,a0,1786 # ffffffffc0201770 <etext+0x42>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	70650513          	addi	a0,a0,1798 # ffffffffc0201790 <etext+0x62>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	fe258593          	addi	a1,a1,-30 # ffffffffc0206078 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	71250513          	addi	a0,a0,1810 # ffffffffc02017b0 <etext+0x82>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	3cd58593          	addi	a1,a1,973 # ffffffffc0206477 <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	70450513          	addi	a0,a0,1796 # ffffffffc02017d0 <etext+0xa2>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00006517          	auipc	a0,0x6
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0206018 <free_area>
ffffffffc02000e0:	00006617          	auipc	a2,0x6
ffffffffc02000e4:	f9860613          	addi	a2,a2,-104 # ffffffffc0206078 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	62c010ef          	jal	ra,ffffffffc020171c <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	70450513          	addi	a0,a0,1796 # ffffffffc0201800 <etext+0xd2>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	7b7000ef          	jal	ra,ffffffffc02010c2 <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	1c6010ef          	jal	ra,ffffffffc0201306 <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	190010ef          	jal	ra,ffffffffc0201306 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00006317          	auipc	t1,0x6
ffffffffc02001c6:	e6e30313          	addi	t1,t1,-402 # ffffffffc0206030 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	62e50513          	addi	a0,a0,1582 # ffffffffc0201820 <etext+0xf2>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	5f050513          	addi	a0,a0,1520 # ffffffffc02017f8 <etext+0xca>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	46c0106f          	j	ffffffffc0201688 <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	61e50513          	addi	a0,a0,1566 # ffffffffc0201840 <etext+0x112>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	60050513          	addi	a0,a0,1536 # ffffffffc0201850 <etext+0x122>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00006417          	auipc	s0,0x6
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0206008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	5fa50513          	addi	a0,a0,1530 # ffffffffc0201860 <etext+0x132>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	60250513          	addi	a0,a0,1538 # ffffffffc0201878 <etext+0x14a>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9e75>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	59890913          	addi	s2,s2,1432 # ffffffffc02018c8 <etext+0x19a>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	58248493          	addi	s1,s1,1410 # ffffffffc02018c0 <etext+0x192>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	5ae50513          	addi	a0,a0,1454 # ffffffffc0201940 <etext+0x212>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	5da50513          	addi	a0,a0,1498 # ffffffffc0201978 <etext+0x24a>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	4ba50513          	addi	a0,a0,1210 # ffffffffc0201898 <etext+0x16a>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	2b6010ef          	jal	ra,ffffffffc02016a2 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	2fc010ef          	jal	ra,ffffffffc02016f6 <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	248010ef          	jal	ra,ffffffffc02016d8 <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	42c50513          	addi	a0,a0,1068 # ffffffffc02018d0 <etext+0x1a2>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	37e50513          	addi	a0,a0,894 # ffffffffc02018f0 <etext+0x1c2>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	38450513          	addi	a0,a0,900 # ffffffffc0201908 <etext+0x1da>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	39250513          	addi	a0,a0,914 # ffffffffc0201928 <etext+0x1fa>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	3d650513          	addi	a0,a0,982 # ffffffffc0201978 <etext+0x24a>
        memory_base = mem_base;
ffffffffc02005aa:	00006797          	auipc	a5,0x6
ffffffffc02005ae:	a887b723          	sd	s0,-1394(a5) # ffffffffc0206038 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00006797          	auipc	a5,0x6
ffffffffc02005b6:	a967b723          	sd	s6,-1394(a5) # ffffffffc0206040 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	a7c53503          	ld	a0,-1412(a0) # ffffffffc0206038 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00006517          	auipc	a0,0x6
ffffffffc02005ca:	a7a53503          	ld	a0,-1414(a0) # ffffffffc0206040 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <default_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0206018 <free_area>
ffffffffc02005d8:	e79c                	sd	a5,8(a5)
ffffffffc02005da:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005dc:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e0:	8082                	ret

ffffffffc02005e2 <default_nr_free_pages>:
}

static size_t
default_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02005e2:	00006517          	auipc	a0,0x6
ffffffffc02005e6:	a4656503          	lwu	a0,-1466(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc02005ea:	8082                	ret

ffffffffc02005ec <default_alloc_pages>:
    assert(n > 0);
ffffffffc02005ec:	c949                	beqz	a0,ffffffffc020067e <default_alloc_pages+0x92>
    if (n > nr_free) {
ffffffffc02005ee:	00006597          	auipc	a1,0x6
ffffffffc02005f2:	a2a58593          	addi	a1,a1,-1494 # ffffffffc0206018 <free_area>
ffffffffc02005f6:	0105a803          	lw	a6,16(a1)
ffffffffc02005fa:	862a                	mv	a2,a0
ffffffffc02005fc:	02081793          	slli	a5,a6,0x20
ffffffffc0200600:	9381                	srli	a5,a5,0x20
ffffffffc0200602:	00a7ee63          	bltu	a5,a0,ffffffffc020061e <default_alloc_pages+0x32>
    list_entry_t *le = &free_list;
ffffffffc0200606:	87ae                	mv	a5,a1
ffffffffc0200608:	a801                	j	ffffffffc0200618 <default_alloc_pages+0x2c>
        if (p->property >= n) {
ffffffffc020060a:	ff87a703          	lw	a4,-8(a5)
ffffffffc020060e:	02071693          	slli	a3,a4,0x20
ffffffffc0200612:	9281                	srli	a3,a3,0x20
ffffffffc0200614:	00c6f763          	bgeu	a3,a2,ffffffffc0200622 <default_alloc_pages+0x36>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200618:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc020061a:	feb798e3          	bne	a5,a1,ffffffffc020060a <default_alloc_pages+0x1e>
        return NULL;
ffffffffc020061e:	4501                	li	a0,0
}
ffffffffc0200620:	8082                	ret
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200622:	0007b303          	ld	t1,0(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200626:	0087b883          	ld	a7,8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc020062a:	fe878513          	addi	a0,a5,-24
            p->property = page->property - n;
ffffffffc020062e:	00060e1b          	sext.w	t3,a2
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200632:	01133423          	sd	a7,8(t1)
    next->prev = prev;
ffffffffc0200636:	0068b023          	sd	t1,0(a7)
        if (page->property > n) {
ffffffffc020063a:	02d67863          	bgeu	a2,a3,ffffffffc020066a <default_alloc_pages+0x7e>
            struct Page *p = page + n;
ffffffffc020063e:	00261693          	slli	a3,a2,0x2
ffffffffc0200642:	96b2                	add	a3,a3,a2
ffffffffc0200644:	068e                	slli	a3,a3,0x3
ffffffffc0200646:	96aa                	add	a3,a3,a0
            SetPageProperty(p);
ffffffffc0200648:	6690                	ld	a2,8(a3)
            p->property = page->property - n;
ffffffffc020064a:	41c7073b          	subw	a4,a4,t3
ffffffffc020064e:	ca98                	sw	a4,16(a3)
            SetPageProperty(p);
ffffffffc0200650:	00266713          	ori	a4,a2,2
ffffffffc0200654:	e698                	sd	a4,8(a3)
            list_add(prev, &(p->page_link));
ffffffffc0200656:	01868713          	addi	a4,a3,24
    prev->next = next->prev = elm;
ffffffffc020065a:	00e8b023          	sd	a4,0(a7)
ffffffffc020065e:	00e33423          	sd	a4,8(t1)
    elm->next = next;
ffffffffc0200662:	0316b023          	sd	a7,32(a3)
    elm->prev = prev;
ffffffffc0200666:	0066bc23          	sd	t1,24(a3)
        ClearPageProperty(page);
ffffffffc020066a:	ff07b703          	ld	a4,-16(a5)
        nr_free -= n;
ffffffffc020066e:	41c8083b          	subw	a6,a6,t3
ffffffffc0200672:	0105a823          	sw	a6,16(a1)
        ClearPageProperty(page);
ffffffffc0200676:	9b75                	andi	a4,a4,-3
ffffffffc0200678:	fee7b823          	sd	a4,-16(a5)
ffffffffc020067c:	8082                	ret
default_alloc_pages(size_t n) {
ffffffffc020067e:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200680:	00001697          	auipc	a3,0x1
ffffffffc0200684:	31068693          	addi	a3,a3,784 # ffffffffc0201990 <etext+0x262>
ffffffffc0200688:	00001617          	auipc	a2,0x1
ffffffffc020068c:	31060613          	addi	a2,a2,784 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200690:	06200593          	li	a1,98
ffffffffc0200694:	00001517          	auipc	a0,0x1
ffffffffc0200698:	31c50513          	addi	a0,a0,796 # ffffffffc02019b0 <etext+0x282>
default_alloc_pages(size_t n) {
ffffffffc020069c:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020069e:	b25ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02006a2 <default_check>:
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
ffffffffc02006a2:	715d                	addi	sp,sp,-80
ffffffffc02006a4:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc02006a6:	00006417          	auipc	s0,0x6
ffffffffc02006aa:	97240413          	addi	s0,s0,-1678 # ffffffffc0206018 <free_area>
ffffffffc02006ae:	641c                	ld	a5,8(s0)
ffffffffc02006b0:	e486                	sd	ra,72(sp)
ffffffffc02006b2:	fc26                	sd	s1,56(sp)
ffffffffc02006b4:	f84a                	sd	s2,48(sp)
ffffffffc02006b6:	f44e                	sd	s3,40(sp)
ffffffffc02006b8:	f052                	sd	s4,32(sp)
ffffffffc02006ba:	ec56                	sd	s5,24(sp)
ffffffffc02006bc:	e85a                	sd	s6,16(sp)
ffffffffc02006be:	e45e                	sd	s7,8(sp)
ffffffffc02006c0:	e062                	sd	s8,0(sp)
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006c2:	2c878363          	beq	a5,s0,ffffffffc0200988 <default_check+0x2e6>
    int count = 0, total = 0;
ffffffffc02006c6:	4481                	li	s1,0
ffffffffc02006c8:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02006ca:	ff07b703          	ld	a4,-16(a5)
ffffffffc02006ce:	8b09                	andi	a4,a4,2
ffffffffc02006d0:	2c070063          	beqz	a4,ffffffffc0200990 <default_check+0x2ee>
        count ++, total += p->property;
ffffffffc02006d4:	ff87a703          	lw	a4,-8(a5)
ffffffffc02006d8:	679c                	ld	a5,8(a5)
ffffffffc02006da:	2905                	addiw	s2,s2,1
ffffffffc02006dc:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006de:	fe8796e3          	bne	a5,s0,ffffffffc02006ca <default_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc02006e2:	89a6                	mv	s3,s1
ffffffffc02006e4:	1d3000ef          	jal	ra,ffffffffc02010b6 <nr_free_pages>
ffffffffc02006e8:	71351463          	bne	a0,s3,ffffffffc0200df0 <default_check+0x74e>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02006ec:	4505                	li	a0,1
ffffffffc02006ee:	1b1000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02006f2:	8a2a                	mv	s4,a0
ffffffffc02006f4:	42050e63          	beqz	a0,ffffffffc0200b30 <default_check+0x48e>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02006f8:	4505                	li	a0,1
ffffffffc02006fa:	1a5000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02006fe:	89aa                	mv	s3,a0
ffffffffc0200700:	70050863          	beqz	a0,ffffffffc0200e10 <default_check+0x76e>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200704:	4505                	li	a0,1
ffffffffc0200706:	199000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020070a:	8aaa                	mv	s5,a0
ffffffffc020070c:	4a050263          	beqz	a0,ffffffffc0200bb0 <default_check+0x50e>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200710:	2b3a0063          	beq	s4,s3,ffffffffc02009b0 <default_check+0x30e>
ffffffffc0200714:	28aa0e63          	beq	s4,a0,ffffffffc02009b0 <default_check+0x30e>
ffffffffc0200718:	28a98c63          	beq	s3,a0,ffffffffc02009b0 <default_check+0x30e>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc020071c:	000a2783          	lw	a5,0(s4)
ffffffffc0200720:	2a079863          	bnez	a5,ffffffffc02009d0 <default_check+0x32e>
ffffffffc0200724:	0009a783          	lw	a5,0(s3)
ffffffffc0200728:	2a079463          	bnez	a5,ffffffffc02009d0 <default_check+0x32e>
ffffffffc020072c:	411c                	lw	a5,0(a0)
ffffffffc020072e:	2a079163          	bnez	a5,ffffffffc02009d0 <default_check+0x32e>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200732:	00006797          	auipc	a5,0x6
ffffffffc0200736:	91e7b783          	ld	a5,-1762(a5) # ffffffffc0206050 <pages>
ffffffffc020073a:	40fa0733          	sub	a4,s4,a5
ffffffffc020073e:	870d                	srai	a4,a4,0x3
ffffffffc0200740:	00002597          	auipc	a1,0x2
ffffffffc0200744:	9d85b583          	ld	a1,-1576(a1) # ffffffffc0202118 <error_string+0x38>
ffffffffc0200748:	02b70733          	mul	a4,a4,a1
ffffffffc020074c:	00002617          	auipc	a2,0x2
ffffffffc0200750:	9d463603          	ld	a2,-1580(a2) # ffffffffc0202120 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200754:	00006697          	auipc	a3,0x6
ffffffffc0200758:	8f46b683          	ld	a3,-1804(a3) # ffffffffc0206048 <npage>
ffffffffc020075c:	06b2                	slli	a3,a3,0xc
ffffffffc020075e:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc0200760:	0732                	slli	a4,a4,0xc
ffffffffc0200762:	28d77763          	bgeu	a4,a3,ffffffffc02009f0 <default_check+0x34e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200766:	40f98733          	sub	a4,s3,a5
ffffffffc020076a:	870d                	srai	a4,a4,0x3
ffffffffc020076c:	02b70733          	mul	a4,a4,a1
ffffffffc0200770:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200772:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200774:	4ad77e63          	bgeu	a4,a3,ffffffffc0200c30 <default_check+0x58e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200778:	40f507b3          	sub	a5,a0,a5
ffffffffc020077c:	878d                	srai	a5,a5,0x3
ffffffffc020077e:	02b787b3          	mul	a5,a5,a1
ffffffffc0200782:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200784:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200786:	30d7f563          	bgeu	a5,a3,ffffffffc0200a90 <default_check+0x3ee>
    assert(alloc_page() == NULL);
ffffffffc020078a:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020078c:	00043c03          	ld	s8,0(s0)
ffffffffc0200790:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc0200794:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200798:	e400                	sd	s0,8(s0)
ffffffffc020079a:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc020079c:	00006797          	auipc	a5,0x6
ffffffffc02007a0:	8807a623          	sw	zero,-1908(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc02007a4:	0fb000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02007a8:	2c051463          	bnez	a0,ffffffffc0200a70 <default_check+0x3ce>
    free_page(p0);
ffffffffc02007ac:	4585                	li	a1,1
ffffffffc02007ae:	8552                	mv	a0,s4
ffffffffc02007b0:	0fb000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_page(p1);
ffffffffc02007b4:	4585                	li	a1,1
ffffffffc02007b6:	854e                	mv	a0,s3
ffffffffc02007b8:	0f3000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_page(p2);
ffffffffc02007bc:	4585                	li	a1,1
ffffffffc02007be:	8556                	mv	a0,s5
ffffffffc02007c0:	0eb000ef          	jal	ra,ffffffffc02010aa <free_pages>
    assert(nr_free == 3);
ffffffffc02007c4:	4818                	lw	a4,16(s0)
ffffffffc02007c6:	478d                	li	a5,3
ffffffffc02007c8:	28f71463          	bne	a4,a5,ffffffffc0200a50 <default_check+0x3ae>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007cc:	4505                	li	a0,1
ffffffffc02007ce:	0d1000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02007d2:	89aa                	mv	s3,a0
ffffffffc02007d4:	24050e63          	beqz	a0,ffffffffc0200a30 <default_check+0x38e>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007d8:	4505                	li	a0,1
ffffffffc02007da:	0c5000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02007de:	8aaa                	mv	s5,a0
ffffffffc02007e0:	3a050863          	beqz	a0,ffffffffc0200b90 <default_check+0x4ee>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007e4:	4505                	li	a0,1
ffffffffc02007e6:	0b9000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02007ea:	8a2a                	mv	s4,a0
ffffffffc02007ec:	38050263          	beqz	a0,ffffffffc0200b70 <default_check+0x4ce>
    assert(alloc_page() == NULL);
ffffffffc02007f0:	4505                	li	a0,1
ffffffffc02007f2:	0ad000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02007f6:	34051d63          	bnez	a0,ffffffffc0200b50 <default_check+0x4ae>
    free_page(p0);
ffffffffc02007fa:	4585                	li	a1,1
ffffffffc02007fc:	854e                	mv	a0,s3
ffffffffc02007fe:	0ad000ef          	jal	ra,ffffffffc02010aa <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200802:	641c                	ld	a5,8(s0)
ffffffffc0200804:	20878663          	beq	a5,s0,ffffffffc0200a10 <default_check+0x36e>
    assert((p = alloc_page()) == p0);
ffffffffc0200808:	4505                	li	a0,1
ffffffffc020080a:	095000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020080e:	30a99163          	bne	s3,a0,ffffffffc0200b10 <default_check+0x46e>
    assert(alloc_page() == NULL);
ffffffffc0200812:	4505                	li	a0,1
ffffffffc0200814:	08b000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc0200818:	2c051c63          	bnez	a0,ffffffffc0200af0 <default_check+0x44e>
    assert(nr_free == 0);
ffffffffc020081c:	481c                	lw	a5,16(s0)
ffffffffc020081e:	2a079963          	bnez	a5,ffffffffc0200ad0 <default_check+0x42e>
    free_page(p);
ffffffffc0200822:	854e                	mv	a0,s3
ffffffffc0200824:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200826:	01843023          	sd	s8,0(s0)
ffffffffc020082a:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc020082e:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200832:	079000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_page(p1);
ffffffffc0200836:	4585                	li	a1,1
ffffffffc0200838:	8556                	mv	a0,s5
ffffffffc020083a:	071000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_page(p2);
ffffffffc020083e:	4585                	li	a1,1
ffffffffc0200840:	8552                	mv	a0,s4
ffffffffc0200842:	069000ef          	jal	ra,ffffffffc02010aa <free_pages>

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200846:	4515                	li	a0,5
ffffffffc0200848:	057000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020084c:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc020084e:	26050163          	beqz	a0,ffffffffc0200ab0 <default_check+0x40e>
    assert(!PageProperty(p0));
ffffffffc0200852:	651c                	ld	a5,8(a0)
ffffffffc0200854:	8b89                	andi	a5,a5,2
ffffffffc0200856:	52079d63          	bnez	a5,ffffffffc0200d90 <default_check+0x6ee>

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc020085a:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020085c:	00043b83          	ld	s7,0(s0)
ffffffffc0200860:	00843b03          	ld	s6,8(s0)
ffffffffc0200864:	e000                	sd	s0,0(s0)
ffffffffc0200866:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200868:	037000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020086c:	50051263          	bnez	a0,ffffffffc0200d70 <default_check+0x6ce>

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
ffffffffc0200870:	05098a13          	addi	s4,s3,80
ffffffffc0200874:	8552                	mv	a0,s4
ffffffffc0200876:	458d                	li	a1,3
    unsigned int nr_free_store = nr_free;
ffffffffc0200878:	01042c03          	lw	s8,16(s0)
    nr_free = 0;
ffffffffc020087c:	00005797          	auipc	a5,0x5
ffffffffc0200880:	7a07a623          	sw	zero,1964(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 2, 3);
ffffffffc0200884:	027000ef          	jal	ra,ffffffffc02010aa <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200888:	4511                	li	a0,4
ffffffffc020088a:	015000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020088e:	4c051163          	bnez	a0,ffffffffc0200d50 <default_check+0x6ae>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200892:	0589b783          	ld	a5,88(s3)
ffffffffc0200896:	8b89                	andi	a5,a5,2
ffffffffc0200898:	48078c63          	beqz	a5,ffffffffc0200d30 <default_check+0x68e>
ffffffffc020089c:	0609a703          	lw	a4,96(s3)
ffffffffc02008a0:	478d                	li	a5,3
ffffffffc02008a2:	48f71763          	bne	a4,a5,ffffffffc0200d30 <default_check+0x68e>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc02008a6:	450d                	li	a0,3
ffffffffc02008a8:	7f6000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02008ac:	8aaa                	mv	s5,a0
ffffffffc02008ae:	46050163          	beqz	a0,ffffffffc0200d10 <default_check+0x66e>
    assert(alloc_page() == NULL);
ffffffffc02008b2:	4505                	li	a0,1
ffffffffc02008b4:	7ea000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc02008b8:	42051c63          	bnez	a0,ffffffffc0200cf0 <default_check+0x64e>
    assert(p0 + 2 == p1);
ffffffffc02008bc:	415a1a63          	bne	s4,s5,ffffffffc0200cd0 <default_check+0x62e>

    p2 = p0 + 1;
    free_page(p0);
ffffffffc02008c0:	4585                	li	a1,1
ffffffffc02008c2:	854e                	mv	a0,s3
ffffffffc02008c4:	7e6000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_pages(p1, 3);
ffffffffc02008c8:	458d                	li	a1,3
ffffffffc02008ca:	8552                	mv	a0,s4
ffffffffc02008cc:	7de000ef          	jal	ra,ffffffffc02010aa <free_pages>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc02008d0:	0089b783          	ld	a5,8(s3)
    p2 = p0 + 1;
ffffffffc02008d4:	02898a93          	addi	s5,s3,40
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc02008d8:	8b89                	andi	a5,a5,2
ffffffffc02008da:	3c078b63          	beqz	a5,ffffffffc0200cb0 <default_check+0x60e>
ffffffffc02008de:	0109a703          	lw	a4,16(s3)
ffffffffc02008e2:	4785                	li	a5,1
ffffffffc02008e4:	3cf71663          	bne	a4,a5,ffffffffc0200cb0 <default_check+0x60e>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc02008e8:	008a3783          	ld	a5,8(s4)
ffffffffc02008ec:	8b89                	andi	a5,a5,2
ffffffffc02008ee:	3a078163          	beqz	a5,ffffffffc0200c90 <default_check+0x5ee>
ffffffffc02008f2:	010a2703          	lw	a4,16(s4)
ffffffffc02008f6:	478d                	li	a5,3
ffffffffc02008f8:	38f71c63          	bne	a4,a5,ffffffffc0200c90 <default_check+0x5ee>

    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc02008fc:	4505                	li	a0,1
ffffffffc02008fe:	7a0000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc0200902:	36a99763          	bne	s3,a0,ffffffffc0200c70 <default_check+0x5ce>
    free_page(p0);
ffffffffc0200906:	4585                	li	a1,1
ffffffffc0200908:	7a2000ef          	jal	ra,ffffffffc02010aa <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc020090c:	4509                	li	a0,2
ffffffffc020090e:	790000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc0200912:	32aa1f63          	bne	s4,a0,ffffffffc0200c50 <default_check+0x5ae>

    free_pages(p0, 2);
ffffffffc0200916:	4589                	li	a1,2
ffffffffc0200918:	792000ef          	jal	ra,ffffffffc02010aa <free_pages>
    free_page(p2);
ffffffffc020091c:	4585                	li	a1,1
ffffffffc020091e:	8556                	mv	a0,s5
ffffffffc0200920:	78a000ef          	jal	ra,ffffffffc02010aa <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200924:	4515                	li	a0,5
ffffffffc0200926:	778000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc020092a:	89aa                	mv	s3,a0
ffffffffc020092c:	48050263          	beqz	a0,ffffffffc0200db0 <default_check+0x70e>
    assert(alloc_page() == NULL);
ffffffffc0200930:	4505                	li	a0,1
ffffffffc0200932:	76c000ef          	jal	ra,ffffffffc020109e <alloc_pages>
ffffffffc0200936:	2c051d63          	bnez	a0,ffffffffc0200c10 <default_check+0x56e>

    assert(nr_free == 0);
ffffffffc020093a:	481c                	lw	a5,16(s0)
ffffffffc020093c:	2a079a63          	bnez	a5,ffffffffc0200bf0 <default_check+0x54e>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200940:	4595                	li	a1,5
ffffffffc0200942:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200944:	01842823          	sw	s8,16(s0)
    free_list = free_list_store;
ffffffffc0200948:	01743023          	sd	s7,0(s0)
ffffffffc020094c:	01643423          	sd	s6,8(s0)
    free_pages(p0, 5);
ffffffffc0200950:	75a000ef          	jal	ra,ffffffffc02010aa <free_pages>
    return listelm->next;
ffffffffc0200954:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200956:	00878963          	beq	a5,s0,ffffffffc0200968 <default_check+0x2c6>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc020095a:	ff87a703          	lw	a4,-8(a5)
ffffffffc020095e:	679c                	ld	a5,8(a5)
ffffffffc0200960:	397d                	addiw	s2,s2,-1
ffffffffc0200962:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200964:	fe879be3          	bne	a5,s0,ffffffffc020095a <default_check+0x2b8>
    }
    assert(count == 0);
ffffffffc0200968:	26091463          	bnez	s2,ffffffffc0200bd0 <default_check+0x52e>
    assert(total == 0);
ffffffffc020096c:	46049263          	bnez	s1,ffffffffc0200dd0 <default_check+0x72e>
}
ffffffffc0200970:	60a6                	ld	ra,72(sp)
ffffffffc0200972:	6406                	ld	s0,64(sp)
ffffffffc0200974:	74e2                	ld	s1,56(sp)
ffffffffc0200976:	7942                	ld	s2,48(sp)
ffffffffc0200978:	79a2                	ld	s3,40(sp)
ffffffffc020097a:	7a02                	ld	s4,32(sp)
ffffffffc020097c:	6ae2                	ld	s5,24(sp)
ffffffffc020097e:	6b42                	ld	s6,16(sp)
ffffffffc0200980:	6ba2                	ld	s7,8(sp)
ffffffffc0200982:	6c02                	ld	s8,0(sp)
ffffffffc0200984:	6161                	addi	sp,sp,80
ffffffffc0200986:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200988:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc020098a:	4481                	li	s1,0
ffffffffc020098c:	4901                	li	s2,0
ffffffffc020098e:	bb99                	j	ffffffffc02006e4 <default_check+0x42>
        assert(PageProperty(p));
ffffffffc0200990:	00001697          	auipc	a3,0x1
ffffffffc0200994:	03868693          	addi	a3,a3,56 # ffffffffc02019c8 <etext+0x29a>
ffffffffc0200998:	00001617          	auipc	a2,0x1
ffffffffc020099c:	00060613          	mv	a2,a2
ffffffffc02009a0:	0f000593          	li	a1,240
ffffffffc02009a4:	00001517          	auipc	a0,0x1
ffffffffc02009a8:	00c50513          	addi	a0,a0,12 # ffffffffc02019b0 <etext+0x282>
ffffffffc02009ac:	817ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02009b0:	00001697          	auipc	a3,0x1
ffffffffc02009b4:	0a868693          	addi	a3,a3,168 # ffffffffc0201a58 <etext+0x32a>
ffffffffc02009b8:	00001617          	auipc	a2,0x1
ffffffffc02009bc:	fe060613          	addi	a2,a2,-32 # ffffffffc0201998 <etext+0x26a>
ffffffffc02009c0:	0bd00593          	li	a1,189
ffffffffc02009c4:	00001517          	auipc	a0,0x1
ffffffffc02009c8:	fec50513          	addi	a0,a0,-20 # ffffffffc02019b0 <etext+0x282>
ffffffffc02009cc:	ff6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc02009d0:	00001697          	auipc	a3,0x1
ffffffffc02009d4:	0b068693          	addi	a3,a3,176 # ffffffffc0201a80 <etext+0x352>
ffffffffc02009d8:	00001617          	auipc	a2,0x1
ffffffffc02009dc:	fc060613          	addi	a2,a2,-64 # ffffffffc0201998 <etext+0x26a>
ffffffffc02009e0:	0be00593          	li	a1,190
ffffffffc02009e4:	00001517          	auipc	a0,0x1
ffffffffc02009e8:	fcc50513          	addi	a0,a0,-52 # ffffffffc02019b0 <etext+0x282>
ffffffffc02009ec:	fd6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009f0:	00001697          	auipc	a3,0x1
ffffffffc02009f4:	0d068693          	addi	a3,a3,208 # ffffffffc0201ac0 <etext+0x392>
ffffffffc02009f8:	00001617          	auipc	a2,0x1
ffffffffc02009fc:	fa060613          	addi	a2,a2,-96 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200a00:	0c000593          	li	a1,192
ffffffffc0200a04:	00001517          	auipc	a0,0x1
ffffffffc0200a08:	fac50513          	addi	a0,a0,-84 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200a0c:	fb6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200a10:	00001697          	auipc	a3,0x1
ffffffffc0200a14:	13868693          	addi	a3,a3,312 # ffffffffc0201b48 <etext+0x41a>
ffffffffc0200a18:	00001617          	auipc	a2,0x1
ffffffffc0200a1c:	f8060613          	addi	a2,a2,-128 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200a20:	0d900593          	li	a1,217
ffffffffc0200a24:	00001517          	auipc	a0,0x1
ffffffffc0200a28:	f8c50513          	addi	a0,a0,-116 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200a2c:	f96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a30:	00001697          	auipc	a3,0x1
ffffffffc0200a34:	fc868693          	addi	a3,a3,-56 # ffffffffc02019f8 <etext+0x2ca>
ffffffffc0200a38:	00001617          	auipc	a2,0x1
ffffffffc0200a3c:	f6060613          	addi	a2,a2,-160 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200a40:	0d200593          	li	a1,210
ffffffffc0200a44:	00001517          	auipc	a0,0x1
ffffffffc0200a48:	f6c50513          	addi	a0,a0,-148 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200a4c:	f76ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200a50:	00001697          	auipc	a3,0x1
ffffffffc0200a54:	0e868693          	addi	a3,a3,232 # ffffffffc0201b38 <etext+0x40a>
ffffffffc0200a58:	00001617          	auipc	a2,0x1
ffffffffc0200a5c:	f4060613          	addi	a2,a2,-192 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200a60:	0d000593          	li	a1,208
ffffffffc0200a64:	00001517          	auipc	a0,0x1
ffffffffc0200a68:	f4c50513          	addi	a0,a0,-180 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200a6c:	f56ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200a70:	00001697          	auipc	a3,0x1
ffffffffc0200a74:	0b068693          	addi	a3,a3,176 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200a78:	00001617          	auipc	a2,0x1
ffffffffc0200a7c:	f2060613          	addi	a2,a2,-224 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200a80:	0cb00593          	li	a1,203
ffffffffc0200a84:	00001517          	auipc	a0,0x1
ffffffffc0200a88:	f2c50513          	addi	a0,a0,-212 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200a8c:	f36ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200a90:	00001697          	auipc	a3,0x1
ffffffffc0200a94:	07068693          	addi	a3,a3,112 # ffffffffc0201b00 <etext+0x3d2>
ffffffffc0200a98:	00001617          	auipc	a2,0x1
ffffffffc0200a9c:	f0060613          	addi	a2,a2,-256 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200aa0:	0c200593          	li	a1,194
ffffffffc0200aa4:	00001517          	auipc	a0,0x1
ffffffffc0200aa8:	f0c50513          	addi	a0,a0,-244 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200aac:	f16ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200ab0:	00001697          	auipc	a3,0x1
ffffffffc0200ab4:	0e068693          	addi	a3,a3,224 # ffffffffc0201b90 <etext+0x462>
ffffffffc0200ab8:	00001617          	auipc	a2,0x1
ffffffffc0200abc:	ee060613          	addi	a2,a2,-288 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200ac0:	0f800593          	li	a1,248
ffffffffc0200ac4:	00001517          	auipc	a0,0x1
ffffffffc0200ac8:	eec50513          	addi	a0,a0,-276 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200acc:	ef6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200ad0:	00001697          	auipc	a3,0x1
ffffffffc0200ad4:	0b068693          	addi	a3,a3,176 # ffffffffc0201b80 <etext+0x452>
ffffffffc0200ad8:	00001617          	auipc	a2,0x1
ffffffffc0200adc:	ec060613          	addi	a2,a2,-320 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200ae0:	0df00593          	li	a1,223
ffffffffc0200ae4:	00001517          	auipc	a0,0x1
ffffffffc0200ae8:	ecc50513          	addi	a0,a0,-308 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200aec:	ed6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200af0:	00001697          	auipc	a3,0x1
ffffffffc0200af4:	03068693          	addi	a3,a3,48 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200af8:	00001617          	auipc	a2,0x1
ffffffffc0200afc:	ea060613          	addi	a2,a2,-352 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200b00:	0dd00593          	li	a1,221
ffffffffc0200b04:	00001517          	auipc	a0,0x1
ffffffffc0200b08:	eac50513          	addi	a0,a0,-340 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200b0c:	eb6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200b10:	00001697          	auipc	a3,0x1
ffffffffc0200b14:	05068693          	addi	a3,a3,80 # ffffffffc0201b60 <etext+0x432>
ffffffffc0200b18:	00001617          	auipc	a2,0x1
ffffffffc0200b1c:	e8060613          	addi	a2,a2,-384 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200b20:	0dc00593          	li	a1,220
ffffffffc0200b24:	00001517          	auipc	a0,0x1
ffffffffc0200b28:	e8c50513          	addi	a0,a0,-372 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200b2c:	e96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200b30:	00001697          	auipc	a3,0x1
ffffffffc0200b34:	ec868693          	addi	a3,a3,-312 # ffffffffc02019f8 <etext+0x2ca>
ffffffffc0200b38:	00001617          	auipc	a2,0x1
ffffffffc0200b3c:	e6060613          	addi	a2,a2,-416 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200b40:	0b900593          	li	a1,185
ffffffffc0200b44:	00001517          	auipc	a0,0x1
ffffffffc0200b48:	e6c50513          	addi	a0,a0,-404 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200b4c:	e76ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b50:	00001697          	auipc	a3,0x1
ffffffffc0200b54:	fd068693          	addi	a3,a3,-48 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200b58:	00001617          	auipc	a2,0x1
ffffffffc0200b5c:	e4060613          	addi	a2,a2,-448 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200b60:	0d600593          	li	a1,214
ffffffffc0200b64:	00001517          	auipc	a0,0x1
ffffffffc0200b68:	e4c50513          	addi	a0,a0,-436 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200b6c:	e56ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200b70:	00001697          	auipc	a3,0x1
ffffffffc0200b74:	ec868693          	addi	a3,a3,-312 # ffffffffc0201a38 <etext+0x30a>
ffffffffc0200b78:	00001617          	auipc	a2,0x1
ffffffffc0200b7c:	e2060613          	addi	a2,a2,-480 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200b80:	0d400593          	li	a1,212
ffffffffc0200b84:	00001517          	auipc	a0,0x1
ffffffffc0200b88:	e2c50513          	addi	a0,a0,-468 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200b8c:	e36ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200b90:	00001697          	auipc	a3,0x1
ffffffffc0200b94:	e8868693          	addi	a3,a3,-376 # ffffffffc0201a18 <etext+0x2ea>
ffffffffc0200b98:	00001617          	auipc	a2,0x1
ffffffffc0200b9c:	e0060613          	addi	a2,a2,-512 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200ba0:	0d300593          	li	a1,211
ffffffffc0200ba4:	00001517          	auipc	a0,0x1
ffffffffc0200ba8:	e0c50513          	addi	a0,a0,-500 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200bac:	e16ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200bb0:	00001697          	auipc	a3,0x1
ffffffffc0200bb4:	e8868693          	addi	a3,a3,-376 # ffffffffc0201a38 <etext+0x30a>
ffffffffc0200bb8:	00001617          	auipc	a2,0x1
ffffffffc0200bbc:	de060613          	addi	a2,a2,-544 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200bc0:	0bb00593          	li	a1,187
ffffffffc0200bc4:	00001517          	auipc	a0,0x1
ffffffffc0200bc8:	dec50513          	addi	a0,a0,-532 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200bcc:	df6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200bd0:	00001697          	auipc	a3,0x1
ffffffffc0200bd4:	11068693          	addi	a3,a3,272 # ffffffffc0201ce0 <etext+0x5b2>
ffffffffc0200bd8:	00001617          	auipc	a2,0x1
ffffffffc0200bdc:	dc060613          	addi	a2,a2,-576 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200be0:	12500593          	li	a1,293
ffffffffc0200be4:	00001517          	auipc	a0,0x1
ffffffffc0200be8:	dcc50513          	addi	a0,a0,-564 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200bec:	dd6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200bf0:	00001697          	auipc	a3,0x1
ffffffffc0200bf4:	f9068693          	addi	a3,a3,-112 # ffffffffc0201b80 <etext+0x452>
ffffffffc0200bf8:	00001617          	auipc	a2,0x1
ffffffffc0200bfc:	da060613          	addi	a2,a2,-608 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200c00:	11a00593          	li	a1,282
ffffffffc0200c04:	00001517          	auipc	a0,0x1
ffffffffc0200c08:	dac50513          	addi	a0,a0,-596 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200c0c:	db6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200c10:	00001697          	auipc	a3,0x1
ffffffffc0200c14:	f1068693          	addi	a3,a3,-240 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200c18:	00001617          	auipc	a2,0x1
ffffffffc0200c1c:	d8060613          	addi	a2,a2,-640 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200c20:	11800593          	li	a1,280
ffffffffc0200c24:	00001517          	auipc	a0,0x1
ffffffffc0200c28:	d8c50513          	addi	a0,a0,-628 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200c2c:	d96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200c30:	00001697          	auipc	a3,0x1
ffffffffc0200c34:	eb068693          	addi	a3,a3,-336 # ffffffffc0201ae0 <etext+0x3b2>
ffffffffc0200c38:	00001617          	auipc	a2,0x1
ffffffffc0200c3c:	d6060613          	addi	a2,a2,-672 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200c40:	0c100593          	li	a1,193
ffffffffc0200c44:	00001517          	auipc	a0,0x1
ffffffffc0200c48:	d6c50513          	addi	a0,a0,-660 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200c4c:	d76ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0200c50:	00001697          	auipc	a3,0x1
ffffffffc0200c54:	05068693          	addi	a3,a3,80 # ffffffffc0201ca0 <etext+0x572>
ffffffffc0200c58:	00001617          	auipc	a2,0x1
ffffffffc0200c5c:	d4060613          	addi	a2,a2,-704 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200c60:	11200593          	li	a1,274
ffffffffc0200c64:	00001517          	auipc	a0,0x1
ffffffffc0200c68:	d4c50513          	addi	a0,a0,-692 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200c6c:	d56ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0200c70:	00001697          	auipc	a3,0x1
ffffffffc0200c74:	01068693          	addi	a3,a3,16 # ffffffffc0201c80 <etext+0x552>
ffffffffc0200c78:	00001617          	auipc	a2,0x1
ffffffffc0200c7c:	d2060613          	addi	a2,a2,-736 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200c80:	11000593          	li	a1,272
ffffffffc0200c84:	00001517          	auipc	a0,0x1
ffffffffc0200c88:	d2c50513          	addi	a0,a0,-724 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200c8c:	d36ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc0200c90:	00001697          	auipc	a3,0x1
ffffffffc0200c94:	fc868693          	addi	a3,a3,-56 # ffffffffc0201c58 <etext+0x52a>
ffffffffc0200c98:	00001617          	auipc	a2,0x1
ffffffffc0200c9c:	d0060613          	addi	a2,a2,-768 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200ca0:	10e00593          	li	a1,270
ffffffffc0200ca4:	00001517          	auipc	a0,0x1
ffffffffc0200ca8:	d0c50513          	addi	a0,a0,-756 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200cac:	d16ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200cb0:	00001697          	auipc	a3,0x1
ffffffffc0200cb4:	f8068693          	addi	a3,a3,-128 # ffffffffc0201c30 <etext+0x502>
ffffffffc0200cb8:	00001617          	auipc	a2,0x1
ffffffffc0200cbc:	ce060613          	addi	a2,a2,-800 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200cc0:	10d00593          	li	a1,269
ffffffffc0200cc4:	00001517          	auipc	a0,0x1
ffffffffc0200cc8:	cec50513          	addi	a0,a0,-788 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200ccc:	cf6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 2 == p1);
ffffffffc0200cd0:	00001697          	auipc	a3,0x1
ffffffffc0200cd4:	f5068693          	addi	a3,a3,-176 # ffffffffc0201c20 <etext+0x4f2>
ffffffffc0200cd8:	00001617          	auipc	a2,0x1
ffffffffc0200cdc:	cc060613          	addi	a2,a2,-832 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200ce0:	10800593          	li	a1,264
ffffffffc0200ce4:	00001517          	auipc	a0,0x1
ffffffffc0200ce8:	ccc50513          	addi	a0,a0,-820 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200cec:	cd6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200cf0:	00001697          	auipc	a3,0x1
ffffffffc0200cf4:	e3068693          	addi	a3,a3,-464 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200cf8:	00001617          	auipc	a2,0x1
ffffffffc0200cfc:	ca060613          	addi	a2,a2,-864 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200d00:	10700593          	li	a1,263
ffffffffc0200d04:	00001517          	auipc	a0,0x1
ffffffffc0200d08:	cac50513          	addi	a0,a0,-852 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200d0c:	cb6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0200d10:	00001697          	auipc	a3,0x1
ffffffffc0200d14:	ef068693          	addi	a3,a3,-272 # ffffffffc0201c00 <etext+0x4d2>
ffffffffc0200d18:	00001617          	auipc	a2,0x1
ffffffffc0200d1c:	c8060613          	addi	a2,a2,-896 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200d20:	10600593          	li	a1,262
ffffffffc0200d24:	00001517          	auipc	a0,0x1
ffffffffc0200d28:	c8c50513          	addi	a0,a0,-884 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200d2c:	c96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200d30:	00001697          	auipc	a3,0x1
ffffffffc0200d34:	ea068693          	addi	a3,a3,-352 # ffffffffc0201bd0 <etext+0x4a2>
ffffffffc0200d38:	00001617          	auipc	a2,0x1
ffffffffc0200d3c:	c6060613          	addi	a2,a2,-928 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200d40:	10500593          	li	a1,261
ffffffffc0200d44:	00001517          	auipc	a0,0x1
ffffffffc0200d48:	c6c50513          	addi	a0,a0,-916 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200d4c:	c76ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200d50:	00001697          	auipc	a3,0x1
ffffffffc0200d54:	e6868693          	addi	a3,a3,-408 # ffffffffc0201bb8 <etext+0x48a>
ffffffffc0200d58:	00001617          	auipc	a2,0x1
ffffffffc0200d5c:	c4060613          	addi	a2,a2,-960 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200d60:	10400593          	li	a1,260
ffffffffc0200d64:	00001517          	auipc	a0,0x1
ffffffffc0200d68:	c4c50513          	addi	a0,a0,-948 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200d6c:	c56ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d70:	00001697          	auipc	a3,0x1
ffffffffc0200d74:	db068693          	addi	a3,a3,-592 # ffffffffc0201b20 <etext+0x3f2>
ffffffffc0200d78:	00001617          	auipc	a2,0x1
ffffffffc0200d7c:	c2060613          	addi	a2,a2,-992 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200d80:	0fe00593          	li	a1,254
ffffffffc0200d84:	00001517          	auipc	a0,0x1
ffffffffc0200d88:	c2c50513          	addi	a0,a0,-980 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200d8c:	c36ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200d90:	00001697          	auipc	a3,0x1
ffffffffc0200d94:	e1068693          	addi	a3,a3,-496 # ffffffffc0201ba0 <etext+0x472>
ffffffffc0200d98:	00001617          	auipc	a2,0x1
ffffffffc0200d9c:	c0060613          	addi	a2,a2,-1024 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200da0:	0f900593          	li	a1,249
ffffffffc0200da4:	00001517          	auipc	a0,0x1
ffffffffc0200da8:	c0c50513          	addi	a0,a0,-1012 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200dac:	c16ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200db0:	00001697          	auipc	a3,0x1
ffffffffc0200db4:	f1068693          	addi	a3,a3,-240 # ffffffffc0201cc0 <etext+0x592>
ffffffffc0200db8:	00001617          	auipc	a2,0x1
ffffffffc0200dbc:	be060613          	addi	a2,a2,-1056 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200dc0:	11700593          	li	a1,279
ffffffffc0200dc4:	00001517          	auipc	a0,0x1
ffffffffc0200dc8:	bec50513          	addi	a0,a0,-1044 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200dcc:	bf6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0200dd0:	00001697          	auipc	a3,0x1
ffffffffc0200dd4:	f2068693          	addi	a3,a3,-224 # ffffffffc0201cf0 <etext+0x5c2>
ffffffffc0200dd8:	00001617          	auipc	a2,0x1
ffffffffc0200ddc:	bc060613          	addi	a2,a2,-1088 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200de0:	12600593          	li	a1,294
ffffffffc0200de4:	00001517          	auipc	a0,0x1
ffffffffc0200de8:	bcc50513          	addi	a0,a0,-1076 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200dec:	bd6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200df0:	00001697          	auipc	a3,0x1
ffffffffc0200df4:	be868693          	addi	a3,a3,-1048 # ffffffffc02019d8 <etext+0x2aa>
ffffffffc0200df8:	00001617          	auipc	a2,0x1
ffffffffc0200dfc:	ba060613          	addi	a2,a2,-1120 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200e00:	0f300593          	li	a1,243
ffffffffc0200e04:	00001517          	auipc	a0,0x1
ffffffffc0200e08:	bac50513          	addi	a0,a0,-1108 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200e0c:	bb6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200e10:	00001697          	auipc	a3,0x1
ffffffffc0200e14:	c0868693          	addi	a3,a3,-1016 # ffffffffc0201a18 <etext+0x2ea>
ffffffffc0200e18:	00001617          	auipc	a2,0x1
ffffffffc0200e1c:	b8060613          	addi	a2,a2,-1152 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200e20:	0ba00593          	li	a1,186
ffffffffc0200e24:	00001517          	auipc	a0,0x1
ffffffffc0200e28:	b8c50513          	addi	a0,a0,-1140 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200e2c:	b96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200e30 <default_free_pages>:
default_free_pages(struct Page *base, size_t n) {
ffffffffc0200e30:	1141                	addi	sp,sp,-16
ffffffffc0200e32:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200e34:	14058c63          	beqz	a1,ffffffffc0200f8c <default_free_pages+0x15c>
    for (; p != base + n; p ++) {
ffffffffc0200e38:	00259693          	slli	a3,a1,0x2
ffffffffc0200e3c:	96ae                	add	a3,a3,a1
ffffffffc0200e3e:	068e                	slli	a3,a3,0x3
ffffffffc0200e40:	96aa                	add	a3,a3,a0
ffffffffc0200e42:	87aa                	mv	a5,a0
ffffffffc0200e44:	00d50e63          	beq	a0,a3,ffffffffc0200e60 <default_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e48:	6798                	ld	a4,8(a5)
ffffffffc0200e4a:	8b0d                	andi	a4,a4,3
ffffffffc0200e4c:	12071063          	bnez	a4,ffffffffc0200f6c <default_free_pages+0x13c>
        p->flags = 0;
ffffffffc0200e50:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200e54:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200e58:	02878793          	addi	a5,a5,40
ffffffffc0200e5c:	fed796e3          	bne	a5,a3,ffffffffc0200e48 <default_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200e60:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc0200e64:	00005697          	auipc	a3,0x5
ffffffffc0200e68:	1b468693          	addi	a3,a3,436 # ffffffffc0206018 <free_area>
ffffffffc0200e6c:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200e6e:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200e70:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc0200e74:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200e76:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200e78:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200e7a:	9f2d                	addw	a4,a4,a1
ffffffffc0200e7c:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200e7e:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200e82:	0ad78b63          	beq	a5,a3,ffffffffc0200f38 <default_free_pages+0x108>
            struct Page* page = le2page(le, page_link);
ffffffffc0200e86:	fe878713          	addi	a4,a5,-24
ffffffffc0200e8a:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200e8e:	4801                	li	a6,0
            if (base < page) {
ffffffffc0200e90:	00e56a63          	bltu	a0,a4,ffffffffc0200ea4 <default_free_pages+0x74>
    return listelm->next;
ffffffffc0200e94:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200e96:	06d70563          	beq	a4,a3,ffffffffc0200f00 <default_free_pages+0xd0>
    for (; p != base + n; p ++) {
ffffffffc0200e9a:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0200e9c:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200ea0:	fee57ae3          	bgeu	a0,a4,ffffffffc0200e94 <default_free_pages+0x64>
ffffffffc0200ea4:	00080463          	beqz	a6,ffffffffc0200eac <default_free_pages+0x7c>
ffffffffc0200ea8:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200eac:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc0200eb0:	e390                	sd	a2,0(a5)
ffffffffc0200eb2:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc0200eb6:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200eb8:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc0200ebc:	02d80463          	beq	a6,a3,ffffffffc0200ee4 <default_free_pages+0xb4>
        if (p + p->property == base) {
ffffffffc0200ec0:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc0200ec4:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc0200ec8:	020e1613          	slli	a2,t3,0x20
ffffffffc0200ecc:	9201                	srli	a2,a2,0x20
ffffffffc0200ece:	00261713          	slli	a4,a2,0x2
ffffffffc0200ed2:	9732                	add	a4,a4,a2
ffffffffc0200ed4:	070e                	slli	a4,a4,0x3
ffffffffc0200ed6:	971a                	add	a4,a4,t1
ffffffffc0200ed8:	02e50e63          	beq	a0,a4,ffffffffc0200f14 <default_free_pages+0xe4>
    if (le != &free_list) {
ffffffffc0200edc:	00d78f63          	beq	a5,a3,ffffffffc0200efa <default_free_pages+0xca>
ffffffffc0200ee0:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc0200ee4:	490c                	lw	a1,16(a0)
ffffffffc0200ee6:	02059613          	slli	a2,a1,0x20
ffffffffc0200eea:	9201                	srli	a2,a2,0x20
ffffffffc0200eec:	00261693          	slli	a3,a2,0x2
ffffffffc0200ef0:	96b2                	add	a3,a3,a2
ffffffffc0200ef2:	068e                	slli	a3,a3,0x3
ffffffffc0200ef4:	96aa                	add	a3,a3,a0
ffffffffc0200ef6:	04d70863          	beq	a4,a3,ffffffffc0200f46 <default_free_pages+0x116>
}
ffffffffc0200efa:	60a2                	ld	ra,8(sp)
ffffffffc0200efc:	0141                	addi	sp,sp,16
ffffffffc0200efe:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200f00:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f02:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200f04:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200f06:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200f08:	02d70463          	beq	a4,a3,ffffffffc0200f30 <default_free_pages+0x100>
    prev->next = next->prev = elm;
ffffffffc0200f0c:	8332                	mv	t1,a2
ffffffffc0200f0e:	4805                	li	a6,1
    for (; p != base + n; p ++) {
ffffffffc0200f10:	87ba                	mv	a5,a4
ffffffffc0200f12:	b769                	j	ffffffffc0200e9c <default_free_pages+0x6c>
            p->property += base->property;
ffffffffc0200f14:	01c585bb          	addw	a1,a1,t3
ffffffffc0200f18:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc0200f1c:	ffd8f893          	andi	a7,a7,-3
ffffffffc0200f20:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc0200f24:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc0200f28:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc0200f2c:	851a                	mv	a0,t1
ffffffffc0200f2e:	b77d                	j	ffffffffc0200edc <default_free_pages+0xac>
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200f30:	883e                	mv	a6,a5
ffffffffc0200f32:	e290                	sd	a2,0(a3)
ffffffffc0200f34:	87b6                	mv	a5,a3
ffffffffc0200f36:	b769                	j	ffffffffc0200ec0 <default_free_pages+0x90>
}
ffffffffc0200f38:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200f3a:	e390                	sd	a2,0(a5)
ffffffffc0200f3c:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f3e:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f40:	ed1c                	sd	a5,24(a0)
ffffffffc0200f42:	0141                	addi	sp,sp,16
ffffffffc0200f44:	8082                	ret
            base->property += p->property;
ffffffffc0200f46:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc0200f4a:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200f4e:	0007b803          	ld	a6,0(a5)
ffffffffc0200f52:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc0200f54:	9db5                	addw	a1,a1,a3
ffffffffc0200f56:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc0200f58:	9b75                	andi	a4,a4,-3
ffffffffc0200f5a:	fee7b823          	sd	a4,-16(a5)
}
ffffffffc0200f5e:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc0200f60:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc0200f64:	01063023          	sd	a6,0(a2)
ffffffffc0200f68:	0141                	addi	sp,sp,16
ffffffffc0200f6a:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200f6c:	00001697          	auipc	a3,0x1
ffffffffc0200f70:	d9468693          	addi	a3,a3,-620 # ffffffffc0201d00 <etext+0x5d2>
ffffffffc0200f74:	00001617          	auipc	a2,0x1
ffffffffc0200f78:	a2460613          	addi	a2,a2,-1500 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200f7c:	08300593          	li	a1,131
ffffffffc0200f80:	00001517          	auipc	a0,0x1
ffffffffc0200f84:	a3050513          	addi	a0,a0,-1488 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200f88:	a3aff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200f8c:	00001697          	auipc	a3,0x1
ffffffffc0200f90:	a0468693          	addi	a3,a3,-1532 # ffffffffc0201990 <etext+0x262>
ffffffffc0200f94:	00001617          	auipc	a2,0x1
ffffffffc0200f98:	a0460613          	addi	a2,a2,-1532 # ffffffffc0201998 <etext+0x26a>
ffffffffc0200f9c:	08000593          	li	a1,128
ffffffffc0200fa0:	00001517          	auipc	a0,0x1
ffffffffc0200fa4:	a1050513          	addi	a0,a0,-1520 # ffffffffc02019b0 <etext+0x282>
ffffffffc0200fa8:	a1aff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200fac <default_init_memmap>:
default_init_memmap(struct Page *base, size_t n) {
ffffffffc0200fac:	1141                	addi	sp,sp,-16
ffffffffc0200fae:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200fb0:	c5f9                	beqz	a1,ffffffffc020107e <default_init_memmap+0xd2>
    for (; p != base + n; p ++) {
ffffffffc0200fb2:	00259693          	slli	a3,a1,0x2
ffffffffc0200fb6:	96ae                	add	a3,a3,a1
ffffffffc0200fb8:	068e                	slli	a3,a3,0x3
ffffffffc0200fba:	96aa                	add	a3,a3,a0
ffffffffc0200fbc:	87aa                	mv	a5,a0
ffffffffc0200fbe:	00d50f63          	beq	a0,a3,ffffffffc0200fdc <default_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200fc2:	6798                	ld	a4,8(a5)
ffffffffc0200fc4:	8b05                	andi	a4,a4,1
ffffffffc0200fc6:	cf41                	beqz	a4,ffffffffc020105e <default_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc0200fc8:	0007a823          	sw	zero,16(a5)
ffffffffc0200fcc:	0007b423          	sd	zero,8(a5)
ffffffffc0200fd0:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200fd4:	02878793          	addi	a5,a5,40
ffffffffc0200fd8:	fed795e3          	bne	a5,a3,ffffffffc0200fc2 <default_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200fdc:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200fde:	00005697          	auipc	a3,0x5
ffffffffc0200fe2:	03a68693          	addi	a3,a3,58 # ffffffffc0206018 <free_area>
ffffffffc0200fe6:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200fe8:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200fea:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0200fee:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200ff0:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200ff2:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200ff4:	9db9                	addw	a1,a1,a4
ffffffffc0200ff6:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200ff8:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200ffc:	04d78a63          	beq	a5,a3,ffffffffc0201050 <default_init_memmap+0xa4>
            struct Page* page = le2page(le, page_link);
ffffffffc0201000:	fe878713          	addi	a4,a5,-24
ffffffffc0201004:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0201008:	4581                	li	a1,0
            if (base < page) {
ffffffffc020100a:	00e56a63          	bltu	a0,a4,ffffffffc020101e <default_init_memmap+0x72>
    return listelm->next;
ffffffffc020100e:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0201010:	02d70263          	beq	a4,a3,ffffffffc0201034 <default_init_memmap+0x88>
    for (; p != base + n; p ++) {
ffffffffc0201014:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0201016:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc020101a:	fee57ae3          	bgeu	a0,a4,ffffffffc020100e <default_init_memmap+0x62>
ffffffffc020101e:	c199                	beqz	a1,ffffffffc0201024 <default_init_memmap+0x78>
ffffffffc0201020:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0201024:	6398                	ld	a4,0(a5)
}
ffffffffc0201026:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0201028:	e390                	sd	a2,0(a5)
ffffffffc020102a:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc020102c:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020102e:	ed18                	sd	a4,24(a0)
ffffffffc0201030:	0141                	addi	sp,sp,16
ffffffffc0201032:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0201034:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201036:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0201038:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc020103a:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc020103c:	00d70663          	beq	a4,a3,ffffffffc0201048 <default_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc0201040:	8832                	mv	a6,a2
ffffffffc0201042:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc0201044:	87ba                	mv	a5,a4
ffffffffc0201046:	bfc1                	j	ffffffffc0201016 <default_init_memmap+0x6a>
}
ffffffffc0201048:	60a2                	ld	ra,8(sp)
ffffffffc020104a:	e290                	sd	a2,0(a3)
ffffffffc020104c:	0141                	addi	sp,sp,16
ffffffffc020104e:	8082                	ret
ffffffffc0201050:	60a2                	ld	ra,8(sp)
ffffffffc0201052:	e390                	sd	a2,0(a5)
ffffffffc0201054:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201056:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201058:	ed1c                	sd	a5,24(a0)
ffffffffc020105a:	0141                	addi	sp,sp,16
ffffffffc020105c:	8082                	ret
        assert(PageReserved(p));
ffffffffc020105e:	00001697          	auipc	a3,0x1
ffffffffc0201062:	cca68693          	addi	a3,a3,-822 # ffffffffc0201d28 <etext+0x5fa>
ffffffffc0201066:	00001617          	auipc	a2,0x1
ffffffffc020106a:	93260613          	addi	a2,a2,-1742 # ffffffffc0201998 <etext+0x26a>
ffffffffc020106e:	04900593          	li	a1,73
ffffffffc0201072:	00001517          	auipc	a0,0x1
ffffffffc0201076:	93e50513          	addi	a0,a0,-1730 # ffffffffc02019b0 <etext+0x282>
ffffffffc020107a:	948ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc020107e:	00001697          	auipc	a3,0x1
ffffffffc0201082:	91268693          	addi	a3,a3,-1774 # ffffffffc0201990 <etext+0x262>
ffffffffc0201086:	00001617          	auipc	a2,0x1
ffffffffc020108a:	91260613          	addi	a2,a2,-1774 # ffffffffc0201998 <etext+0x26a>
ffffffffc020108e:	04600593          	li	a1,70
ffffffffc0201092:	00001517          	auipc	a0,0x1
ffffffffc0201096:	91e50513          	addi	a0,a0,-1762 # ffffffffc02019b0 <etext+0x282>
ffffffffc020109a:	928ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020109e <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc020109e:	00005797          	auipc	a5,0x5
ffffffffc02010a2:	fba7b783          	ld	a5,-70(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02010a6:	6f9c                	ld	a5,24(a5)
ffffffffc02010a8:	8782                	jr	a5

ffffffffc02010aa <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc02010aa:	00005797          	auipc	a5,0x5
ffffffffc02010ae:	fae7b783          	ld	a5,-82(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02010b2:	739c                	ld	a5,32(a5)
ffffffffc02010b4:	8782                	jr	a5

ffffffffc02010b6 <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc02010b6:	00005797          	auipc	a5,0x5
ffffffffc02010ba:	fa27b783          	ld	a5,-94(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02010be:	779c                	ld	a5,40(a5)
ffffffffc02010c0:	8782                	jr	a5

ffffffffc02010c2 <pmm_init>:
    pmm_manager = &default_pmm_manager;
ffffffffc02010c2:	00001797          	auipc	a5,0x1
ffffffffc02010c6:	c8e78793          	addi	a5,a5,-882 # ffffffffc0201d50 <default_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02010ca:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02010cc:	7179                	addi	sp,sp,-48
ffffffffc02010ce:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02010d0:	00001517          	auipc	a0,0x1
ffffffffc02010d4:	cb850513          	addi	a0,a0,-840 # ffffffffc0201d88 <default_pmm_manager+0x38>
    pmm_manager = &default_pmm_manager;
ffffffffc02010d8:	00005417          	auipc	s0,0x5
ffffffffc02010dc:	f8040413          	addi	s0,s0,-128 # ffffffffc0206058 <pmm_manager>
void pmm_init(void) {
ffffffffc02010e0:	f406                	sd	ra,40(sp)
ffffffffc02010e2:	ec26                	sd	s1,24(sp)
ffffffffc02010e4:	e44e                	sd	s3,8(sp)
ffffffffc02010e6:	e84a                	sd	s2,16(sp)
ffffffffc02010e8:	e052                	sd	s4,0(sp)
    pmm_manager = &default_pmm_manager;
ffffffffc02010ea:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02010ec:	860ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc02010f0:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc02010f2:	00005497          	auipc	s1,0x5
ffffffffc02010f6:	f7e48493          	addi	s1,s1,-130 # ffffffffc0206070 <va_pa_offset>
    pmm_manager->init();
ffffffffc02010fa:	679c                	ld	a5,8(a5)
ffffffffc02010fc:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc02010fe:	57f5                	li	a5,-3
ffffffffc0201100:	07fa                	slli	a5,a5,0x1e
ffffffffc0201102:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0201104:	cb8ff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0201108:	89aa                	mv	s3,a0
    uint64_t mem_size  = get_memory_size();
ffffffffc020110a:	cbcff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_size == 0) {
ffffffffc020110e:	14050d63          	beqz	a0,ffffffffc0201268 <pmm_init+0x1a6>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0201112:	892a                	mv	s2,a0
    cprintf("physcial memory map:\n");
ffffffffc0201114:	00001517          	auipc	a0,0x1
ffffffffc0201118:	cbc50513          	addi	a0,a0,-836 # ffffffffc0201dd0 <default_pmm_manager+0x80>
ffffffffc020111c:	830ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uint64_t mem_end   = mem_begin + mem_size;
ffffffffc0201120:	01298a33          	add	s4,s3,s2
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", mem_size, mem_begin,
ffffffffc0201124:	864e                	mv	a2,s3
ffffffffc0201126:	fffa0693          	addi	a3,s4,-1
ffffffffc020112a:	85ca                	mv	a1,s2
ffffffffc020112c:	00001517          	auipc	a0,0x1
ffffffffc0201130:	cbc50513          	addi	a0,a0,-836 # ffffffffc0201de8 <default_pmm_manager+0x98>
ffffffffc0201134:	818ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0201138:	c80007b7          	lui	a5,0xc8000
ffffffffc020113c:	8652                	mv	a2,s4
ffffffffc020113e:	0d47e463          	bltu	a5,s4,ffffffffc0201206 <pmm_init+0x144>
ffffffffc0201142:	00006797          	auipc	a5,0x6
ffffffffc0201146:	f3578793          	addi	a5,a5,-203 # ffffffffc0207077 <end+0xfff>
ffffffffc020114a:	757d                	lui	a0,0xfffff
ffffffffc020114c:	8d7d                	and	a0,a0,a5
ffffffffc020114e:	8231                	srli	a2,a2,0xc
ffffffffc0201150:	00005797          	auipc	a5,0x5
ffffffffc0201154:	eec7bc23          	sd	a2,-264(a5) # ffffffffc0206048 <npage>
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc0201158:	00005797          	auipc	a5,0x5
ffffffffc020115c:	eea7bc23          	sd	a0,-264(a5) # ffffffffc0206050 <pages>
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0201160:	000807b7          	lui	a5,0x80
ffffffffc0201164:	002005b7          	lui	a1,0x200
ffffffffc0201168:	02f60563          	beq	a2,a5,ffffffffc0201192 <pmm_init+0xd0>
ffffffffc020116c:	00261593          	slli	a1,a2,0x2
ffffffffc0201170:	00c586b3          	add	a3,a1,a2
ffffffffc0201174:	fec007b7          	lui	a5,0xfec00
ffffffffc0201178:	97aa                	add	a5,a5,a0
ffffffffc020117a:	068e                	slli	a3,a3,0x3
ffffffffc020117c:	96be                	add	a3,a3,a5
ffffffffc020117e:	87aa                	mv	a5,a0
        SetPageReserved(pages + i);
ffffffffc0201180:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc0201182:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f9fb0>
        SetPageReserved(pages + i);
ffffffffc0201186:	00176713          	ori	a4,a4,1
ffffffffc020118a:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc020118e:	fef699e3          	bne	a3,a5,ffffffffc0201180 <pmm_init+0xbe>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0201192:	95b2                	add	a1,a1,a2
ffffffffc0201194:	fec006b7          	lui	a3,0xfec00
ffffffffc0201198:	96aa                	add	a3,a3,a0
ffffffffc020119a:	058e                	slli	a1,a1,0x3
ffffffffc020119c:	96ae                	add	a3,a3,a1
ffffffffc020119e:	c02007b7          	lui	a5,0xc0200
ffffffffc02011a2:	0af6e763          	bltu	a3,a5,ffffffffc0201250 <pmm_init+0x18e>
ffffffffc02011a6:	6098                	ld	a4,0(s1)
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc02011a8:	77fd                	lui	a5,0xfffff
ffffffffc02011aa:	00fa75b3          	and	a1,s4,a5
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc02011ae:	8e99                	sub	a3,a3,a4
    if (freemem < mem_end) {
ffffffffc02011b0:	04b6ee63          	bltu	a3,a1,ffffffffc020120c <pmm_init+0x14a>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02011b4:	601c                	ld	a5,0(s0)
ffffffffc02011b6:	7b9c                	ld	a5,48(a5)
ffffffffc02011b8:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02011ba:	00001517          	auipc	a0,0x1
ffffffffc02011be:	cb650513          	addi	a0,a0,-842 # ffffffffc0201e70 <default_pmm_manager+0x120>
ffffffffc02011c2:	f8bfe0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02011c6:	00004597          	auipc	a1,0x4
ffffffffc02011ca:	e3a58593          	addi	a1,a1,-454 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc02011ce:	00005797          	auipc	a5,0x5
ffffffffc02011d2:	e8b7bd23          	sd	a1,-358(a5) # ffffffffc0206068 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc02011d6:	c02007b7          	lui	a5,0xc0200
ffffffffc02011da:	0af5e363          	bltu	a1,a5,ffffffffc0201280 <pmm_init+0x1be>
ffffffffc02011de:	6090                	ld	a2,0(s1)
}
ffffffffc02011e0:	7402                	ld	s0,32(sp)
ffffffffc02011e2:	70a2                	ld	ra,40(sp)
ffffffffc02011e4:	64e2                	ld	s1,24(sp)
ffffffffc02011e6:	6942                	ld	s2,16(sp)
ffffffffc02011e8:	69a2                	ld	s3,8(sp)
ffffffffc02011ea:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc02011ec:	40c58633          	sub	a2,a1,a2
ffffffffc02011f0:	00005797          	auipc	a5,0x5
ffffffffc02011f4:	e6c7b823          	sd	a2,-400(a5) # ffffffffc0206060 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc02011f8:	00001517          	auipc	a0,0x1
ffffffffc02011fc:	c9850513          	addi	a0,a0,-872 # ffffffffc0201e90 <default_pmm_manager+0x140>
}
ffffffffc0201200:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201202:	f4bfe06f          	j	ffffffffc020014c <cprintf>
    npage = maxpa / PGSIZE;
ffffffffc0201206:	c8000637          	lui	a2,0xc8000
ffffffffc020120a:	bf25                	j	ffffffffc0201142 <pmm_init+0x80>
    mem_begin = ROUNDUP(freemem, PGSIZE);
ffffffffc020120c:	6705                	lui	a4,0x1
ffffffffc020120e:	177d                	addi	a4,a4,-1
ffffffffc0201210:	96ba                	add	a3,a3,a4
ffffffffc0201212:	8efd                	and	a3,a3,a5
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201214:	00c6d793          	srli	a5,a3,0xc
ffffffffc0201218:	02c7f063          	bgeu	a5,a2,ffffffffc0201238 <pmm_init+0x176>
    pmm_manager->init_memmap(base, n);
ffffffffc020121c:	6010                	ld	a2,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020121e:	fff80737          	lui	a4,0xfff80
ffffffffc0201222:	973e                	add	a4,a4,a5
ffffffffc0201224:	00271793          	slli	a5,a4,0x2
ffffffffc0201228:	97ba                	add	a5,a5,a4
ffffffffc020122a:	6a18                	ld	a4,16(a2)
        init_memmap(pa2page(mem_begin), (mem_end - mem_begin) / PGSIZE);
ffffffffc020122c:	8d95                	sub	a1,a1,a3
ffffffffc020122e:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0201230:	81b1                	srli	a1,a1,0xc
ffffffffc0201232:	953e                	add	a0,a0,a5
ffffffffc0201234:	9702                	jalr	a4
}
ffffffffc0201236:	bfbd                	j	ffffffffc02011b4 <pmm_init+0xf2>
        panic("pa2page called with invalid pa");
ffffffffc0201238:	00001617          	auipc	a2,0x1
ffffffffc020123c:	c0860613          	addi	a2,a2,-1016 # ffffffffc0201e40 <default_pmm_manager+0xf0>
ffffffffc0201240:	06a00593          	li	a1,106
ffffffffc0201244:	00001517          	auipc	a0,0x1
ffffffffc0201248:	c1c50513          	addi	a0,a0,-996 # ffffffffc0201e60 <default_pmm_manager+0x110>
ffffffffc020124c:	f77fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * (npage - nbase));
ffffffffc0201250:	00001617          	auipc	a2,0x1
ffffffffc0201254:	bc860613          	addi	a2,a2,-1080 # ffffffffc0201e18 <default_pmm_manager+0xc8>
ffffffffc0201258:	05e00593          	li	a1,94
ffffffffc020125c:	00001517          	auipc	a0,0x1
ffffffffc0201260:	b6450513          	addi	a0,a0,-1180 # ffffffffc0201dc0 <default_pmm_manager+0x70>
ffffffffc0201264:	f5ffe0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("DTB memory info not available");
ffffffffc0201268:	00001617          	auipc	a2,0x1
ffffffffc020126c:	b3860613          	addi	a2,a2,-1224 # ffffffffc0201da0 <default_pmm_manager+0x50>
ffffffffc0201270:	04600593          	li	a1,70
ffffffffc0201274:	00001517          	auipc	a0,0x1
ffffffffc0201278:	b4c50513          	addi	a0,a0,-1204 # ffffffffc0201dc0 <default_pmm_manager+0x70>
ffffffffc020127c:	f47fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201280:	86ae                	mv	a3,a1
ffffffffc0201282:	00001617          	auipc	a2,0x1
ffffffffc0201286:	b9660613          	addi	a2,a2,-1130 # ffffffffc0201e18 <default_pmm_manager+0xc8>
ffffffffc020128a:	07900593          	li	a1,121
ffffffffc020128e:	00001517          	auipc	a0,0x1
ffffffffc0201292:	b3250513          	addi	a0,a0,-1230 # ffffffffc0201dc0 <default_pmm_manager+0x70>
ffffffffc0201296:	f2dfe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020129a <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020129a:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020129e:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02012a0:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02012a4:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02012a6:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02012aa:	f022                	sd	s0,32(sp)
ffffffffc02012ac:	ec26                	sd	s1,24(sp)
ffffffffc02012ae:	e84a                	sd	s2,16(sp)
ffffffffc02012b0:	f406                	sd	ra,40(sp)
ffffffffc02012b2:	e44e                	sd	s3,8(sp)
ffffffffc02012b4:	84aa                	mv	s1,a0
ffffffffc02012b6:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02012b8:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02012bc:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02012be:	03067e63          	bgeu	a2,a6,ffffffffc02012fa <printnum+0x60>
ffffffffc02012c2:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02012c4:	00805763          	blez	s0,ffffffffc02012d2 <printnum+0x38>
ffffffffc02012c8:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02012ca:	85ca                	mv	a1,s2
ffffffffc02012cc:	854e                	mv	a0,s3
ffffffffc02012ce:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02012d0:	fc65                	bnez	s0,ffffffffc02012c8 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02012d2:	1a02                	slli	s4,s4,0x20
ffffffffc02012d4:	00001797          	auipc	a5,0x1
ffffffffc02012d8:	bfc78793          	addi	a5,a5,-1028 # ffffffffc0201ed0 <default_pmm_manager+0x180>
ffffffffc02012dc:	020a5a13          	srli	s4,s4,0x20
ffffffffc02012e0:	9a3e                	add	s4,s4,a5
}
ffffffffc02012e2:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02012e4:	000a4503          	lbu	a0,0(s4)
}
ffffffffc02012e8:	70a2                	ld	ra,40(sp)
ffffffffc02012ea:	69a2                	ld	s3,8(sp)
ffffffffc02012ec:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02012ee:	85ca                	mv	a1,s2
ffffffffc02012f0:	87a6                	mv	a5,s1
}
ffffffffc02012f2:	6942                	ld	s2,16(sp)
ffffffffc02012f4:	64e2                	ld	s1,24(sp)
ffffffffc02012f6:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02012f8:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc02012fa:	03065633          	divu	a2,a2,a6
ffffffffc02012fe:	8722                	mv	a4,s0
ffffffffc0201300:	f9bff0ef          	jal	ra,ffffffffc020129a <printnum>
ffffffffc0201304:	b7f9                	j	ffffffffc02012d2 <printnum+0x38>

ffffffffc0201306 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201306:	7119                	addi	sp,sp,-128
ffffffffc0201308:	f4a6                	sd	s1,104(sp)
ffffffffc020130a:	f0ca                	sd	s2,96(sp)
ffffffffc020130c:	ecce                	sd	s3,88(sp)
ffffffffc020130e:	e8d2                	sd	s4,80(sp)
ffffffffc0201310:	e4d6                	sd	s5,72(sp)
ffffffffc0201312:	e0da                	sd	s6,64(sp)
ffffffffc0201314:	fc5e                	sd	s7,56(sp)
ffffffffc0201316:	f06a                	sd	s10,32(sp)
ffffffffc0201318:	fc86                	sd	ra,120(sp)
ffffffffc020131a:	f8a2                	sd	s0,112(sp)
ffffffffc020131c:	f862                	sd	s8,48(sp)
ffffffffc020131e:	f466                	sd	s9,40(sp)
ffffffffc0201320:	ec6e                	sd	s11,24(sp)
ffffffffc0201322:	892a                	mv	s2,a0
ffffffffc0201324:	84ae                	mv	s1,a1
ffffffffc0201326:	8d32                	mv	s10,a2
ffffffffc0201328:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020132a:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc020132e:	5b7d                	li	s6,-1
ffffffffc0201330:	00001a97          	auipc	s5,0x1
ffffffffc0201334:	bd4a8a93          	addi	s5,s5,-1068 # ffffffffc0201f04 <default_pmm_manager+0x1b4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201338:	00001b97          	auipc	s7,0x1
ffffffffc020133c:	da8b8b93          	addi	s7,s7,-600 # ffffffffc02020e0 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201340:	000d4503          	lbu	a0,0(s10)
ffffffffc0201344:	001d0413          	addi	s0,s10,1
ffffffffc0201348:	01350a63          	beq	a0,s3,ffffffffc020135c <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc020134c:	c121                	beqz	a0,ffffffffc020138c <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc020134e:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201350:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201352:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201354:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201358:	ff351ae3          	bne	a0,s3,ffffffffc020134c <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020135c:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201360:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201364:	4c81                	li	s9,0
ffffffffc0201366:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201368:	5c7d                	li	s8,-1
ffffffffc020136a:	5dfd                	li	s11,-1
ffffffffc020136c:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201370:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201372:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201376:	0ff5f593          	zext.b	a1,a1
ffffffffc020137a:	00140d13          	addi	s10,s0,1
ffffffffc020137e:	04b56263          	bltu	a0,a1,ffffffffc02013c2 <vprintfmt+0xbc>
ffffffffc0201382:	058a                	slli	a1,a1,0x2
ffffffffc0201384:	95d6                	add	a1,a1,s5
ffffffffc0201386:	4194                	lw	a3,0(a1)
ffffffffc0201388:	96d6                	add	a3,a3,s5
ffffffffc020138a:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc020138c:	70e6                	ld	ra,120(sp)
ffffffffc020138e:	7446                	ld	s0,112(sp)
ffffffffc0201390:	74a6                	ld	s1,104(sp)
ffffffffc0201392:	7906                	ld	s2,96(sp)
ffffffffc0201394:	69e6                	ld	s3,88(sp)
ffffffffc0201396:	6a46                	ld	s4,80(sp)
ffffffffc0201398:	6aa6                	ld	s5,72(sp)
ffffffffc020139a:	6b06                	ld	s6,64(sp)
ffffffffc020139c:	7be2                	ld	s7,56(sp)
ffffffffc020139e:	7c42                	ld	s8,48(sp)
ffffffffc02013a0:	7ca2                	ld	s9,40(sp)
ffffffffc02013a2:	7d02                	ld	s10,32(sp)
ffffffffc02013a4:	6de2                	ld	s11,24(sp)
ffffffffc02013a6:	6109                	addi	sp,sp,128
ffffffffc02013a8:	8082                	ret
            padc = '0';
ffffffffc02013aa:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc02013ac:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013b0:	846a                	mv	s0,s10
ffffffffc02013b2:	00140d13          	addi	s10,s0,1
ffffffffc02013b6:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02013ba:	0ff5f593          	zext.b	a1,a1
ffffffffc02013be:	fcb572e3          	bgeu	a0,a1,ffffffffc0201382 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02013c2:	85a6                	mv	a1,s1
ffffffffc02013c4:	02500513          	li	a0,37
ffffffffc02013c8:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02013ca:	fff44783          	lbu	a5,-1(s0)
ffffffffc02013ce:	8d22                	mv	s10,s0
ffffffffc02013d0:	f73788e3          	beq	a5,s3,ffffffffc0201340 <vprintfmt+0x3a>
ffffffffc02013d4:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02013d8:	1d7d                	addi	s10,s10,-1
ffffffffc02013da:	ff379de3          	bne	a5,s3,ffffffffc02013d4 <vprintfmt+0xce>
ffffffffc02013de:	b78d                	j	ffffffffc0201340 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02013e0:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02013e4:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013e8:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc02013ea:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc02013ee:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02013f2:	02d86463          	bltu	a6,a3,ffffffffc020141a <vprintfmt+0x114>
                ch = *fmt;
ffffffffc02013f6:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc02013fa:	002c169b          	slliw	a3,s8,0x2
ffffffffc02013fe:	0186873b          	addw	a4,a3,s8
ffffffffc0201402:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201406:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201408:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc020140c:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc020140e:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201412:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201416:	fed870e3          	bgeu	a6,a3,ffffffffc02013f6 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc020141a:	f40ddce3          	bgez	s11,ffffffffc0201372 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc020141e:	8de2                	mv	s11,s8
ffffffffc0201420:	5c7d                	li	s8,-1
ffffffffc0201422:	bf81                	j	ffffffffc0201372 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201424:	fffdc693          	not	a3,s11
ffffffffc0201428:	96fd                	srai	a3,a3,0x3f
ffffffffc020142a:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020142e:	00144603          	lbu	a2,1(s0)
ffffffffc0201432:	2d81                	sext.w	s11,s11
ffffffffc0201434:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201436:	bf35                	j	ffffffffc0201372 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201438:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020143c:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201440:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201442:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201444:	bfd9                	j	ffffffffc020141a <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201446:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201448:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020144c:	01174463          	blt	a4,a7,ffffffffc0201454 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201450:	1a088e63          	beqz	a7,ffffffffc020160c <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201454:	000a3603          	ld	a2,0(s4)
ffffffffc0201458:	46c1                	li	a3,16
ffffffffc020145a:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc020145c:	2781                	sext.w	a5,a5
ffffffffc020145e:	876e                	mv	a4,s11
ffffffffc0201460:	85a6                	mv	a1,s1
ffffffffc0201462:	854a                	mv	a0,s2
ffffffffc0201464:	e37ff0ef          	jal	ra,ffffffffc020129a <printnum>
            break;
ffffffffc0201468:	bde1                	j	ffffffffc0201340 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc020146a:	000a2503          	lw	a0,0(s4)
ffffffffc020146e:	85a6                	mv	a1,s1
ffffffffc0201470:	0a21                	addi	s4,s4,8
ffffffffc0201472:	9902                	jalr	s2
            break;
ffffffffc0201474:	b5f1                	j	ffffffffc0201340 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201476:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201478:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020147c:	01174463          	blt	a4,a7,ffffffffc0201484 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201480:	18088163          	beqz	a7,ffffffffc0201602 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201484:	000a3603          	ld	a2,0(s4)
ffffffffc0201488:	46a9                	li	a3,10
ffffffffc020148a:	8a2e                	mv	s4,a1
ffffffffc020148c:	bfc1                	j	ffffffffc020145c <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020148e:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201492:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201494:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201496:	bdf1                	j	ffffffffc0201372 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201498:	85a6                	mv	a1,s1
ffffffffc020149a:	02500513          	li	a0,37
ffffffffc020149e:	9902                	jalr	s2
            break;
ffffffffc02014a0:	b545                	j	ffffffffc0201340 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014a2:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02014a6:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014a8:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02014aa:	b5e1                	j	ffffffffc0201372 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc02014ac:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02014ae:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02014b2:	01174463          	blt	a4,a7,ffffffffc02014ba <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02014b6:	14088163          	beqz	a7,ffffffffc02015f8 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02014ba:	000a3603          	ld	a2,0(s4)
ffffffffc02014be:	46a1                	li	a3,8
ffffffffc02014c0:	8a2e                	mv	s4,a1
ffffffffc02014c2:	bf69                	j	ffffffffc020145c <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02014c4:	03000513          	li	a0,48
ffffffffc02014c8:	85a6                	mv	a1,s1
ffffffffc02014ca:	e03e                	sd	a5,0(sp)
ffffffffc02014cc:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02014ce:	85a6                	mv	a1,s1
ffffffffc02014d0:	07800513          	li	a0,120
ffffffffc02014d4:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02014d6:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02014d8:	6782                	ld	a5,0(sp)
ffffffffc02014da:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02014dc:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02014e0:	bfb5                	j	ffffffffc020145c <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02014e2:	000a3403          	ld	s0,0(s4)
ffffffffc02014e6:	008a0713          	addi	a4,s4,8
ffffffffc02014ea:	e03a                	sd	a4,0(sp)
ffffffffc02014ec:	14040263          	beqz	s0,ffffffffc0201630 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02014f0:	0fb05763          	blez	s11,ffffffffc02015de <vprintfmt+0x2d8>
ffffffffc02014f4:	02d00693          	li	a3,45
ffffffffc02014f8:	0cd79163          	bne	a5,a3,ffffffffc02015ba <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02014fc:	00044783          	lbu	a5,0(s0)
ffffffffc0201500:	0007851b          	sext.w	a0,a5
ffffffffc0201504:	cf85                	beqz	a5,ffffffffc020153c <vprintfmt+0x236>
ffffffffc0201506:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020150a:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020150e:	000c4563          	bltz	s8,ffffffffc0201518 <vprintfmt+0x212>
ffffffffc0201512:	3c7d                	addiw	s8,s8,-1
ffffffffc0201514:	036c0263          	beq	s8,s6,ffffffffc0201538 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201518:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020151a:	0e0c8e63          	beqz	s9,ffffffffc0201616 <vprintfmt+0x310>
ffffffffc020151e:	3781                	addiw	a5,a5,-32
ffffffffc0201520:	0ef47b63          	bgeu	s0,a5,ffffffffc0201616 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201524:	03f00513          	li	a0,63
ffffffffc0201528:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020152a:	000a4783          	lbu	a5,0(s4)
ffffffffc020152e:	3dfd                	addiw	s11,s11,-1
ffffffffc0201530:	0a05                	addi	s4,s4,1
ffffffffc0201532:	0007851b          	sext.w	a0,a5
ffffffffc0201536:	ffe1                	bnez	a5,ffffffffc020150e <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201538:	01b05963          	blez	s11,ffffffffc020154a <vprintfmt+0x244>
ffffffffc020153c:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc020153e:	85a6                	mv	a1,s1
ffffffffc0201540:	02000513          	li	a0,32
ffffffffc0201544:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201546:	fe0d9be3          	bnez	s11,ffffffffc020153c <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020154a:	6a02                	ld	s4,0(sp)
ffffffffc020154c:	bbd5                	j	ffffffffc0201340 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc020154e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201550:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201554:	01174463          	blt	a4,a7,ffffffffc020155c <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201558:	08088d63          	beqz	a7,ffffffffc02015f2 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc020155c:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201560:	0a044d63          	bltz	s0,ffffffffc020161a <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201564:	8622                	mv	a2,s0
ffffffffc0201566:	8a66                	mv	s4,s9
ffffffffc0201568:	46a9                	li	a3,10
ffffffffc020156a:	bdcd                	j	ffffffffc020145c <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc020156c:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201570:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201572:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201574:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201578:	8fb5                	xor	a5,a5,a3
ffffffffc020157a:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020157e:	02d74163          	blt	a4,a3,ffffffffc02015a0 <vprintfmt+0x29a>
ffffffffc0201582:	00369793          	slli	a5,a3,0x3
ffffffffc0201586:	97de                	add	a5,a5,s7
ffffffffc0201588:	639c                	ld	a5,0(a5)
ffffffffc020158a:	cb99                	beqz	a5,ffffffffc02015a0 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020158c:	86be                	mv	a3,a5
ffffffffc020158e:	00001617          	auipc	a2,0x1
ffffffffc0201592:	97260613          	addi	a2,a2,-1678 # ffffffffc0201f00 <default_pmm_manager+0x1b0>
ffffffffc0201596:	85a6                	mv	a1,s1
ffffffffc0201598:	854a                	mv	a0,s2
ffffffffc020159a:	0ce000ef          	jal	ra,ffffffffc0201668 <printfmt>
ffffffffc020159e:	b34d                	j	ffffffffc0201340 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02015a0:	00001617          	auipc	a2,0x1
ffffffffc02015a4:	95060613          	addi	a2,a2,-1712 # ffffffffc0201ef0 <default_pmm_manager+0x1a0>
ffffffffc02015a8:	85a6                	mv	a1,s1
ffffffffc02015aa:	854a                	mv	a0,s2
ffffffffc02015ac:	0bc000ef          	jal	ra,ffffffffc0201668 <printfmt>
ffffffffc02015b0:	bb41                	j	ffffffffc0201340 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02015b2:	00001417          	auipc	s0,0x1
ffffffffc02015b6:	93640413          	addi	s0,s0,-1738 # ffffffffc0201ee8 <default_pmm_manager+0x198>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015ba:	85e2                	mv	a1,s8
ffffffffc02015bc:	8522                	mv	a0,s0
ffffffffc02015be:	e43e                	sd	a5,8(sp)
ffffffffc02015c0:	0fc000ef          	jal	ra,ffffffffc02016bc <strnlen>
ffffffffc02015c4:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02015c8:	01b05b63          	blez	s11,ffffffffc02015de <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02015cc:	67a2                	ld	a5,8(sp)
ffffffffc02015ce:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015d2:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02015d4:	85a6                	mv	a1,s1
ffffffffc02015d6:	8552                	mv	a0,s4
ffffffffc02015d8:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015da:	fe0d9ce3          	bnez	s11,ffffffffc02015d2 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015de:	00044783          	lbu	a5,0(s0)
ffffffffc02015e2:	00140a13          	addi	s4,s0,1
ffffffffc02015e6:	0007851b          	sext.w	a0,a5
ffffffffc02015ea:	d3a5                	beqz	a5,ffffffffc020154a <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015ec:	05e00413          	li	s0,94
ffffffffc02015f0:	bf39                	j	ffffffffc020150e <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02015f2:	000a2403          	lw	s0,0(s4)
ffffffffc02015f6:	b7ad                	j	ffffffffc0201560 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc02015f8:	000a6603          	lwu	a2,0(s4)
ffffffffc02015fc:	46a1                	li	a3,8
ffffffffc02015fe:	8a2e                	mv	s4,a1
ffffffffc0201600:	bdb1                	j	ffffffffc020145c <vprintfmt+0x156>
ffffffffc0201602:	000a6603          	lwu	a2,0(s4)
ffffffffc0201606:	46a9                	li	a3,10
ffffffffc0201608:	8a2e                	mv	s4,a1
ffffffffc020160a:	bd89                	j	ffffffffc020145c <vprintfmt+0x156>
ffffffffc020160c:	000a6603          	lwu	a2,0(s4)
ffffffffc0201610:	46c1                	li	a3,16
ffffffffc0201612:	8a2e                	mv	s4,a1
ffffffffc0201614:	b5a1                	j	ffffffffc020145c <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201616:	9902                	jalr	s2
ffffffffc0201618:	bf09                	j	ffffffffc020152a <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc020161a:	85a6                	mv	a1,s1
ffffffffc020161c:	02d00513          	li	a0,45
ffffffffc0201620:	e03e                	sd	a5,0(sp)
ffffffffc0201622:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201624:	6782                	ld	a5,0(sp)
ffffffffc0201626:	8a66                	mv	s4,s9
ffffffffc0201628:	40800633          	neg	a2,s0
ffffffffc020162c:	46a9                	li	a3,10
ffffffffc020162e:	b53d                	j	ffffffffc020145c <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201630:	03b05163          	blez	s11,ffffffffc0201652 <vprintfmt+0x34c>
ffffffffc0201634:	02d00693          	li	a3,45
ffffffffc0201638:	f6d79de3          	bne	a5,a3,ffffffffc02015b2 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020163c:	00001417          	auipc	s0,0x1
ffffffffc0201640:	8ac40413          	addi	s0,s0,-1876 # ffffffffc0201ee8 <default_pmm_manager+0x198>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201644:	02800793          	li	a5,40
ffffffffc0201648:	02800513          	li	a0,40
ffffffffc020164c:	00140a13          	addi	s4,s0,1
ffffffffc0201650:	bd6d                	j	ffffffffc020150a <vprintfmt+0x204>
ffffffffc0201652:	00001a17          	auipc	s4,0x1
ffffffffc0201656:	897a0a13          	addi	s4,s4,-1897 # ffffffffc0201ee9 <default_pmm_manager+0x199>
ffffffffc020165a:	02800513          	li	a0,40
ffffffffc020165e:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201662:	05e00413          	li	s0,94
ffffffffc0201666:	b565                	j	ffffffffc020150e <vprintfmt+0x208>

ffffffffc0201668 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201668:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc020166a:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020166e:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201670:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201672:	ec06                	sd	ra,24(sp)
ffffffffc0201674:	f83a                	sd	a4,48(sp)
ffffffffc0201676:	fc3e                	sd	a5,56(sp)
ffffffffc0201678:	e0c2                	sd	a6,64(sp)
ffffffffc020167a:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020167c:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020167e:	c89ff0ef          	jal	ra,ffffffffc0201306 <vprintfmt>
}
ffffffffc0201682:	60e2                	ld	ra,24(sp)
ffffffffc0201684:	6161                	addi	sp,sp,80
ffffffffc0201686:	8082                	ret

ffffffffc0201688 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201688:	4781                	li	a5,0
ffffffffc020168a:	00005717          	auipc	a4,0x5
ffffffffc020168e:	98673703          	ld	a4,-1658(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201692:	88ba                	mv	a7,a4
ffffffffc0201694:	852a                	mv	a0,a0
ffffffffc0201696:	85be                	mv	a1,a5
ffffffffc0201698:	863e                	mv	a2,a5
ffffffffc020169a:	00000073          	ecall
ffffffffc020169e:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02016a0:	8082                	ret

ffffffffc02016a2 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02016a2:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02016a6:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02016a8:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02016aa:	cb81                	beqz	a5,ffffffffc02016ba <strlen+0x18>
        cnt ++;
ffffffffc02016ac:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02016ae:	00a707b3          	add	a5,a4,a0
ffffffffc02016b2:	0007c783          	lbu	a5,0(a5)
ffffffffc02016b6:	fbfd                	bnez	a5,ffffffffc02016ac <strlen+0xa>
ffffffffc02016b8:	8082                	ret
    }
    return cnt;
}
ffffffffc02016ba:	8082                	ret

ffffffffc02016bc <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc02016bc:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc02016be:	e589                	bnez	a1,ffffffffc02016c8 <strnlen+0xc>
ffffffffc02016c0:	a811                	j	ffffffffc02016d4 <strnlen+0x18>
        cnt ++;
ffffffffc02016c2:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc02016c4:	00f58863          	beq	a1,a5,ffffffffc02016d4 <strnlen+0x18>
ffffffffc02016c8:	00f50733          	add	a4,a0,a5
ffffffffc02016cc:	00074703          	lbu	a4,0(a4)
ffffffffc02016d0:	fb6d                	bnez	a4,ffffffffc02016c2 <strnlen+0x6>
ffffffffc02016d2:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc02016d4:	852e                	mv	a0,a1
ffffffffc02016d6:	8082                	ret

ffffffffc02016d8 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02016d8:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02016dc:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02016e0:	cb89                	beqz	a5,ffffffffc02016f2 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc02016e2:	0505                	addi	a0,a0,1
ffffffffc02016e4:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02016e6:	fee789e3          	beq	a5,a4,ffffffffc02016d8 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02016ea:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc02016ee:	9d19                	subw	a0,a0,a4
ffffffffc02016f0:	8082                	ret
ffffffffc02016f2:	4501                	li	a0,0
ffffffffc02016f4:	bfed                	j	ffffffffc02016ee <strcmp+0x16>

ffffffffc02016f6 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02016f6:	c20d                	beqz	a2,ffffffffc0201718 <strncmp+0x22>
ffffffffc02016f8:	962e                	add	a2,a2,a1
ffffffffc02016fa:	a031                	j	ffffffffc0201706 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc02016fc:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02016fe:	00e79a63          	bne	a5,a4,ffffffffc0201712 <strncmp+0x1c>
ffffffffc0201702:	00b60b63          	beq	a2,a1,ffffffffc0201718 <strncmp+0x22>
ffffffffc0201706:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc020170a:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020170c:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201710:	f7f5                	bnez	a5,ffffffffc02016fc <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201712:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201716:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201718:	4501                	li	a0,0
ffffffffc020171a:	8082                	ret

ffffffffc020171c <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc020171c:	ca01                	beqz	a2,ffffffffc020172c <memset+0x10>
ffffffffc020171e:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201720:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201722:	0785                	addi	a5,a5,1
ffffffffc0201724:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201728:	fec79de3          	bne	a5,a2,ffffffffc0201722 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020172c:	8082                	ret
