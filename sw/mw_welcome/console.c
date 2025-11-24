#include <stdint.h>  // For uint32_t, uintptr_t
#include <stdbool.h> // For bool

#include "console.h"
#include "microwatt_soc.h"
#include "io.h"

// Helper macro for register access
#define BASE_ADDR                   UART_BASE_ADDR
#define READ_REG(offset)            readl(BASE_ADDR + offset)
#define WRITE_REG(val, offset)      writeb(val, BASE_ADDR + offset)

/**
 * Check if TX FIFO is full.
 * @return true if full, false otherwise.
 */
bool uart_is_tx_fifo_full(void) {
    uint32_t status = READ_REG(UART_CHANNEL_STS_OFFSET);
    return (status & UART_TX_FULL) != 0;
}

/**
 * Check if RX FIFO is empty.
 * @return true if empty, false otherwise.
 */
bool uart_is_rx_fifo_empty(void) {
    uint32_t status = READ_REG(UART_CHANNEL_STS_OFFSET);
    return (status & UART_RX_EMPTY) != 0;
}

/**
 * Transmit a single byte via UART (non-blocking, assumes space available).
 * Waits if TX FIFO is full.
 */
void uart_transmit_byte(uint8_t data) {
    // Wait until TX FIFO is not full
    while (uart_is_tx_fifo_full()) {
        // Busy wait
    }
    WRITE_REG(data, UART_TX_RX_FIFO_OFFSET);
}

/**
 * Receive a single byte via UART (non-blocking, returns 0 if empty).
 * @return Received byte if available, 0 otherwise.
 */
uint8_t uart_receive_byte(void) {
    if (uart_is_rx_fifo_empty()) {
        return 0;  // No data available
    }
    return (uint8_t)READ_REG(UART_TX_RX_FIFO_OFFSET);
}
