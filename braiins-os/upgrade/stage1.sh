#!/bin/sh

# Copyright (C) 2019  Braiins Systems s.r.o.
#
# This file is part of Braiins Open-Source Initiative (BOSI).
#
# BOSI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Please, keep in mind that we may also license BOSI or any part thereof
# under a proprietary license. For more information on the terms and conditions
# of such proprietary license or if you have any other questions, please
# contact us at opensource@braiins.com.

if [ "$#" -ne 4 ]; then
	echo "Illegal number of parameters" >&2
	exit 1
fi

set -e

MINER_HWID="$1"
KEEP_NET_CONFIG="$2"
KEEP_HOSTNAME="$3"
DRY_RUN="$4"

UBOOT_ENV_CFG="uboot_env.config"

SPL_IMAGE="boot.bin"
UBOOT_IMAGE="u-boot.img"
UBOOT_ENV_DATA="uboot_env.bin"
BITSTREAM_DATA="system.bit.gz"
KERNEL_IMAGE="fit.itb"
STAGE2_FIRMWARE="stage2.tgz"
STAGE3_FIRMWARE="stage3.tgz"

ERASED_MTDS=""

erase_mtd() {
	local index=$1

	for erased in $ERASED_MTDS; do
		if [ $erased == $index ]; then
			# do not erase MTD twice
			return
		fi
	done

	flash_eraseall /dev/mtd${index} 2>&1
	ERASED_MTDS="$ERASED_MTDS $index"
}

sed_variables() {
	local value
	local args
	local input="$1"
	shift

	for name in "$@"; do
		eval value=\$$name
		args="$args -e 's,\${$name},$value,g'"
	done
	eval sed -i $args "$input"
}

# include firmware specific code
. ./CONTROL

# prepare configuration file
sed_variables "$UBOOT_ENV_CFG" UBOOT_ENV_MTD UBOOT_ENV1_OFF UBOOT_ENV2_OFF

[ x"$DRY_RUN" == x"yes" ] && exit 0

erase_mtd ${SPL_MTD} 2>&1
erase_mtd ${UBOOT_MTD} 2>&1
erase_mtd ${BITSTREAM_MTD} 2>&1

echo "Writing U-Boot images with FPGA bitstream..."
nandwrite -ps ${SPL_OFF} /dev/mtd${SPL_MTD} "$SPL_IMAGE" 2>&1
nandwrite -ps ${UBOOT_OFF} /dev/mtd${UBOOT_MTD} "$UBOOT_IMAGE" 2>&1
nandwrite -ps ${SRC_BITSTREAM_OFF} /dev/mtd${BITSTREAM_MTD} "$BITSTREAM_DATA" 2>&1

erase_mtd ${UBOOT_ENV_MTD} 2>&1

echo "Writing U-Boot environment..."
nandwrite -ps ${UBOOT_ENV1_OFF} /dev/mtd${UBOOT_ENV_MTD} "$UBOOT_ENV_DATA" 2>&1
nandwrite -ps ${UBOOT_ENV2_OFF} /dev/mtd${UBOOT_ENV_MTD} "$UBOOT_ENV_DATA" 2>&1

erase_mtd ${SRC_STAGE2_MTD} 2>&1

echo "Writing kernel image..."
nandwrite -ps ${SRC_KERNEL_OFF} /dev/mtd${SRC_STAGE2_MTD} "$KERNEL_IMAGE" 2>&1

echo "Writing stage2 tarball..."
nandwrite -ps ${SRC_STAGE2_OFF} /dev/mtd${SRC_STAGE2_MTD} "$STAGE2_FIRMWARE" 2>&1

if [ -f "$STAGE3_FIRMWARE" ]; then
	echo "Writing stage3 tarball..."
	erase_mtd ${SRC_STAGE3_MTD} 2>&1
	nandwrite -ps ${SRC_STAGE3_OFF} /dev/mtd${SRC_STAGE3_MTD} "$STAGE3_FIRMWARE" 2>&1
	dst_stage3_off=${DST_STAGE3_OFF}
	dst_stage3_size=$(file_size "$STAGE3_FIRMWARE")
	dst_stage3_mtd=${DST_STAGE3_MTD}
fi

echo "U-Boot configuration..."

fw_setenv -c "$UBOOT_ENV_CFG" --script - <<-EOF
	# bitstream metadata
	bitstream_off ${DST_BITSTREAM_OFF}
	bitstream_size $(file_size "$BITSTREAM_DATA")
	#
	# set kernel metadata
	kernel_off ${DST_KERNEL_OFF}
	kernel_size $(file_size "$KERNEL_IMAGE")
	#
	# set firmware stage2 metadata
	stage2_off ${DST_STAGE2_OFF}
	stage2_size $(file_size "$STAGE2_FIRMWARE")
	stage2_mtd ${DST_STAGE2_MTD}
	#
	# set firmware stage3 metadata
	stage3_off ${dst_stage3_off}
	stage3_size ${dst_stage3_size}
	stage3_mtd ${dst_stage3_mtd}
	#
	ethaddr ${ETHADDR}
	#
	# set miner configuration
	miner_hwid ${MINER_HWID}
	#
	# s9 specific configuration
	miner_freq ${MINER_FREQ}
	miner_voltage ${MINER_VOLTAGE}
	miner_fixed_freq ${MINER_FIXED_FREQ}
EOF

# set network konfiguration
if [ x"$KEEP_NET_CONFIG" == x"yes" ]; then
	fw_setenv -c "$UBOOT_ENV_CFG" --script - <<-EOF
		net_ip ${NET_IP}
		net_mask ${NET_MASK}
		net_gateway ${NET_GATEWAY}
		net_dns_servers ${NET_DNS_SERVERS}
	EOF
fi
if [ x"$KEEP_HOSTNAME" == x"yes" ]; then
	fw_setenv -c "$UBOOT_ENV_CFG" net_hostname ${NET_HOSTNAME}
fi

echo
echo "Content of U-Boot configuration:"
fw_printenv -c "$UBOOT_ENV_CFG"

sync
