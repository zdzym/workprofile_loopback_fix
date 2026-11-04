#!/system/bin/sh
# Installer hook (KernelSU-Next embedded installer / Magisk util_functions).

SKIPUNZIP=0

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0755
