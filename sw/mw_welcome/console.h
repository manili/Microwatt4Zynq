#include <stddef.h>

bool uart_is_tx_fifo_full(void);
bool uart_is_rx_fifo_empty(void);
void uart_transmit_byte(uint8_t data);
uint8_t uart_receive_byte(void);
