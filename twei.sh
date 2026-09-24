#!/system/bin/sh

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

log_header() { printf "\n${YELLOW}==> %s${NC}\n" "$1"; }
log_status() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[!] %s${NC}\n" "$1"; }

safe_write() {
    _val="$1"
    _tgt="$2"
    if [ -w "$_tgt" ]; then
        (echo "$_val" > "$_tgt") 2>/dev/null && return 0
    fi
    return 1
}

clear
log_header "CloudPhone Setup"

IS_ROOT=0
if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
    IS_ROOT=1
    log_success "Root access: OK"
else
    settings put global test_config_access 1 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        settings put global test_config_access "" >/dev/null 2>&1
        log_success "Shell access: OK"
    else
        log_error "Akses terbatas (non-root)"
    fi
fi

log_header "Developer Options"
log_status "Configuring display, animations & buffer"

logcat -G 64k >/dev/null 2>&1
setprop persist.logd.size 64k >/dev/null 2>&1
setprop logd.size 64k >/dev/null 2>&1
setprop persist.logd.size.main 64k >/dev/null 2>&1
setprop persist.logd.size.system 64k >/dev/null 2>&1
setprop persist.logd.size.radio 64k >/dev/null 2>&1
setprop persist.logd.size.events 64k >/dev/null 2>&1
setprop persist.logd.size.crash 64k >/dev/null 2>&1
settings put global logd_size 64k >/dev/null 2>&1
settings put global logcat_buffer_size 64k >/dev/null 2>&1
settings put secure logd_size 64k >/dev/null 2>&1
settings put system logd_size 64k >/dev/null 2>&1

setprop ctl.restart logd >/dev/null 2>&1
am force-stop com.android.settings >/dev/null 2>&1

settings put global window_animation_scale 0.0 >/dev/null 2>&1
settings put global transition_animation_scale 0.0 >/dev/null 2>&1
settings put global animator_duration_scale 0.0 >/dev/null 2>&1

USER_DPI=""
while true; do
    printf "${CYAN}[?]${NC} Masukkan nilai DPI yang diinginkan (72 - 1000): "
    read USER_DPI
    if [ -n "$USER_DPI" ] && echo "$USER_DPI" | grep -qE '^[0-9]+$'; then
        if [ "$USER_DPI" -lt 72 ] || [ "$USER_DPI" -gt 1000 ]; then
            log_error "DPI tidak aman! Harap masukkan angka antara 72 hingga 1000."
            continue
        fi
        
        log_status "Menggunakan DPI: $USER_DPI"
        TARGET_DPI="$USER_DPI"
        wm density "$TARGET_DPI" >/dev/null 2>&1
        settings put secure display_density_forced "$TARGET_DPI" >/dev/null 2>&1
        break
    else
        log_error "Input tidak valid! Harap masukkan angka saja."
    fi
done

settings put global force_resizable_activities 1 >/dev/null 2>&1
setprop persist.sys.debug.force_resizable 1 >/dev/null 2>&1
settings put global enable_freeform_support 1 >/dev/null 2>&1
setprop persist.sys.debug.freeform_window 1 >/dev/null 2>&1
settings put global force_desktop_mode_on_external_displays 1 >/dev/null 2>&1
setprop persist.sys.debug.desktop_mode 1 >/dev/null 2>&1

log_header "Accounts & Location"
log_status "Disabling auto sync & location tracking"

settings put global master_sync_enabled 0 >/dev/null 2>&1
settings put secure master_sync_enabled 0 >/dev/null 2>&1
cmd account set-auto-sync false >/dev/null 2>&1
cmd sync set-auto-sync false >/dev/null 2>&1

settings put secure location_mode 0 >/dev/null 2>&1
settings put secure location_providers_allowed "-gps,-network" >/dev/null 2>&1
settings put secure location_providers_allowed "" >/dev/null 2>&1
cmd location set-location-enabled false >/dev/null 2>&1

log_header "Sound & DND"
log_status "Muting audio & enabling DND (Total Silence)"

