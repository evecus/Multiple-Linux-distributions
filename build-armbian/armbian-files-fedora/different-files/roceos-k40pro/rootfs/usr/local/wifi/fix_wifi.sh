#!/bin/bash
# EasePi WiFi 初始化 - Fedora variant
# systemd rfkill state dir exists on Fedora; update-alternatives may be absent, so fall back to direct copy.

WLAN_IF="wlan0"
RFKILL_WLAN=""

for f in /var/lib/systemd/rfkill/*:wlan; do
    if [ -f "$f" ]; then
        RFKILL_WLAN="$f"
        break
    fi
done

if [ -n "$RFKILL_WLAN" ]; then
    echo 0 > "$RFKILL_WLAN" 2>/dev/null
fi

# Distro-agnostic fallback
rfkill unblock wlan 2>/dev/null
rfkill unblock all 2>/dev/null

UPSTREAM_DB="/lib/firmware/regulatory.db-upstream"
UPSTREAM_P7S="/lib/firmware/regulatory.db.p7s-upstream"
if [ -f "$UPSTREAM_DB" ]; then
    if command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --set regulatory.db "$UPSTREAM_DB" >/dev/null 2>&1
        update-alternatives --set regulatory.db.p7s "$UPSTREAM_P7S" >/dev/null 2>&1
    else
        cp -f "$UPSTREAM_DB" /lib/firmware/regulatory.db 2>/dev/null
        [ -f "$UPSTREAM_P7S" ] && cp -f "$UPSTREAM_P7S" /lib/firmware/regulatory.db.p7s 2>/dev/null
    fi
fi

if [ -d /sys/class/net/$WLAN_IF ]; then
    nmcli radio wifi on 2>/dev/null
    ip link set $WLAN_IF up 2>/dev/null
fi
