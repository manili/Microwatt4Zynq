#ifndef __MICROWATT_SOC_H
#define __MICROWATT_SOC_H

/*
 * Microwatt SoC memory map
 */

#define DRAM_BASE                    0x00000000UL  /* "Main-memory/DRAM Base Address */

/*
 * Zynq UltraScale+ UART subsystem:
 */

// UART Base Address (use UART0; change to 0xFF010000 for UART1)
#define UART_BASE_ADDR               0xFF000000UL

// Register Offsets
#define UART_CONTROL_OFFSET          0x00  // Control register
#define UART_MODE_OFFSET             0x04  // Mode register (for baud rate, etc.)
#define UART_INTRPT_EN_OFFSET        0x08  // Interrupt enable
#define UART_CHANNEL_STS_OFFSET      0x2C  // Channel status register
#define UART_TX_RX_FIFO_OFFSET       0x30  // TX/RX FIFO data

// Control Register Bits
#define UART_TX_ENABLE               (1 << 4)  // TX path enable
#define UART_RX_ENABLE               (1 << 2)  // RX path enable
#define UART_TX_RESET                (1 << 1)  // TX FIFO reset (self-clearing)
#define UART_RX_RESET                (1 << 0)  // RX FIFO reset (self-clearing)

// Channel Status Register Bits
#define UART_TX_FULL                 (1 << 4)  // TFUL: TX FIFO full
#define UART_RX_EMPTY                (1 << 1)  // REMPTY: RX FIFO empty

#endif /* __MICROWATT_SOC_H */
