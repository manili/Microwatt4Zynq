# Run Linux on Microwatt4Zynq
This repository includes all necessary files (RTL, firmware, bootloader, etc.) to run any applications on a Microwatt resides in PL side of a Zynq processor using PS-side peripherals (e.g. DDR memory, UART, Ethernet, etc.). Right now, this repository is specifically dedicated to Zynq Ultrascale+ Family and [ZCU104 evaluation board](https://www.amd.com/en/products/adaptive-socs-and-fpgas/evaluation-boards/zcu104.html), but can be extended to Zynq-7000 series and other evaluation boards with just a few efforts.

**NOTE:** The current version only suppors PS-side LPDDR4 memory and PS-side UART0. But (using the current version as a template) adding the PS-side peripherals shouldn't be that hard.

## Prerequisites
First make sure you have downloaded/cloned the following tools/repositories:

### 1. Developing System and OS
You need a developing machine to develop both HW and SW on it. Here is the specs of the recommanded system for development:
- Ubuntu 22.04.5 LTS
- Linux Kernel v5.15
- 16GiB of Memory
- 256 GiB of Storage

### 2. Vivado & Vitis Toolsets
Currently we are using version `2025.1` of [Vivado and Vitis toolsets](https://www.xilinx.com/member/forms/download/xef.html?filename=FPGAs_AdaptiveSoCs_Unified_SDI_2025.1_0530_0145.tar). But you can download any versions from the [official website](https://www.xilinx.com/support/download.html).

### 3. Cross Compile Toolchain for PPC64LE
There are actually two ways to download the `powerpc64le-power8` toolchain:
- You can download and install it from your distro. For example in Ubuntu you can do the following:
```
sudo apt install gcc-powerpc64le-linux-gnu g++-powerpc64le-linux-gnu
```
- If it isn't available on your distro grab the `powerpc64le-power8` toolchain from [here](https://toolchains.bootlin.com). In this case you may need to set the `CROSS_COMPILE` environment variable to the prefix used for your cross compilers (the default is `powerpc64le-linux-gnu-`), for example:
```
export CROSS_COMPILE=powerpc64le-linux-
```

### 4. Clone Microwatt4Zynq Repository
To create the proper hardware for your board you need to clone this repository:
```
git clone https://github.com/manili/Microwatt4Zynq.git
```

### 5. Clone buildroot Repository
To create the rootfs for Linux you need to clone this repository:
```
git clone -b microwatt https://github.com/shenki/buildroot
```

### 6. Clone Linux Repository
To create the Linux kernel you need to clone this repository:
```
git clone https://github.com/manili/linux_microwatt4zynq.git
```

## Generating Hardware
We consider that you have already downloaded and installed the Vivado & Vitis toolsets.

Open your terminal and do the following:
```
cd <Path of folder where you cloned Microwatt4Zynq>
source <Path of folder where you installed Vivado>/settings64.sh # e.g. /opt/tools/Xilinx/2025.1/Vivado/settings64.sh
vivado -mode tcl -source create_project.tcl
```
Now you should wait until you see `Vivado%` (this may take up to 30mins or more based on your PC/laptop specifications). After that, write `exit` and close the terminal window. Now, if you open `project` folder within the `Microwatt4Zynq`, you should see `design_1_wrapper.xsa` which is what we need for the next step in Vitis.

## Generating Software
In this step we are going to generate and package all required softwares for booting up any types of applications (including a simple `Hello World` or a complex `Linux Kernel`).

Open your terminal and do the following:
```
# Make sure cross compiling toolchain is already in your PATH/environment
# and the CROSS_COMPILE variable is set properly
cd <Path of folder where you cloned Microwatt4Zynq>/sw
make
```
These commands should result in creation of `sw_package.zip` in `sw` folder. We need this file along with `design_1_wrapper.xsa` for the next step, Vitis.

## Vitis
In this step we will use the generated files in the previous steps to create a Vitis `workspace` for our project. So open Vitis and follow the following steps.

### Creating Workspace
File -> Set Workspace ... -> Choose proper folder -> Click Open

### Creating Platform Component
File -> New Component -> Platform -> `Create Platform Component` pops up. Now do the followings (We'll consider minimum changes but you can try yourself):
- Name and Location
  - Click Next
- Flow
  - Click `Hardware Design`
  - Click `Browse`
  - Find `design_1_wrapper.xsa` which we had mentioned in [this section](#generating-hardware)
  - Click `Select`
  - Click Next
- OS and Processor
  - Make sure:
    - `Operating system` is set on `standalone`
    - `Processor` is set on `psu_cortexa53_0`
    - `Architecture` is set on `64-bit`
    - `Generate Boot artifacts` is selected
  - Click Next
- Summary
  - Click Finish

Wait for the platform to be created by Vitis. This may take several minutes. After the process finished, do the followings:

- Make sure `Vitis Explorer` is selected on the left pan.
- Under `VITIS COMPONENTS` window
  - Make sure `platform (if you did not change the name)` is selected.
- Under `FLOW` window
  - Make sure `platform (if you did not change the name)` is selected in front of the Component.
  - Click `Build` button.
- Wait for the compilation process to be finished. This may take several minutes.

### Creating Hello World Application
File -> New Example -> Hello World -> Click `Create Application Component from Template` button -> `Create Application Component` pops up. Now do the followings (We'll consider minimum changes but you can try yourself):
- Name and Location
  - Component name -> bootloader
  - Click Next
- Hardware
  - Select `platform (if you did not change the name)`
  - Click Next
- Domain
  - Make sure `standalone_psu_cortexa53_0` is selected.
  - Click Next
- Summary
  - Click Finish
 
Wait for the application to be created by Vitis. This may take several minutes. After the process finished, do the followings:
 
- Make sure `Vitis Explorer` is selected on the left pan.
- Under `VITIS COMPONENTS` window
  - Make sure `bootloader` is selected and expanded.
  - Expand `Settings`
  - Click `UserConfig.cmake`, this will open correspoding window on the right side
  - Look for `Sources` and find then hover on `helloworld.c`
  - Click `edit` button
  - Rename `helloworld` to `bootloader` and click `OK` button
- Once again, under `VITIS COMPONENTS` window
  - Make sure `bootloader` is selected and expanded.
  - Expand `Sources` -> Expand `src`
  - Right click on `helloworld.c` -> Click `Delete` -> Click `OK`
  - Right click on `src` -> `Copy Path`

Open your terminal and do the following:
```
cd <Path of folder where you cloned Microwatt4Zynq>/sw
unzip sw_package.zip -d <Paste `src` path here>
```

Now we are all set to compile our application:
- Make sure `Vitis Explorer` is selected on the left pan.
- Under `VITIS COMPONENTS` window
  - Make sure `bootloader` is selected
- Under `FLOW` window
  - Make sure `bootloader` is selected in front of the Component.
  - Click `Build` button.
- Wait for the compilation process to be finished. This may take several minutes.

### Running on ZCU104
Now we are going to program our FPGA via JTAG so make sure all switches in `SW6` are `ON` (towards the arrow), then follow these steps:
- Connect USB2UART/JTAG port to your PC/laptop
- Put the `SD Card` into ZCU104 board (it is empty but let's just ignore it, for now)
- Plug power cable to the board
- Turn on the board
- Open your terminal and run `screen` command on it:
```
screen /dev/ttyUSB1 115200
```

**NOTE:** You can terminate `screen` by `Cntrl + A` then press `\`, and finally press `y`.

Now let's switch back to your `Vitis` while the Workspace is opened:
- Make sure `Vitis Explorer` is selected on the left pan.
- Under `VITIS COMPONENTS` window
  - Make sure `bootloader` is selected
- Under `FLOW` window
  - Make sure `bootloader` is selected in front of the Component.
  - Click `Run` button.
- Wait for the process to be finished. This may take several seconds and you can check the progress at the bottom at status bar.

Now get back to your terminal where you had opened a `screen` connection. You should see something like the following:
```
Zynq MP First Stage Boot Loader 
Release 2025.1   Nov  9 2025  -  19:22:42
PMU-FW is not running, certain applications may not be supported.
Downloading bootloader to the DRAM...
Successfully downloaded bootloader to the DRAM at 0x20000000!
Downloading Linux ELF file to the DRAM...
Starting ELF read from SD card...
Initializing SDPS driver...
SDPS driver and card initialized successfully.
Reading 7340032 bytes from sector offset 0 to address 0x30000000
ELF file read from SD card successfully.
Successfully downloaded ELF file to the DRAM at 0x30000000!
Extracting Linux ELF file to the DRAM...
Successfully extracted ELF file to the DRAM!
Configuring Microwatt for booting...
Successfully configured Microwatt!
Booting up Microwatt from bootloader at 0x20000000...
--------------------------------------------------


   .oOOo.     
 ."      ". 
 ;  .mw.  ;   Microwatt, it works.
  . '  ' .    
   \ || /    
    ;..;      
    ;..;      
    `ww'      


Function <my_printf> is located at 0x00001354.
Executing: *(0x01700000) --> 0x480000d0.
Press any key to continue...
```

Congratulations! Now we know `Microwatt` is working perfectly fine in our `ZCU104` (Zynq US+) platform.

## Use Buildroot to Create a RootFS
A small change is required to glibc in order to support the VMX/AltiVec-less Microwatt, as float128 support is mandiatory and for this in GCC requires VSX/AltiVec. This change is included in Joel's buildroot fork, along with a defconfig. We had cloned the repository [in this step](#5-clone-buildroot-repository) Open your terminal and run the following commands on it:
```
# Make sure cross compiling toolchain is already in your PATH/environment
# and the CROSS_COMPILE variable is set properly
cd <Path of `buildroot` folder>
make ppc64le_microwatt_defconfig
make
```
Please consider the output which is `<Path of buildroot folder>/output/images/rootfs.cpio`, we need it for the next step.

## Building the Linux Kernel
In this step you can build the Linux kernel using downloaded repository in [this step](#6-clone-linux-repository) and RootFS generated in the previous step and in `<Path of buildroot folder>/output/images/rootfs.cpio`.

Now open a terminal window:
```
# Make sure cross compiling toolchain is already in your PATH/environment
# and the CROSS_COMPILE variable is set properly
cd <Path of `linux_microwatt4zynq` folder>

make ARCH=powerpc microwatt4zynq_defconfig

make ARCH=powerpc CROSS_COMPILE=powerpc64le-linux-gnu- \
  CONFIG_INITRAMFS_SOURCE=<Path of `buildroot` folder>/buildroot/output/images/rootfs.cpio -j`nproc`
```
Please consider the output which is `<Path of linux_microwatt4zynq folder>/arch/powerpc/boot/dtbImage.microwatt4zynq.elf`, we need it for the next step.

## Burn the ELF Version of Kernel to the SD Card
In this last step we are going to write the OS to the SD Card. Follow these steps:
- Connect the SD Card to the PC/laptop
- Open terminal and find the name of your SD Card using `lsblk` command.
  Usually it is `sdb` but you must make sure based on the storage size and other features.
- Now write the following command to copy the OS into the SD Card:
  **CAUTION:** Make sure the SD Card's name is correct, otherwise you may overwrite one of your storages.
```
sudo dd if=<Path of `linux_microwatt4zynq` folder>/arch/powerpc/boot/dtbImage.microwatt4zynq.elf \
  of=/dev/sdb bs=512 seek=0; sync
```
- Eject the SD Card from your PC/laptop and connect it to the ZCU104 evaluation board.

## Test Our Microwatt4Zynq along with the Linux
- Connect USB2UART/JTAG port to your PC/laptop
- Open your terminal and run `screen` command on it:
```
screen /dev/ttyUSB1 115200
```
- Open your `Vitis` while the Workspace is opened
- Make sure `Vitis Explorer` is selected on the left pan
- Under `VITIS COMPONENTS` window
  - Make sure `bootloader` is selected
- Under `FLOW` window
  - Make sure `bootloader` is selected in front of the Component.
  - Click `Run` button.
- Wait for the process to be finished. This may take several seconds and you can check the progress at the bottom at status bar.
- After the above message has shown, press any key to continue the booting procedure.

And here is what you should expect as the final result:
```
Zynq MP First Stage Boot Loader 
Release 2025.1   Nov 25 2025  -  10:35:00
PMU-FW is not running, certain applications may not be supported.
Downloading bootloader to the DRAM...
Successfully downloaded bootloader to the DRAM at 0x20000000!
Downloading Linux ELF file to the DRAM...
Starting ELF read from SD card...
Initializing SDPS driver...
SDPS driver and card initialized successfully.
Reading 7340032 bytes from sector offset 0 to address 0x30000000
ELF file read from SD card successfully.
Successfully downloaded ELF file to the DRAM at 0x30000000!
Extracting Linux ELF file to the DRAM...
Successfully extracted ELF file to the DRAM!
Configuring Microwatt for booting...
Successfully configured Microwatt!
Booting up Microwatt from bootloader at 0x20000000...
--------------------------------------------------

   .oOOo.     
 ."      ". 
 ;  .mw.  ;   Microwatt, it works.
  . '  ' .    
   \ || /    
    ;..;      
    ;..;      
    `ww'      

Function <my_printf> is located at 0x00001354.
Executing: *(0x01700000) --> 0x480000d0.
Press any key to continue...

zImage starting: loaded at 0x0000000001700000 (sp: 0x0000000001c1beb0)
Allocating 0x16eb580 bytes for kernel...
Decompressing (0x0000000000000000 <- 0x0000000001714000:0x0000000001c19477)...
Done! Decompressed 0x16eb580 bytes

Linux/PowerPC load: 
Finalizing device tree... flat tree at 0x1c1cc80

[    0.000000] dt-cpu-ftrs: setup for ISA 3100
[    0.000000] dt-cpu-ftrs: final cpu/mmu features = 0x00040083800bb181 0x20005040
[    0.000000] radix-mmu: Page sizes from device-tree:
[    0.000000] radix-mmu: Page size shift = 12 AP=0x0
[    0.000000] radix-mmu: Page size shift = 16 AP=0x5
[    0.000000] radix-mmu: Page size shift = 21 AP=0x1
[    0.000000] radix-mmu: Page size shift = 30 AP=0x2
[    0.000000] radix-mmu: Mapped 0x0000000000000000-0x0000000001800000 with 2.00 MiB pages (exec)
[    0.000000] radix-mmu: Mapped 0x0000000001800000-0x0000000010000000 with 2.00 MiB pages
[    0.000000] radix-mmu: Initializing Radix MMU
[    0.000000] Linux version 6.18.0-rc7-g30f09200cc4a-dirty (manili@manili) (powerpc64le-linux-gcc.br_real (Buildroot 2021.11-18033-g83947c7bb6) 14.3.0, GNU ld (GNU Binutils) 2.43.1) #1 Tue Nov 25 21:05:11 EST 2025
[    0.000000] OF: reserved mem: 0x0000000020010000..0x0000000020010fff (4 KiB) nomap non-reusable kernel-crash-log@20010000
[    0.000000] Hardware name: microwatt4zynq Microwatt 0x630000 microwatt4zynq
[    0.000000] printk: legacy bootconsole [udbg0] enabled
[    0.000000] -----------------------------------------------------
[    0.000000] phys_mem_size     = 0x10000000
[    0.000000] dcache_bsize      = 0x40
[    0.000000] icache_bsize      = 0x40
[    0.000000] cpu_features      = 0x00040083800bb181
[    0.000000]   possible        = 0x003ffbebcb5fb185
[    0.000000]   always          = 0x0000000380008181
[    0.000000] cpu_user_features = 0xcc002102 0x8c940000
[    0.000000] mmu_features      = 0x20005040
[    0.000000] firmware_features = 0x0000000000000000
[    0.000000] vmalloc start     = 0xc008000000000000
[    0.000000] IO start          = 0xc00a000000000000
[    0.000000] vmemmap start     = 0xc00c000000000000
[    0.000000] -----------------------------------------------------
[    0.000000] barrier-nospec: using ORI speculation barrier
[    0.000000] Zone ranges:
[    0.000000]   Normal   [mem 0x0000000000000000-0x000000000fffffff]
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000000000000-0x000000000fffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000000000000-0x000000000fffffff]
[    0.000000] Kernel command line: console=ttyPS0,115200
[    0.000000] printk: log buffer data + meta data: 65536 + 229376 = 294912 bytes
[    0.000000] Dentry cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    0.000000] Inode-cache hash table entries: 16384 (order: 5, 131072 bytes, linear)
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 65536
[    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.000000] SLUB: HWalign=128, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 16
[    0.000000] ICS native initialized for sources 16..31
[    0.000000] ICS native backend registered
[    0.000578] time_init: 64 bit decrementer (max: 7fffffffffffffff)
[    0.002488] clocksource: timebase: mask: 0xffffffffffffffff max_cycles: 0x171024e7e0, max_idle_ns: 440795205315 ns
[    0.012828] clocksource: timebase mult[a000000] shift[24] registered
[    0.025931] pid_max: default: 32768 minimum: 301
[    0.038920] Mount-cache hash table entries: 512 (order: 0, 4096 bytes, linear)
[    0.043569] Mountpoint-cache hash table entries: 512 (order: 0, 4096 bytes, linear)
[    0.222691] Memory: 212736K/262144K available (4484K kernel code, 460K rwdata, 11900K rodata, 6288K init, 317K bss, 48660K reserved, 0K cma-reserved)
[    0.263645] devtmpfs: initialized
[    0.480698] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
[    0.488980] posixtimers hash table entries: 512 (order: 0, 4096 bytes, linear)
[    0.494521] futex hash table entries: 256 (8192 bytes on 1 NUMA nodes, total 8 KiB, linear).
[    0.589870] NET: Registered PF_NETLINK/PF_ROUTE protocol family
[    0.804149] ff000000.serial: ttyPS0 at MMIO 0xff000000 (irq = 16, base_baud = 6250000) is a xuartps
[    0.815625] printk: legacy console [ttyPS0] enabled
[    0.815625] printk: legacy console [ttyPS0] enabled
[    0.822488] printk: legacy bootconsole [udbg0] disabled
[    0.822488] printk: legacy bootconsole [udbg0] disabled
[    0.998694] pps_core: LinuxPPS API ver. 1 registered
[    1.006194] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
[    1.019732] PTP clock support registered
[    1.121526] clocksource: Switched to clocksource timebase
[    1.314682] NET: Registered PF_INET protocol family
[    1.336848] IP idents hash table entries: 4096 (order: 3, 32768 bytes, linear)
[    1.400379] tcp_listen_portaddr_hash hash table entries: 512 (order: 0, 4096 bytes, linear)
[    1.413433] Table-perturb hash table entries: 65536 (order: 6, 262144 bytes, linear)
[    1.426958] TCP established hash table entries: 2048 (order: 2, 16384 bytes, linear)
[    1.438440] TCP bind hash table entries: 2048 (order: 3, 32768 bytes, linear)
[    1.449458] TCP: Hash tables configured (established 2048 bind 2048)
[    1.465533] UDP hash table entries: 256 (order: 2, 16384 bytes, linear)
[    1.476006] UDP-Lite hash table entries: 256 (order: 2, 16384 bytes, linear)
[    1.497887] NET: Registered PF_UNIX/PF_LOCAL protocol family
[    1.670130] workingset: timestamp_bits=62 max_order=16 bucket_order=0
[    1.786066] io scheduler mq-deadline registered
[    1.804668] io scheduler bfq registered
[    4.658221] brd: module loaded
[    6.085532] loop: module loaded
[    6.218140] NET: Registered PF_INET6 protocol family
[    6.403574] Segment Routing with IPv6
[    6.449726] In-situ OAM (IOAM) with IPv6
[    6.467789] sit: IPv6, IPv4 and MPLS over IPv4 tunneling driver
[    6.634699] NET: Registered PF_PACKET protocol family
[   10.390356] clk: Disabling unused clocks
[   13.152336] Freeing unused kernel image (initmem) memory: 6288K
[   13.208061] Run /init as init process
Starting syslogd: OK
Starting klogd: OK
Running sysctl: OK
Saving random seed: [   30.034691] random: crng init done
OK
Starting network: Waiting for interface eth0 to appear............... timeout!
run-parts: /etc/network/if-pre-up.d/wait_iface: exit status 1
FAIL
Starting dropbear sshd: OK

Welcome to Buildroot
microwatt login: root
# 
```

## Acknowledgements
- [Anton Blanchard](https://github.com/antonblanchard/microwatt)
- [Joel Stanley](https://shenki.github.io/boot-linux-on-microwatt)
- [Oliver O'Halloran](https://www.linkedin.com/in/oliver-o-halloran-0806ba110)
