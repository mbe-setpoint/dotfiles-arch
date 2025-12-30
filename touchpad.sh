#!/bin/sh

sudo rmmod i2c_hid_acpi i2c_hid
sudo modprobe i2c_hid_acpi
