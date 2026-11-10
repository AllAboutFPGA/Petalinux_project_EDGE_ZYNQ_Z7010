# EDGE ZYNQ Z7-10: PetaLinux 2022.2

PetaLinux 2022.2 project and ready-made microSD card image for the **EDGE ZYNQ SoC FPGA kit** with the
Zynq-7000 **XC7Z010** (EDGE ZYNQ Z7-10), from [Invent Logics / allaboutfpga.com](https://allaboutfpga.com).
Made for the V3 board (RTL8211F Ethernet PHY) and tested on it.

## Download

The SD card image and the boot files are on the [Releases page](https://github.com/AllAboutFPGA/petalinux_project_edge_zynq_z7010/releases):

| File | What it is |
|---|---|
| `edge_zynq_z10_petalinux_2022.2_sd.wic.xz` | Complete microSD card image (boot + root file system) |
| `edge_zynq_z10_petalinux_2022.2_boot_files.zip` | `BOOT.BIN`, `boot.scr`, `image.ub`, `system.bit`, `system.dtb` |

## What works

- Boots from the microSD card: FAT boot partition and a 4 GB ext4 root file system
- Linux 5.15 (linux-xlnx 2022.2), both Cortex-A9 cores, 512 MB DDR3
- Serial console on the USB-UART at 115200 baud
- Gigabit Ethernet with DHCP, **plus a fixed address 192.168.2.99**, and SSH (Dropbear)
- USB 2.0 host on **J3** (fit jumpers **J6** and **J7**): memory sticks, keyboards, USB-serial adapters, UVC webcams
- PS LED **D1** blinks as a heartbeat; the four PL LEDs are `/sys/class/leds/pl_led0` to `pl_led3`
- Slide switches and push buttons through AXI GPIO (use `gpiodetect`, `gpioget`)
- Tools: python3, ethtool, iperf3, i2c-tools, libgpiod tools, v4l-utils, devmem2, nano, parted

## Quick start

1. Write `edge_zynq_z10_petalinux_2022.2_sd.wic.xz` to a microSD card (8 GB or larger) with
   [balenaEtcher](https://etcher.balena.io/), which reads `.xz` files directly.
2. Set the boot jumpers to SD, connect the USB-UART to your PC (115200 baud) and power the board.
3. Log in as **root**, password **root**. Change it with `passwd` if the board is on a shared network.
4. Network:
   - on a router, the board gets an address by DHCP;
   - with a cable straight to the PC, set the PC's Ethernet to `192.168.2.1`, netmask `255.255.255.0`,
     then `ssh root@192.168.2.99`.

Try the board:

```sh
echo 1 > /sys/class/leds/pl_led0/brightness   # PL LED on
gpiodetect                                     # 41210000.gpio = slide switches, 41220000.gpio = push buttons
lsusb                                          # USB devices on J3
ethtool eth0 | grep Speed                      # 1000Mb/s
```

The first boot takes about 30 seconds longer while the SSH host key is created.

## Build it yourself

You need Ubuntu 20.04 (WSL2 on Windows works) with PetaLinux 2022.2 installed.

```sh
git clone https://github.com/AllAboutFPGA/petalinux_project_edge_zynq_z7010.git
cd petalinux_project_edge_zynq_z7010
source ~/petalinux/2022.2/settings.sh
petalinux-build
cd images/linux
petalinux-package --boot --fsbl zynq_fsbl.elf --fpga system.bit --u-boot u-boot.elf --force
cd ../..
petalinux-package --wic --images-dir images/linux --outdir images/linux --bootfiles "BOOT.BIN boot.scr image.ub"
```

The card image is `images/linux/petalinux-sdimage.wic`.

## Hardware design

`project-spec/hw-description/system.xsa` comes from the Vivado 2022.2 script in `hw/`: the processing system with
the EDGE ZYNQ settings (33.333 MHz clock, DDR3, UART0, microSD, Ethernet, USB0, QSPI) and AXI GPIO for the PL LEDs
(0x41200000), slide switches (0x41210000) and push buttons (0x41220000). Pins are in `hw/edge_linux.xdc`.

To rebuild it:

```sh
vivado -mode batch -source hw/edge_linux_hw.tcl -tclargs xc7z010clg400-1 work out
petalinux-config --get-hw-description out --silentconfig
```

## Changes from the PetaLinux defaults

| File | Change |
|---|---|
| `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi` | USB host with the ULPI PHY, microSD without write protect, LEDs |
| `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/edge.cfg` | Realtek PHY, USB host, USB serial, webcams, exFAT, GPIO LEDs |
| `project-spec/meta-user/conf/petalinuxbsp.conf` | Extra tools, root login, at most 4 parallel downloads |
| `project-spec/meta-user/recipes-core/init-ifupdown/` | DHCP plus the fixed 192.168.2.99 |
| `project-spec/configs/config` | ext4 root file system on the microSD card, hostname `edge-zynq` |

## Older version

The previous project is kept on the [`legacy`](https://github.com/AllAboutFPGA/petalinux_project_edge_zynq_z7010/tree/legacy) branch.

