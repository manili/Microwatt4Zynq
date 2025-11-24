#include <stdint.h>
#include <stdio.h>
#include <xil_types.h>
#include <xstatus.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h" // Contains hardware base addresses
#include "xil_io.h"      // For Xil_Out32 and Xil_In32
#include "xil_cache.h"   // For cache management
#include "xsdps.h"		 // SD device driver

#define CTR_REG			 	 	0xA0000000
#define MEM_REG			 	 	0xA0000004
#define RES_REG			 	 	0xA0000008
#define VER_REG					0xA000000C

#define CUR_VER					0xDEADBEEF

#define OS_SIZE_BYTES			0x00700000UL	// 0x0052EC00UL
#define SECTOR_OFFSET			0x00000000UL
#define PS_DRAM_BASE_OFFSET		0x20000000UL
#define ELF_OS_BASE_OFFSET		0x30000000UL

// The SDPS driver's ADMA descriptor table can handle a maximum of 2MB
// per transfer (32 descriptors * 65536 bytes/descriptor).
#define MAX_BYTES_PER_TRANSFER (32U * 65536U)

// --- Part 1: ELF Header Definitions for a 64-bit system ---
// These structures must match the ELF64 specification.

#define EI_NIDENT 16

// ELF Header (Ehdr)
typedef struct {
    unsigned char e_ident[EI_NIDENT]; // Magic number and other info
    uint16_t      e_type;             // Object file type
    uint16_t      e_machine;          // Architecture
    uint32_t      e_version;          // Object file version
    uint64_t      e_entry;            // Entry point virtual address
    uint64_t      e_phoff;            // Program header table file offset
    uint64_t      e_shoff;            // Section header table file offset
    uint32_t      e_flags;            // Processor-specific flags
    uint16_t      e_ehsize;           // ELF header size in bytes
    uint16_t      e_phentsize;        // Program header table entry size
    uint16_t      e_phnum;            // Program header table entry count
    uint16_t      e_shentsize;        // Section header table entry size
    uint16_t      e_shnum;            // Section header table entry count
    uint16_t      e_shstrndx;         // Section header string table index
} Elf64_Ehdr;

// Program Header (Phdr)
typedef struct {
    uint32_t p_type;   // Segment type
    uint32_t p_flags;  // Segment flags
    uint64_t p_offset; // Segment file offset
    uint64_t p_vaddr;  // Segment virtual address
    uint64_t p_paddr;  // Segment physical address
    uint64_t p_filesz; // Segment size in file
    uint64_t p_memsz;  // Segment size in memory
    uint64_t p_align;  // Segment alignment
} Elf64_Phdr;

// ELF segment types
#define PT_NULL    0
#define PT_LOAD    1 // Identifies a loadable segment

// ELF magic number
#define ELFMAG0 0x7f
#define ELFMAG1 'E'
#define ELFMAG2 'L'
#define ELFMAG3 'F'

// --- Part 2: Baremetal Memory Utilities ---
// We can't use the standard library, so we provide our own.

