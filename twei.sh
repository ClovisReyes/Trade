#!/system/bin/sh

echo "=== CLOUDPHONE DEBUG SCRIPT ==="
echo "OS Version: $(getprop ro.build.version.release)"
echo "API Level: $(getprop ro.build.version.sdk)"

echo -e "\n[1] Testing SQLite3 Path..."
if command -v sqlite3 >/dev/null 2>&1; then 
    echo "SQLite3 found at: $(command -v sqlite3)"
elif [ -x "/data/data/com.termux/files/usr/bin/sqlite3" ]; then 
    echo "SQLite3 found at: /data/data/com.termux/files/usr/bin/sqlite3"
elif [ -x "/system/xbin/sqlite3" ]; then 
    echo "SQLite3 found at: /system/xbin/sqlite3"
else
    echo "SQLite3 TIDAK DITEMUKAN"
fi

echo -e "\n[2] Testing Display Resolution Method..."
RAW_WM=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -n 1)
echo "WM Size result: '$RAW_WM'"
RAW_DUMPSYS=$(dumpsys display 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -n 1)
echo "Dumpsys result: '$RAW_DUMPSYS'"

echo -e "\n[3] Testing Volume Mute Command..."
media volume --stream 3 --set 5 >/dev/null 2>&1
echo "media volume exit code: $?"
cmd audio set-volume --stream 3 5 >/dev/null 2>&1
echo "cmd audio exit code: $?"

echo -e "\n[4] Testing DND (Do Not Disturb) Triggers..."
settings put global zen_mode 0
service call notification 49 s16 "android" i32 3 >/dev/null 2>&1
echo "Transaction Code 49 -> zen_mode: $(settings get global zen_mode)"

settings put global zen_mode 0
service call notification 62 i32 2 i32 0 s16 "termux" >/dev/null 2>&1
echo "Transaction Code 62 -> zen_mode: $(settings get global zen_mode)"

settings put global zen_mode 0
service call notification 63 i32 2 i32 0 s16 "termux" >/dev/null 2>&1
echo "Transaction Code 63 -> zen_mode: $(settings get global zen_mode)"

settings put global zen_mode 0
cmd notification set_dnd on >/dev/null 2>&1
echo "CMD Notification -> zen_mode: $(settings get global zen_mode)"

echo -e "\n[5] Testing Logcat Syntax..."
logcat -G 64k >/dev/null 2>&1
echo "logcat -G 64k exit code: $?"
logcat -G 64K >/dev/null 2>&1
echo "logcat -G 64K exit code: $?"

echo -e "\n=== DEBUG SELESAI ==="
