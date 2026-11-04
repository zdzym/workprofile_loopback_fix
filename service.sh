#!/system/bin/sh
# Android 17 cross-profile loopback fix.
#
# Runs at late_start service on Magisk and KernelSU (including KernelSU
# late-load mode). Waits for boot completion, then flips the netd eBPF map
# once. A reboot restores the platform default, so no cleanup is needed.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/workprofile_loopback_fix

MAP=/sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map
LOG=$MODDIR/apply.log

BPFTOOL=/system/bin/bpftool
[ -x "$BPFTOOL" ] || BPFTOOL=$(command -v bpftool 2>/dev/null)

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null
}

# system_server writes the map's default value during startup, so wait for
# boot completion before overwriting it (max 180s).
i=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$i" -lt 180 ]; do
    sleep 1
    i=$((i + 1))
done

[ -n "$BPFTOOL" ] || { log_msg "bpftool not found"; exit 1; }
[ -e "$MAP" ] || { log_msg "map not found: $MAP"; exit 1; }

"$BPFTOOL" map update pinned "$MAP" key 0 0 0 0 value 0 >/dev/null 2>>"$LOG"

state=$("$BPFTOOL" map lookup pinned "$MAP" key 0 0 0 0 2>/dev/null \
    | tr -d ' \n' \
    | sed -n 's/.*"value":\([a-zA-Z0-9]*\).*/\1/p')

if [ "$state" = "false" ]; then
    log_msg "applied (late_load=${KSU_LATE_LOAD:-0})"
else
    log_msg "failed (state=$state)"
fi