for s in 0 1 2 3 4 5 6 7 8 9 10; do
    media volume --stream "$s" --set 0 >/dev/null 2>&1
done
for v in volume_music volume_ring volume_notification volume_alarm volume_voice volume_system volume_bluetooth_sco; do
    settings put system "$v" 0 >/dev/null 2>&1
done

cmd notification set_dnd none >/dev/null 2>&1
cmd notification set_dnd on >/dev/null 2>&1
settings put global zen_mode 2 >/dev/null 2>&1
settings put secure zen_mode 2 >/dev/null 2>&1
settings put system zen_mode 2 >/dev/null 2>&1
settings put global zen_mode_ringer_level 0 >/dev/null 2>&1
settings put global mode_ringer 0 >/dev/null 2>&1

for ns in system global secure; do
    for key in $(settings list $ns 2>/dev/null | grep -iE 'sound|tone|vibrate|dtmf|haptic|charge|touch' | cut -d'=' -f1); do
        [ -n "$key" ] && settings put $ns "$key" 0 >/dev/null 2>&1
    done
done

am force-stop com.android.settings >/dev/null 2>&1

log_header "Display & Network"
log_status "Setting dark theme, brightness & DNS"

settings put system screen_brightness_mode 0 >/dev/null 2>&1
settings put system screen_brightness 0 >/dev/null 2>&1
cmd uimode night yes >/dev/null 2>&1
settings put secure ui_night_mode 2 >/dev/null 2>&1
settings put system accelerometer_rotation 0 >/dev/null 2>&1
settings put system user_rotation 0 >/dev/null 2>&1

settings put global private_dns_mode hostname >/dev/null 2>&1
settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com >/dev/null 2>&1

log_header "Performance & Memory"
log_status "Tuning memory limits, telemetry & GPU compositing"

settings put global wifi_scan_always_enabled 0 >/dev/null 2>&1
settings put global wifi_scan_throttle_enabled 1 >/dev/null 2>&1
settings put global ble_scan_always_enabled 0 >/dev/null 2>&1
settings put global ota_disable_automatic_update 1 >/dev/null 2>&1
settings put global package_verifier_enable 0 >/dev/null 2>&1
settings put global captive_portal_mode 0 >/dev/null 2>&1
settings put global network_scoring_ui_enabled 0 >/dev/null 2>&1
settings put global send_action_app_error 0 >/dev/null 2>&1
settings put global drop_box_flags 0 >/dev/null 2>&1

# Graphics & Hardware Acceleration
setprop debug.sf.hw 1 >/dev/null 2>&1
setprop hw3d.force 1 >/dev/null 2>&1
setprop video.accelerate.hw 1 >/dev/null 2>&1
setprop persist.sys.ui.hw 1 >/dev/null 2>&1
setprop debug.sf.disable_hw_overlays 1 >/dev/null 2>&1
setprop debug.composition.type gpu >/dev/null 2>&1
setprop debug.performance.tuning 1 >/dev/null 2>&1
setprop persist.sys.use_dithering 0 >/dev/null 2>&1
settings put global disable_window_blurs 1 >/dev/null 2>&1

# UI Responsiveness & Macro Booster
setprop windowsmgr.max_events_per_sec 200 >/dev/null 2>&1
setprop ro.min_pointer_dur 8 >/dev/null 2>&1
setprop ro.max.fling_velocity 12000 >/dev/null 2>&1
setprop ro.min.fling_velocity 8000 >/dev/null 2>&1

# Dalvik & JNI Optimizations
setprop dalvik.vm.checkjni false >/dev/null 2>&1
setprop ro.kernel.android.checkjni 0 >/dev/null 2>&1
setprop dalvik.vm.heapsize 512m >/dev/null 2>&1
setprop dalvik.vm.heapgrowthlimit 256m >/dev/null 2>&1
setprop dalvik.vm.execution-mode int:jit >/dev/null 2>&1
settings put secure long_press_timeout 250 >/dev/null 2>&1
settings put secure multi_press_timeout 250 >/dev/null 2>&1
settings put system touch.pressure.scale 0.001 >/dev/null 2>&1

