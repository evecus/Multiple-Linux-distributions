#!/bin/bash
# EasePi WiFi 初始化 - Alpine/OpenRC variant
# systemd rfkill state dir and update-alternatives are not available on Alpine.

WLAN_IF="wlan0"

# Unblock wlan rfkill (kernel rfkill, distro-agnostic)
rfkill unblock wlan 2>/dev/null
rfkill unblock all 2>/dev/null

# Apply upstream regulatory db directly (replaces Debian update-alternatives)
UPSTREAM_DB="/lib/firmware/regulatory.db-upstream"
UPSTREAM_P7S="/lib/firmware/regulatory.db.p7s-upstream"
if [ -f "$UPSTREAM_DB" ]; then
    cp -f "$UPSTREAM_DB" /lib/firmware/regulatory.db 2>/dev/null
    [ -f "$UPSTREAM_P7S" ] && cp -f "$UPSTREAM_P7S" /lib/firmware/regulatory.db.p7s 2>/dev/null
fi

if [ -d /sys/class/net/$WLAN_IF ]; then
    nmcli radio wifi on 2>/dev/null
    ip link set $WLAN_IF up 2>/dev/null
fi