void *my_memcpy(void *dest, const void *src, size_t n) {
    char *d = dest;
    const char *s = src;
    for (size_t i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}

void *my_memset(void *s, int c, size_t n) {
    unsigned char *p = s;
    for (size_t i = 0; i < n; i++) {
        p[i] = (unsigned char)c;
    }
    return s;
}

// --- Part 3: The ELF Loader and Execution Logic ---

/**
 * @brief Parses an ELF file located in memory, loads its segments, and jumps to its entry point.
 * 
 * @param elf_file_in_memory The starting address of the raw ELF file copied into DRAM.
 */
int load_and_run_elf(uintptr_t extract_to_offset, uintptr_t elf_file_in_memory) {
    // 1. Point to the ELF header at the start of the file.
    Elf64_Ehdr *ehdr = (Elf64_Ehdr *)elf_file_in_memory;

    // 2. Sanity Check: Verify the ELF magic number.
    if (ehdr->e_ident[0] != ELFMAG0 || ehdr->e_ident[1] != ELFMAG1 ||
        ehdr->e_ident[2] != ELFMAG2 || ehdr->e_ident[3] != ELFMAG3) {
        // Not a valid ELF file.
        return XST_FAILURE;
    }
    
    // 3. Find the Program Header Table.
    // The main header tells us where the table is (e_phoff) and how many entries it has (e_phnum).
    Elf64_Phdr *phdr_table = (Elf64_Phdr *)(elf_file_in_memory + ehdr->e_phoff);

    // 4. Iterate through each Program Header.
    for (int i = 0; i < ehdr->e_phnum; i++) {
        Elf64_Phdr *phdr = &phdr_table[i];

        // We only care about "LOAD"able segments. These are the ones that
        // need to be loaded into memory (like .text, .data, .rodata).
        if (phdr->p_type == PT_LOAD) {
            // Calculate source and destination addresses.
            uintptr_t source_address = elf_file_in_memory + phdr->p_offset;
            uintptr_t dest_address = extract_to_offset + phdr->p_vaddr; // The target VMA!

            // Copy the segment from the file buffer to its final memory location.
            // p_filesz is the size of the data in the file.
            my_memcpy((void *)dest_address, (void *)source_address, phdr->p_filesz);

            // The .bss section is handled here. If the memory size is larger
            // than the file size, the difference is the .bss section, which
            // must be cleared to zero.
            if (phdr->p_memsz > phdr->p_filesz) {
                uintptr_t bss_start = dest_address + phdr->p_filesz;
                size_t bss_size = phdr->p_memsz - phdr->p_filesz;
                my_memset((void *)bss_start, 0, bss_size);
            }
        }
    }

    // // 5. Get the application's entry point from the main header.
    // uint64_t entry_point_addr = extract_to_offset + ehdr->e_entry;

    // // 6. Create a function pointer to the entry point and jump to it.
    // // This transfers control from the bootloader to the newly loaded application.
    // void (*application_entry)(void) = (void (*)(void))entry_point_addr;
    // application_entry();

	return XST_SUCCESS;
}

/**
 * @brief	Reads a large file (like an ELF) from an SD card to DRAM.
 *
 * @param	mem_dst_adr:      The destination address in DRAM.
 * @param	elf_size_in_byte: The total size of the file to read in bytes.
 * @param	sd_sector_offset: The starting sector on the SD card to begin reading.
 *
 * @return	XST_SUCCESS if successful, otherwise XST_FAILURE.
 *
 * @note	This function handles files larger than the driver's single-call
 *          transfer limit by reading the file in chunks. It also performs
 *          SD card initialization on its first run.
 */
static int read_elf_from_sd(uintptr_t mem_dst_adr, uint32_t elf_size_in_byte,
	uint32_t sd_sector_offset)
{
	static XSdPs SdInstance;
	static int SdIsInitialized = 0; // Initialize the driver only once
	XSdPs_Config *SdConfig;
	int Status;
	const u32 SectorSize = 512; // Standard SD sector/block size
	u32 BytesRemaining;
	u32 CurrentSectorOffset;
	uintptr_t CurrentMemAddr;
	u32 MaxBlocksPerTransfer = MAX_BYTES_PER_TRANSFER / SectorSize;

	xil_printf("Starting ELF read from SD card...\r\n");

	// --- 1. Initialize SD Driver and Card (if not already done) ---
	if (!SdIsInitialized) {
		xil_printf("Initializing SDPS driver...\r\n");

		// Look up the device configuration
#ifndef SDT
		// Using Device ID from xparameters.h for baremetal flow
		SdConfig = XSdPs_LookupConfig(XPAR_XSDPS_0_DEVICE_ID);
#else
		// Using base address for system device-tree flow
		SdConfig = XSdPs_LookupConfig(XPAR_XSDPS_0_BASEADDR);
#endif
		if (NULL == SdConfig) {
			xil_printf("ERROR: SDPS LookupConfig failed.\r\n");
			return XST_FAILURE;
		}

		// Initialize the SDPS driver instance
		Status = XSdPs_CfgInitialize(&SdInstance, SdConfig, SdConfig->BaseAddress);
		if (Status != XST_SUCCESS) {
			xil_printf("ERROR: SDPS CfgInitialize failed. Status: %d\r\n", Status);
			return XST_FAILURE;
		}

		// Perform card initialization sequence
		Status = XSdPs_CardInitialize(&SdInstance);
		if (Status != XST_SUCCESS) {
			xil_printf("ERROR: SDPS CardInitialize failed. Status: %d\r\n", Status);
			return XST_FAILURE;
		}
		SdIsInitialized = 1;
		xil_printf("SDPS driver and card initialized successfully.\r\n");
	}

	// --- 2. Set up loop variables for chunked reading ---
	BytesRemaining = elf_size_in_byte;
	CurrentMemAddr = mem_dst_adr;
	CurrentSectorOffset = sd_sector_offset;

	xil_printf("Reading %u bytes from sector offset %u to address 0x%X\r\n",
		   (unsigned int)elf_size_in_byte, (unsigned int)sd_sector_offset, (unsigned int)mem_dst_adr);

	// --- 3. Read loop for handling files larger than 2MB ---
	while (BytesRemaining > 0) {
		u32 BlocksToRead;
		u32 BytesToReadInChunk;
		u32 ReadArg;

		// Determine the size of the current chunk to read
		if (BytesRemaining > MAX_BYTES_PER_TRANSFER) {
			BytesToReadInChunk = MAX_BYTES_PER_TRANSFER;
			BlocksToRead = MaxBlocksPerTransfer;
		} else {
			BytesToReadInChunk = BytesRemaining;
			// Ceiling division to ensure the last partial block is fully read
			BlocksToRead = (BytesRemaining + SectorSize - 1) / SectorSize;
		}

		// The argument for XSdPs_ReadPolled is a sector address for High Capacity
		// cards and a byte address for legacy Standard Capacity cards.
		// The driver sets the 'HCS' flag correctly during initialization.
		ReadArg = CurrentSectorOffset;
		if (!(SdInstance.HCS)) {
			ReadArg *= SectorSize;
		}

		// Perform the read operation for the current chunk
		Status = XSdPs_ReadPolled(&SdInstance, ReadArg, BlocksToRead,
					  (u8 *)CurrentMemAddr);
		if (Status != XST_SUCCESS) {
			xil_printf("ERROR: SDPS ReadPolled failed at sector %u. Status: %d\r\n",
				   (unsigned int)CurrentSectorOffset, Status);
			return XST_FAILURE;
		}

		// Update counters for the next iteration
		BytesRemaining -= BytesToReadInChunk;
		CurrentMemAddr += (BlocksToRead * SectorSize); // Advance pointer by bytes read
		CurrentSectorOffset += BlocksToRead;           // Advance sector offset
	}

	xil_printf("ELF file read from SD card successfully.\r\n");
	return XST_SUCCESS;
}

static int prog_mem_directly(uintptr_t mem_dst_adr, void *prog,
	uint32_t prog_size_in_byte) {

	my_memcpy((void *)mem_dst_adr, prog, prog_size_in_byte);

	return XST_SUCCESS;
}

int main() {
    Xil_DCacheDisable();

	int status = 0;
	uint64_t program[] = { 
		#include "mw_welcome_c_ver.hex" 
	};
	uint32_t program_size = sizeof(program);
//-----------------------------------------------------------------------------
	xil_printf("Downloading bootloader to the DRAM...\n\r");
	status = prog_mem_directly(PS_DRAM_BASE_OFFSET, program, program_size);
	if (status != XST_SUCCESS) {
		xil_printf("Failed to program memory with the bootloader.\n\r");
		return XST_FAILURE;
	}
	xil_printf("Successfully downloaded bootloader to the DRAM at 0x%08X!\n\r", PS_DRAM_BASE_OFFSET);
//-----------------------------------------------------------------------------
	xil_printf("Downloading Linux ELF file to the DRAM...\n\r");
	status = read_elf_from_sd(ELF_OS_BASE_OFFSET, OS_SIZE_BYTES, SECTOR_OFFSET);
	if (status != XST_SUCCESS) {
		xil_printf("SD Raw Read failed.\n\r");
		return XST_FAILURE;
	}
	xil_printf("Successfully downloaded ELF file to the DRAM at 0x%08X!\n\r", ELF_OS_BASE_OFFSET);
//-----------------------------------------------------------------------------
	xil_printf("Extracting Linux ELF file to the DRAM...\n\r");
	status = load_and_run_elf(PS_DRAM_BASE_OFFSET, ELF_OS_BASE_OFFSET);
	if (status != XST_SUCCESS) {
		xil_printf("Extracting ELF file failed.\n\r");
		return XST_FAILURE;
	}
	xil_printf("Successfully extracted ELF file to the DRAM!\n\r");
//-----------------------------------------------------------------------------
	xil_printf("Configuring Microwatt for booting...\n\r");
	Xil_Out32(MEM_REG, PS_DRAM_BASE_OFFSET);
	if (Xil_In32(MEM_REG) != PS_DRAM_BASE_OFFSET ||
		Xil_In32(VER_REG) != CUR_VER) {
		xil_printf("Failed to configure Microwatt properly!\n\r");
		return XST_FAILURE;
	}
	xil_printf("Successfully configured Microwatt!\n\r");
//-----------------------------------------------------------------------------
	xil_printf("Booting up Microwatt from bootloader at 0x%p...\n\r", PS_DRAM_BASE_OFFSET);
    xil_printf("--------------------------------------------------\n\r\n\r");
    Xil_Out32(CTR_REG, 0x1);
//-----------------------------------------------------------------------------
    while (1) { __asm__("wfi"); }

    return 0;
}
