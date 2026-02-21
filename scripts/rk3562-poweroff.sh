#!/bin/bash
# Cut power via RK817 PMIC DEV_OFF bit — bypasses ATF's broken SYSTEM_OFF
# which asserts SLPPIN with pmic-reset-func=0, causing a reset instead of
# power-off. Writing DEV_OFF via I2C tells the PMIC to cut power directly.
#
# RK817 I2C: bus 0, addr 0x20, reg 0xF4 (SYS_CFG3), bit 0 = DEV_OFF
# -f forces access despite kernel rk808-core holding the bus
i2cset -f -y 0 0x20 0xf4 0x01
