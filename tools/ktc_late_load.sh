#!/system/bin/sh
set -x
mount -o rprivate none / || exit 10
mount /data/local/tmp/ksud-s25u-kdp /system/bin/logcat || exit 11
/system/bin/logcat late-load --package-name me.weishu.kernelsu
status=$?
echo "$status" > /data/local/tmp/ktc-late-load.status
exit "$status"
