# workprofile_loopback_fix

**English** | [简体中文](README.zh-CN.md)

A **Magisk / KernelSU** module that disables Android 17's cross-profile
(cross-user) loopback restriction.

The module contains a single script, `service.sh`. It runs once at the
late_start service stage after boot and flips the netd eBPF map to `0`.
The system restores the default value on reboot.

## Supported platforms

| Platform | Stage |
|---|---|
| Magisk | `service.sh` (late_start service) |
| KernelSU | `service.sh` (late_start service; also runs in late-load mode) |


## How it works

Android 17 checks loopback traffic in netd's eBPF program. The switch is:

```
/sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map
```

During startup, system_server writes the aconfig flag
`android.permission.flags.use_loopback_interface_permission_enabled`
(`READ_ONLY` in the release config, so `device_config` cannot change it) into
this map. `service.sh` waits for `sys.boot_completed=1` and then sets it to
`0`, disabling the cross-profile check.

Do not use `post-fs-data.sh`: it runs before system_server and would be
overwritten afterwards.

## Installation

Install `workprofile_loopback_fix.zip` directly in the **Magisk / KernelSU
Manager**:

- **Magisk**: Modules → Install from storage → select the zip
- **KernelSU**: Modules → Install → select the zip

Reboot after installation. The module runs `service.sh` on the next boot; it
does not take effect before the reboot.

## Verify

```bash
adb shell su -c 'bpftool map lookup pinned /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map key 0 0 0 0'
# expect "value": false

adb shell su -c 'cat /data/adb/modules/workprofile_loopback_fix/apply.log'
```

## Uninstall

Remove the module in the Magisk / KernelSU Manager. After a reboot the map
returns to `true` automatically.

To restore it immediately without rebooting:

```bash
adb shell su -c 'bpftool map update pinned /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map key 0 0 0 0 value 1'
```

## Does it work on every Android 17 device?

Not unconditionally. All of the following must hold:

1. The map exists:
   ```bash
   su -c 'ls -l /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map'
   ```
2. `bpftool` is available:
   ```bash
   su -c 'command -v bpftool'
   ```
3. Root can write the map (SELinux permits it).
4. The two endpoints are in different Android users (work profile, app clone,
   private space, multi-user).
5. The module actually runs on every boot.

If the map or `bpftool` is missing, `apply.log` records `map not found` /
`bpftool not found`. Android 16 and older do not have this restriction, so the
module is meaningless there.

## Notes

- This disables cross-profile loopback isolation globally, not for a single app.
- Only new connections are affected (the check happens on the TCP SYN).
- The default is restored on reboot; the module writes it again on the next boot.
