#!/bin/bash


#set -x


echo "===== PCI Devices ====="
lspci -nn | grep -Ei "1394|firewire|texas|ti"

echo
echo "===== Kernel Driver ====="
lspci -k | grep -A4 -Ei "1394|firewire"

echo
echo "===== Loaded Modules ====="
lsmod | grep firewire

echo
echo "===== Device Nodes ====="
ls -l /dev/fw* 2>/dev/null || echo "No FireWire devices"

echo
echo "===== Recent Kernel Messages ====="
sudo dmesg | grep -i firewire | tail -20

echo
echo "===== User ====="
id

echo
echo "===== dvgrab ====="
command -v dvgrab && dvgrab --version
