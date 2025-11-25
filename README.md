# Run Linux on Microwatt4Zynq
This repository includes all necessary files (RTL, firmware, bootloader, etc.) to run any applications on a Microwatt resides in PL side of a Zynq processor using PS-side peripherals (e.g. DDR memory, UART, Ethernet, etc.). Right now, this repository is specifically dedicated to Zynq Ultrascale+ Family and [ZCU104 evaluation board](https://www.amd.com/en/products/adaptive-socs-and-fpgas/evaluation-boards/zcu104.html), but can be extended to Zynq-7000 series and other evaluation boards with just a few efforts.

**NOTE:** The current version only suppors PS-side LPDDR4 memory and PS-side UART0. But (using the current version as a template) adding the PS-side peripherals shouldn't be that hard.

## Prerequisites
First make sure you have downloaded/cloned the following tools/repositories:

### 1. Developing OS
You need a developing machine to develop both HW and SW on it. Here is the specs of the recommanded system for development:
- Ubuntu 22.04.5 LTS
- Linux Kernel v5.15
- 16GiB of Memory
- 256 GiB of Storage

### 2. Vivado & Vitis Toolsets
Currently we are using version `2025.1` of [Vivado and Vitis toolsets](https://www.xilinx.com/member/forms/download/xef.html?filename=FPGAs_AdaptiveSoCs_Unified_SDI_2025.1_0530_0145.tar). But you can download any versions from the [official website](https://www.xilinx.com/support/download.html).

### 3. Cross Compiler Toolchain for PPC64LE
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
git clone ...
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

## Use Buildroot to Create a Userspace
A small change is required to glibc in order to support the VMX/AltiVec-less Microwatt, as float128 support is mandiatory and for this in GCC requires VSX/AltiVec. This change is included in Joel's buildroot fork, along with a defconfig. We had cloned the repository [in this step](#5-clone-buildroot-repository) Open your terminal and run the following commands on it:
```
# Make sure cross compiling toolchain is already in your PATH/environment
# and the CROSS_COMPILE variable is set properly
cd <Path of `buildroot` folder>
make ppc64le_microwatt_defconfig
make
```
