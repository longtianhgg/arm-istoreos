ARCH:=arm
SUBTARGET:=armv7
BOARDNAME:=RK3288 boards (32 bit)
CPU_TYPE:=cortex-a15
CPU_SUBTYPE:=neon-vfpv4
KERNELNAME:=zImage dtbs

define Target/Description
	Build firmware images for Rockchip RK3288 ARMv7 devices.
endef