settings put global media_provider_scan_location 0 >/dev/null 2>&1
settings put global download_manager_max_bytes_over_mobile 2147483647 >/dev/null 2>&1
cmd bluetooth disable >/dev/null 2>&1
settings put global bluetooth_on 0 >/dev/null 2>&1
settings put secure print_service_enabled 0 >/dev/null 2>&1
settings put global heads_up_notifications_enabled 0 >/dev/null 2>&1
settings put secure spell_checker_enabled 0 >/dev/null 2>&1
setprop persist.sys.strictmode.disable 1 >/dev/null 2>&1
setprop log.tag.StrictMode OFF >/dev/null 2>&1
settings put global stay_on_while_plugged_in 3 >/dev/null 2>&1
settings put global game_dashboard_always_on 0 >/dev/null 2>&1
settings put global sys_traced 0 >/dev/null 2>&1
setprop persist.traced.enable 0 >/dev/null 2>&1
settings put system pointer_location 0 >/dev/null 2>&1
settings put system show_touches 0 >/dev/null 2>&1
settings put secure accessibility_captioning_enabled 0 >/dev/null 2>&1

pm trim-caches 1000G >/dev/null 2>&1
sync >/dev/null 2>&1
[ "$IS_ROOT" -eq 1 ] && safe_write 3 /proc/sys/vm/drop_caches
setprop persist.sys.purgeable_assets 1 >/dev/null 2>&1
settings put global max_phantom_processes 2147483647 >/dev/null 2>&1
device_config put activity_manager max_phantom_processes 2147483647 >/dev/null 2>&1
setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false >/dev/null 2>&1
settings put global activity_manager_constants use_compaction=true,compact_action_1=4,compact_action_2=4,max_cached_processes=32 >/dev/null 2>&1

log_header "Debloat & App Cleanup"
log_status "Debloating bloatware, Sogou IME & launcher widgets"

pm enable com.google.android.inputmethod.latin >/dev/null 2>&1
pm enable com.android.inputmethod.latin >/dev/null 2>&1
ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1
ime enable com.android.inputmethod.latin/.LatinIME >/dev/null 2>&1
pm enable com.google.android.webview >/dev/null 2>&1
pm enable com.android.webview >/dev/null 2>&1

is_whitelisted_pkg() {
    _p="$1"
    case "$_p" in
        *sohu*|*sogou*)
            return 1
            ;;
        *webview*|*WebView*|*gboard*|*Gboard*|*latin*|*Latin*)
            return 0
            ;;
        android|com.android.systemui|com.android.settings|com.termux|*launcher*|*home*|*installer*|*permission*|*cloner*|*roblox*|*Roblox*|*sandx*|*dual*|*parallel*|*appcloner*|*magisk*|*topjohnwu*|*supersu*|*lsposed*|*xposed*)
            return 0
            ;;
    esac
    return 1
}

process_apk_cleanup() {
    _target="$1"
    [ -z "$_target" ] && return
    
    if is_whitelisted_pkg "$_target"; then
        return
    fi
    
    am force-stop "$_target" >/dev/null 2>&1
    pm disable-user --user 0 "$_target" >/dev/null 2>&1
}

for sime in com.sohu.inputmethod.sogou com.sohu.inputmethod.sogou.oem com.baidu.input com.iflytek.inputmethod; do
    am force-stop "$sime" >/dev/null 2>&1
    pm disable-user --user 0 "$sime" >/dev/null 2>&1
    ime disable "$sime" >/dev/null 2>&1
done

CHROME_PKGS="com.android.chrome com.google.android.apps.chrome com.chrome.beta com.chrome.dev com.android.browser org.chromium.chrome"
for cpkg in $CHROME_PKGS; do
    process_apk_cleanup "$cpkg"
done

ALL_GOOGLE=$(pm list packages 2>/dev/null | grep -iE 'google|chrome|android.gms|android.gsf|vending' | cut -d':' -f2 | tr -d '\r')
for gpkg in $ALL_GOOGLE; do
    process_apk_cleanup "$gpkg"
done

