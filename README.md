# Run Linux on Microwatt4Zynq
This repository includes all necessary files (RTL, firmware, bootloader, etc.) to run any applications on a Microwatt resides in PL side of a Zynq processor using PS-side peripherals (e.g. DDR memory, UART, Ethernet, etc.). Right now, this repository is specifically dedicated to Zynq Ultrascale+ Family and [ZCU104 evaluation board](https://www.amd.com/en/products/adaptive-socs-and-fpgas/evaluation-boards/zcu104.html), but can be extended to Zynq-7000 series and other evaluation board with few efforts.

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

Now open your terminal and do the following:
```
cd <Path of folder where you cloned Microwatt4Zynq>
source <Path of folder where you installed Vivado>/settings64.sh # e.g. /opt/tools/Xilinx/2025.1/Vivado/settings64.sh
vivado -mode tcl -source create_project.tcl
```
Now you should wait until you see `Vivado%` (this may take up to 30mins or more based on your PC/laptop specifications). After that write `exit` and close the terminal window. If you open `project` folder within the `Microwatt4Zynq` folder, you should see `design_1_wrapper.xsa` which is what we need for the next step in Vitis.
