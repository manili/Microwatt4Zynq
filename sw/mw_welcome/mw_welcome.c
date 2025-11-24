#include <stdint.h>
#include <stdbool.h>

#include "print.h"
#include "console.h"

#define	 KERNEL_ADDR	0x01700000UL

static char mw_logo[] =
"\n\r"
"   .oOOo.     \n\r"
" .\"      \". \n\r"
" ;  .mw.  ;   Microwatt, it works.\n\r"
"  . '  ' .    \n\r"
"   \\ || /    \n\r"
"    ;..;      \n\r"
"    ;..;      \n\r"
"    `ww'      \n\r"
"\n\r\n\r";

int main(void)
{
	my_printf("%s", mw_logo);
	my_printf("Function <my_printf> is located at 0x%08x.\n\r", &my_printf);
	volatile uint32_t *prog = (volatile uint32_t *)KERNEL_ADDR;
	my_printf("Executing: *(0x%08x) --> 0x%08x.\n\r", (uint32_t *)prog, *prog);
	my_printf("Press any key to continue...");

	// Receive loop example (pseudo-code, assuming incoming data)
	while (true) {
		uint8_t rx_data = uart_receive_byte();
		if (rx_data != 0) {
			// Process received data
			my_printf("\n\r\n\r");
			break;
		}
	}
	
	__asm__ volatile(
	    "lis    %%r12, %0@ha     \n\t"
	    "mtctr  %%r12            \n\t"
	    "bctrl                   \n\t"
	    :
	    : "i"(KERNEL_ADDR)
	    : "r12", "ctr"
	);
}