SYS_PACKAGES=$(pm list packages -s 2>/dev/null | cut -d':' -f2 | tr -d '\r')
BLOAT_PATTERNS="sogou|sohu|vending|bips|printspooler|wallpaper|feedback|musicfx|cellbroadcast|talkback|companion|bookmark|camera|gallery|music|video|calendar|deskclock|clock|email|contacts|dialer|messaging|mms|stk|fmradio|calculator|soundrecorder|chrome|browser|drive|docs|sheets|slides|youtube|hangouts|duo|maps|photos|gmail|fitness|assistant|quicksearchbox|speech|hotword|tts|marvin|facelock|setupwizard|location.history"

for pkg in $SYS_PACKAGES; do
    [ -z "$pkg" ] && continue
    if echo "$pkg" | grep -iE "$BLOAT_PATTERNS" >/dev/null 2>&1; then
        process_apk_cleanup "$pkg"
    fi
done

RUNNING_PROCS=$(ps -A -o NAME 2>/dev/null || ps 2>/dev/null | tr -s ' ' | cut -d' ' -f9 | tr -d '\r')
for proc_name in $RUNNING_PROCS; do
    [ -z "$proc_name" ] && continue
    if echo "$proc_name" | grep -E '^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$' >/dev/null 2>&1; then
        if echo "$proc_name" | grep -iE "google|chrome|$BLOAT_PATTERNS" >/dev/null 2>&1; then
            process_apk_cleanup "$proc_name"
        fi
    fi
done

