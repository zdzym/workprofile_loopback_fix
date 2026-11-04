# workprofile_loopback_fix

[English](README.md) | **简体中文**

解除 Android 17 跨资料（跨用户）loopback 限制的 **Magisk / KernelSU** 模块。

整个模块只有一个脚本 `service.sh`：开机后在 late_start service 阶段执行一次，
把 netd 的 eBPF map 改成 `0`。重启后系统会恢复默认值。

## 支持平台

| 平台 | 阶段 |
|---|---|
| Magisk | `service.sh`（late_start service） |
| KernelSU | `service.sh`（late_start service；late-load 模式也会执行） |


## 原理

Android 17 在 netd 的 eBPF 程序里检查 loopback 流量，开关是：

```
/sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map
```

system_server 启动时会把 aconfig flag
`android.permission.flags.use_loopback_interface_permission_enabled`
（release 配置里是 `READ_ONLY`，`device_config` 改不了）写进这张 map。
`service.sh` 等 `sys.boot_completed=1` 之后把它改成 `0`，即关闭跨资料拦截。

不要用 `post-fs-data.sh`：它在 system_server 之前执行，随后会被覆盖。

## 安装

直接在 **Magisk / KernelSU 管理器**中安装 `workprofile_loopback_fix.zip`

安装完成后重启设备即可。模块会在下次开机时自动执行 `service.sh`，
重启前不会生效。

## 验证

```bash
adb shell su -c 'bpftool map lookup pinned /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map key 0 0 0 0'
# 期望 "value": false

adb shell su -c 'cat /data/adb/modules/workprofile_loopback_fix/apply.log'
```

## 卸载

在 Magisk / KernelSU 管理器中卸载本模块，重启后 map 自动恢复 `true`。

想不重启立刻恢复，可以执行：

```bash
adb shell su -c 'bpftool map update pinned /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map key 0 0 0 0 value 1'
```

## 对所有 Android 17 都有效吗？

不是无条件的，需要满足：

1. 系统里有这张 map：
   ```bash
   su -c 'ls -l /sys/fs/bpf/netd_shared/map_netd_loopback_checks_enabled_map'
   ```
2. 系统里有 `bpftool`：
   ```bash
   su -c 'command -v bpftool'
   ```
3. root 能写这张 map（SELinux 允许）；
4. 两端在不同 Android 用户（工作资料、应用分身、隐私空间、多用户）；
5. 模块每次开机都执行了。

缺少 map 或 `bpftool` 时，`apply.log` 会记录 `map not found` / `bpftool not found`。
Android 16 及以下没有这个限制，模块无意义。

## 注意

- 全局关闭跨资料 loopback 隔离，不是只针对某个 App。
- 只影响新连接（拦截发生在 TCP SYN）。
- 重启后恢复默认，模块下次开机再写一次。
