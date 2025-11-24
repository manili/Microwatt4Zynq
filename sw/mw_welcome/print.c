#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdbool.h>

#include "console.h"

/* ========================================================================= */
/*                          PROVIDED PRINT FUNCTION                          */
/* ========================================================================= */

/**
 * @brief Prints a string to the serial console character by character.
 *
 * This function is provided and simulates writing to a serial port by interacting
 * with memory-mapped I/O registers. It waits for the transmit buffer to be
 * ready before sending each character.
 *
 * @param str The null-terminated string to be printed.
 */
void my_print(const char *str)
{
	for (int i = 0; str[i] != '\0'; i++) {
		char c = str[i];
		uart_transmit_byte(c);
	}
}


/* ========================================================================= */
/*                       HELPER FUNCTION IMPLEMENTATIONS                     */
/* ========================================================================= */

/**
 * @brief Calculates the length of a string.
 * @param s The null-terminated string.
 * @return The number of characters in the string, excluding the null terminator.
 */
static int my_strlen(const char *s)
{
	int i = 0;
	while (s[i] != '\0') {
		i++;
	}
	return i;
}

/**
 * @brief Reverses a string in place.
 * @param str The null-terminated string to be reversed.
 */
static void str_reverse(char *str)
{
	int i = 0;
	int j = my_strlen(str) - 1;
	char temp;

	while (i < j) {
		temp = str[i];
		str[i] = str[j];
		str[j] = temp;
		i++;
		j--;
	}
}

/**
 * @brief Converts an integer to a null-terminated decimal string.
 * @param n The integer to convert.
 * @param s Buffer to store the resulting string.
 * @param min_len The minimum length of the output string, padded with leading zeros if necessary.
 */
static void my_itoa(int n, char *s, int min_len)
{
	int i = 0;
	int is_negative = 0;

	if (n == 0) {
		s[i++] = '0';
	} else if (n < 0) {
		is_negative = 1;
		n = -n;
	}

	while (n != 0) {
		s[i++] = (n % 10) + '0';
		n = n / 10;
	}

	while (i < min_len) {
		s[i++] = '0';
	}

	if (is_negative) {
		s[i++] = '-';
	}

	s[i] = '\0';
	str_reverse(s);
}

/**
 * @brief Converts a 64-bit unsigned integer to a null-terminated hexadecimal string.
 * @param n The unsigned 64-bit integer to convert.
 * @param s Buffer to store the resulting string.
 * @param min_len The minimum length of the output string, padded with leading zeros if necessary.
 */
static void my_uitoa_hex(uint64_t n, char *s, int min_len)
{
	int i = 0;
	const char *hex_chars = "0123456789abcdef";

	if (n == 0) {
		s[i++] = '0';
	}

	while (n != 0) {
		s[i++] = hex_chars[n % 16];
		n = n / 16;
	}

	while (i < min_len) {
		s[i++] = '0';
	}

	s[i] = '\0';
	str_reverse(s);
}


/* ========================================================================= */
/*                       MAIN `my_printf` IMPLEMENTATION                     */
/* ========================================================================= */

/**
 * @brief Formats a string and prints it to the serial console.
 *
 * This function mimics the behavior of the standard C library's printf.
 * It supports the following format specifiers:
 * - %d: Signed decimal integer.
 * - %x: Unsigned hexadecimal integer (expects uint64_t).
 * - %p: Pointer address (printed as 16-digit zero-padded hex).
 * - %c: Character.
 * - %s: String.
 * - %%: A literal '%' character.
 * It also supports zero-padding for numbers (e.g., %02d, %016x).
 *
 * @param format The format string.
 * @param ... Variable arguments corresponding to the format specifiers.
 * @return The total number of characters printed.
 */
int my_printf(const char *format, ...)
{
	va_list args;
	va_start(args, format);

	char buffer[21]; // Sufficient for 64-bit integer string + null terminator
	int count = 0;   // Total characters printed

	for (int i = 0; format[i] != '\0'; i++) {
		if (format[i] != '%') {
			char str[2] = {format[i], '\0'};
			my_print(str);
			count++;
			continue;
		}

		// Move past the '%'
		i++;

		// Check for zero-padding and width specifiers
		int min_len = 0;
		if (format[i] == '0') {
			i++;
		}
		while (format[i] >= '0' && format[i] <= '9') {
			min_len = min_len * 10 + (format[i] - '0');
			i++;
		}

		// Handle format specifiers
		switch (format[i]) {
			case 'd': {
				int d = va_arg(args, int);
				my_itoa(d, buffer, min_len);
				my_print(buffer);
				count += my_strlen(buffer);
				break;
			}
			case 'x': {
				// Assumes 'x' is for uint64_t as per the example
				uint64_t x = va_arg(args, uint64_t);
				my_uitoa_hex(x, buffer, min_len);
				my_print(buffer);
				count += my_strlen(buffer);
				break;
			}
			case 'p': {
				uint64_t p = (uint64_t)va_arg(args, void *);
				my_print("0x");
				count += 2;
				// Pointers are typically printed with full width
				my_uitoa_hex(p, buffer, 16);
				my_print(buffer);
				count += my_strlen(buffer);
				break;
			}
			case 'c': {
				// char is promoted to int in va_arg
				char c = (char)va_arg(args, int);
				char str[2] = {c, '\0'};
				my_print(str);
				count++;
				break;
			}
			case 's': {
				char *s = va_arg(args, char *);
				if (s == NULL) {
					s = "(null)";
				}
				my_print(s);
				count += my_strlen(s);
				break;
			}
			case '%': {
				my_print("%");
				count++;
				break;
			}
			default: {
				// If specifier is unknown, print it literally
				my_print("%");
				my_print(&format[i]);
				count += 2;
				break;
			}
		}
	}

	va_end(args);
	return count;
}