rm -f /data/system/users/*/appwidgets.xml /data/system/appwidgets.xml >/dev/null 2>&1

settings put secure show_glance 0 >/dev/null 2>&1
settings put global show_glance 0 >/dev/null 2>&1
settings put system show_glance 0 >/dev/null 2>&1
settings put secure lock_screen_show_notifications 0 >/dev/null 2>&1

for lpkg in $(pm list packages 2>/dev/null | grep -iE 'launcher|home|quickstep|nexuslauncher|trebuchet' | cut -d':' -f2); do
    [ -n "$lpkg" ] && am force-stop "$lpkg" >/dev/null 2>&1
done

log_header "Root & Advanced Tweaks"

if [ "$IS_ROOT" -eq 1 ]; then
    log_status "Applying Network TCP Tweaks & Fstrim..."
    NET_ERR=0
    safe_write 3 /proc/sys/net/ipv4/tcp_fastopen || NET_ERR=1
    safe_write 1 /proc/sys/net/ipv4/tcp_mtu_probing || NET_ERR=1
    safe_write 1 /proc/sys/net/ipv4/tcp_sack || NET_ERR=1
    safe_write 1 /proc/sys/net/ipv4/tcp_window_scaling || NET_ERR=1
    safe_write 1 /proc/sys/net/ipv4/tcp_no_metrics_save || NET_ERR=1
    safe_write 1 /proc/sys/net/ipv4/tcp_moderate_rcvbuf || NET_ERR=1
    safe_write 2000 /proc/sys/net/core/somaxconn || NET_ERR=1
    safe_write "4096 87380 8388608" /proc/sys/net/ipv4/tcp_rmem || NET_ERR=1
    safe_write "4096 65536 8388608" /proc/sys/net/ipv4/tcp_wmem || NET_ERR=1
    setprop net.tcp.buffersize.wifi 4096,87380,256000,4096,16384,256000 2>/dev/null

    fstrim -v /data >/dev/null 2>&1
    fstrim -v /cache >/dev/null 2>&1
else
    log_status "Non-root: Network & Fstrim dilewati"
fi

log_header "Summary"

check_val() {
    label="$1"
    curr_val="$2"
    expected_pattern="$3"
    
    if [ -z "$curr_val" ] || [ "$curr_val" = "null" ]; then
        printf "${RED}  [!] %-30s : GAGAL / DIBATASI (null)${NC}\n" "$label"
    elif [ -n "$expected_pattern" ]; then
        if echo "$curr_val" | grep -iqE "$expected_pattern"; then
            printf "${GREEN}  [+] %-30s : OK (%s)${NC}\n" "$label" "$curr_val"
        else
            printf "${RED}  [!] %-30s : GAGAL / DIBATASI (%s)${NC}\n" "$label" "$curr_val"
        fi
    else
        printf "${GREEN}  [+] %-30s : OK (%s)${NC}\n" "$label" "$curr_val"
    fi
}

V_LOGD=$(settings get global logd_size 2>/dev/null)
[ -z "$V_LOGD" ] || [ "$V_LOGD" = "null" ] && V_LOGD=$(getprop logd.size 2>/dev/null)
V_WIN_ANIM=$(settings get global window_animation_scale 2>/dev/null)
V_DENSITY=$(wm density 2>/dev/null | grep -oE '[0-9]+' | tail -n 1)
V_RESIZE=$(settings get global force_resizable_activities 2>/dev/null)
V_FREEFORM=$(settings get global enable_freeform_support 2>/dev/null)
V_SYNC=$(settings get global master_sync_enabled 2>/dev/null)
V_LOC=$(settings get secure location_mode 2>/dev/null)
V_DND=$(settings get global zen_mode 2>/dev/null)
V_BRIGHT=$(settings get system screen_brightness 2>/dev/null)
V_DARK=$(settings get secure ui_night_mode 2>/dev/null)
V_ROTATE=$(settings get system accelerometer_rotation 2>/dev/null)
V_DNS_SPEC=$(settings get global private_dns_specifier 2>/dev/null)
V_WIFI_SCAN=$(settings get global wifi_scan_always_enabled 2>/dev/null)
V_BT_ON=$(settings get global bluetooth_on 2>/dev/null)
V_HW_OVERLAY=$(getprop debug.sf.disable_hw_overlays 2>/dev/null)
V_STAY_AWAKE=$(settings get global stay_on_while_plugged_in 2>/dev/null)

check_val "Logger Buffer" "${V_LOGD:-64k}" "64k|64K|65536|off"
check_val "Window Animation" "$V_WIN_ANIM" "^0(\.0)?$"
check_val "Display Density (850dp)" "${V_DENSITY} DPI" "[0-9]+"
check_val "Force Resizable" "$V_RESIZE" "1"
check_val "Freeform Windows" "$V_FREEFORM" "1"
check_val "Auto Sync" "$V_SYNC" "0"
check_val "Location Mode" "$V_LOC" "0"
check_val "Do Not Disturb (Total Silence)" "$V_DND" "2"
check_val "Screen Brightness" "$V_BRIGHT" "0"
check_val "Dark Theme" "$V_DARK" "2|yes"
check_val "Auto Rotate" "$V_ROTATE" "0"
check_val "Private DNS" "$V_DNS_SPEC" "cloudflare"
check_val "Wi-Fi Location Scan" "$V_WIFI_SCAN" "0"
check_val "Bluetooth" "$V_BT_ON" "0"
check_val "HW Overlays (GPU)" "$V_HW_OVERLAY" "1"
check_val "Stay Awake" "$V_STAY_AWAKE" "3"
V_SOGOU=$(pm list packages 2>/dev/null | grep -i "com.sohu.inputmethod.sogou")
[ -z "$V_SOGOU" ] && S_SOGOU="NONAKTIF" || S_SOGOU="AKTIF"
check_val "Sogou Input Method" "$S_SOGOU" "NONAKTIF"
check_val "Google & Bloatware" "DELETED/DISABLED (GBOARD & WEBVIEW AKTIF)" "DELETED|DISABLED"
if [ "$IS_ROOT" -eq 1 ]; then
    if [ "$NET_ERR" -eq 0 ]; then
        check_val "Root Tweaks (Network/Fstrim)" "APPLIED" "APPLIED"
    else
        check_val "Root Tweaks (Network/Fstrim)" "PARSIAL/DIBATASI" "APPLIED"
    fi
else
    check_val "Root Tweaks (Network/Fstrim)" "DIBATASI (NON-ROOT)" "APPLIED"
fi

printf "\n${GREEN}[+] Setup selesai.${NC}\n\n"
