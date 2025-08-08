#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/*
 * 解析并打印 PADCTL_G3_SOC_GPIO33_0 寄存器各字段：
 *
 *  Bit12  E_SCHMT    — Schmitt 触发器使能（0=禁用，1=启用，抑制输入抖动）
 *  Bit10  GPIO_SF_SEL— 普通 GPIO / SFIO 选择（0=GPIO，1=SFIO）
 *  Bit8   E_LPDR     — 低功耗驱动使能（0=禁用，1=启用，降低驱动强度）
 *  Bit7   E_LPBK     — 环回测试使能（0=禁用，1=启用，内部环回校验）
 *  Bit6   E_INPUT    — 输入使能（0=禁止输入，1=允许输入采样）
 *  Bit5   E_IO_HV    — 高压 IO 使能（0=标准电压，1=高压驱动）
 *  Bit4   TRISTATE   — 三态/直通控制（0=直接驱动，1=三态浮空）
 *  Bits3-2 PUPD      — 上/下拉电阻选择（0=无，1=下拉，2=上拉，3=保留）
 *  Bits1-0 PM        — 引脚多路复用选择（0=RSVD0，1=EXTPERIPH4，2=DCB，3=RSVD3）
 */

void test1() {

    uint32_t v = 0;
    v |= (0x1F << 20) | (0x1F << 12);
    printf("[%s:%d]v = 0x%08X\n", __func__, __LINE__, v);
}

int main(int argc, char *argv[]) {

    test1();
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <hex_value>\n", argv[0]);
        return 1;
    }

    uint16_t reg = 0;
    if (sscanf(argv[1], "%hx", &reg) != 1) {
        fprintf(stderr, "Invalid hex value: %s\n", argv[1]);
        return 1;
    }

    printf("PADCTL_G3_SOC_GPIO33_0 = 0x%04X\n\n", reg);

    // Schmitt 触发器使能
    printf("E_SCHMT    (bit12): %s\n",
           (reg & (1u << 12)) ? "1=ENABLE (Schmitt 滞回)" : "0=DISABLE (无滞回)");

    // 普通 GPIO / SFIO 选择
    printf("GPIO_SF_SEL(bit10): %s\n",
           (reg & (1u << 10)) ? "1=SFIO (Special Function I/O)" 
                              : "0=GPIO (普通 GPIO)");

    // 低功耗驱动使能
    printf("E_LPDR     (bit8) : %s\n",
           (reg & (1u << 8)) ? "1=ENABLE (低功耗驱动)" 
                             : "0=DISABLE (标准驱动)");

    // 环回测试使能
    printf("E_LPBK     (bit7) : %s\n",
           (reg & (1u << 7)) ? "1=ENABLE (内部环回)" 
                             : "0=DISABLE");

    // 输入使能
    printf("E_INPUT    (bit6) : %s\n",
           (reg & (1u << 6)) ? "1=ENABLE (允许输入采样)" 
                             : "0=DISABLE (禁止输入)");

    // 高压 IO 使能
    printf("E_IO_HV    (bit5) : %s\n",
           (reg & (1u << 5)) ? "1=ENABLE (高压驱动支持)" 
                             : "0=DISABLE (标准电压)");

    // 三态/直通控制
    printf("TRISTATE   (bit4) : %s\n",
           (reg & (1u << 4)) ? "1=TRISTATE (浮空)" 
                             : "0=PASSTHROUGH (强制驱动)");

    // 上/下拉电阻选择
    switch ((reg >> 2) & 0x3) {
        case 0: printf("PUPD       (bits3-2): 0=NONE (无拉)\n");      break;
        case 1: printf("PUPD       (bits3-2): 1=PULL_DOWN (下拉)\n"); break;
        case 2: printf("PUPD       (bits3-2): 2=PULL_UP (上拉)\n");   break;
        case 3: printf("PUPD       (bits3-2): 3=RSVD (保留)\n");       break;
    }

    // 引脚多路复用选择
    switch (reg & 0x3) {
        case 0: printf("PM         (bits1-0): 0=RSVD0\n");              break;
        case 1: printf("PM         (bits1-0): 1=EXTPERIPH4\n");       break;
        case 2: printf("PM         (bits1-0): 2=DCB\n");              break;
        case 3: printf("PM         (bits1-0): 3=RSVD3\n");            break;
    }

    return 0;
}
