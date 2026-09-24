#!/system/bin/sh

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

log_header() { printf "\n${YELLOW}=== %s ===${NC}\n" "$1"; }
log_info() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
log_ok() { printf "${GREEN}[+]${NC} %s\n" "$1"; }
log_skip() { printf "${RED}[-]${NC} %s (Skipped/Read-Only)\n" "$1"; }

safe_sys_write() {
    local val="$1"
    local path="$2"
    if [ -f "$path" ]; then
        if [ -w "$path" ]; then
            (echo "$val" > "$path") 2>/dev/null
            if [ $? -eq 0 ]; then
                log_ok "Berhasil: $path -> $val"
                return 0
            fi
        fi
    fi
    log_skip "Dilarang: $path"
    return 1
}

safe_setprop() {
    local prop="$1"
    local val="$2"
    setprop "$prop" "$val" >/dev/null 2>&1
    local current=$(getprop "$prop")
    if [ "$current" = "$val" ]; then
        log_ok "Setprop: $prop = $val"
    else
        log_skip "Setprop Gagal / Read-Only: $prop"
    fi
}

clear
log_header "Ultimate CloudPhone Tweaker (FULL PACKAGE)"
log_info "Menerapkan semua tweak level ekstrem..."

IS_ROOT=0
if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
    IS_ROOT=1
    log_ok "Akses Root (su) tersedia."
else
    log_skip "Akses Root (su) tidak tersedia. Tweak kernel dilewati."
fi

log_header "1. VM & RAM Tweaks (Kernel & VFS)"
if [ "$IS_ROOT" -eq 1 ]; then
    safe_sys_write 10 /proc/sys/vm/swappiness
    safe_sys_write 50 /proc/sys/vm/vfs_cache_pressure
    safe_sys_write 10 /proc/sys/vm/dirty_background_ratio
    safe_sys_write 30 /proc/sys/vm/dirty_ratio
    safe_sys_write 20480 /proc/sys/vm/extra_free_kbytes
    safe_sys_write 4096 /proc/sys/vm/min_free_kbytes
    safe_sys_write 0 /proc/sys/vm/page-cluster
    safe_sys_write 1 /proc/sys/vm/oom_kill_allocating_task
else
    log_skip "VM Tweaks (Butuh Root)"
fi

log_header "2. CPU Governor Tweaks"
if [ "$IS_ROOT" -eq 1 ]; then
    for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        if [ -d "$cpu" ]; then
            avail=$(cat "$cpu/scaling_available_governors" 2>/dev/null)
            if echo "$avail" | grep -qw "performance"; then
                safe_sys_write "performance" "$cpu/scaling_governor"
            elif echo "$avail" | grep -qw "schedutil"; then
                safe_sys_write "schedutil" "$cpu/scaling_governor"
            fi
        fi
    done
else
    log_skip "CPU Tweaks (Butuh Root)"
fi

log_header "3. Network / TCP & Socket Tweaks"
if [ "$IS_ROOT" -eq 1 ]; then
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_low_latency
    safe_sys_write 3 /proc/sys/net/ipv4/tcp_fastopen
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_mtu_probing
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_sack
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_window_scaling
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_no_metrics_save
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_moderate_rcvbuf
    safe_sys_write 2000 /proc/sys/net/core/somaxconn
    safe_sys_write "4096 87380 8388608" /proc/sys/net/ipv4/tcp_rmem
    safe_sys_write "4096 65536 8388608" /proc/sys/net/ipv4/tcp_wmem
else
    log_skip "Network Tweaks (Butuh Root)"
fi

log_header "4. I/O Scheduler & Fstrim"
if [ "$IS_ROOT" -eq 1 ]; then
    for block in /sys/block/*/queue; do
        if [ -d "$block" ]; then
            safe_sys_write 0 "$block/add_random"
            safe_sys_write 0 "$block/iostats"
            
            avail_sched=$(cat "$block/scheduler" 2>/dev/null)
            if echo "$avail_sched" | grep -qw "noop"; then
                safe_sys_write "noop" "$block/scheduler"
            elif echo "$avail_sched" | grep -qw "deadline"; then
                safe_sys_write "deadline" "$block/scheduler"
            fi
        fi
    done
    
    log_info "Menjalankan Fstrim untuk mempercepat I/O Storage..."
    fstrim -v /data >/dev/null 2>&1 && log_ok "Fstrim /data Berhasil" || log_skip "Fstrim /data Gagal"
    fstrim -v /cache >/dev/null 2>&1 && log_ok "Fstrim /cache Berhasil" || log_skip "Fstrim /cache Gagal"
    fstrim -v /system >/dev/null 2>&1 && log_ok "Fstrim /system Berhasil" || log_skip "Fstrim /system Gagal"
else
    log_skip "I/O & Fstrim Tweaks (Butuh Root)"
fi

log_header "5. OOM Killer (Low Memory Killer)"
if [ "$IS_ROOT" -eq 1 ]; then
    safe_sys_write "15360,19200,23040,26880,34415,43737" /sys/module/lowmemorykiller/parameters/minfree
    safe_sys_write "0,100,200,300,900,906" /sys/module/lowmemorykiller/parameters/adj
else
    log_skip "LMK Tweaks (Butuh Root)"
fi

log_header "6. Dalvik / ART & JNI Tweaks"
# Mematikan check JNI yang memberatkan CPU
safe_setprop "dalvik.vm.checkjni" "false"
safe_setprop "ro.kernel.android.checkjni" "0"
# Optimasi heap size untuk aplikasi berat (Bisa gagal karena ro.*, biarkan script mencoba)
safe_setprop "dalvik.vm.heapsize" "512m"
safe_setprop "dalvik.vm.heapgrowthlimit" "256m"
safe_setprop "dalvik.vm.execution-mode" "int:jit"

log_header "7. Graphics, HW Overlays & UI Responsiveness (Setprop)"
# Force GPU & Hardware acceleration
safe_setprop "debug.sf.hw" "1"
safe_setprop "hw3d.force" "1"
safe_setprop "video.accelerate.hw" "1"
safe_setprop "persist.sys.ui.hw" "1"
safe_setprop "debug.sf.disable_hw_overlays" "1"
safe_setprop "debug.composition.type" "gpu"
safe_setprop "debug.performance.tuning" "1"
safe_setprop "persist.sys.purgeable_assets" "1"
safe_setprop "persist.sys.use_dithering" "0"

# Mempercepat respon sentuhan dan klik (Macro / Auto Clicker)
safe_setprop "windowsmgr.max_events_per_sec" "200"
safe_setprop "ro.min_pointer_dur" "8"
safe_setprop "ro.max.fling_velocity" "12000"
safe_setprop "ro.min.fling_velocity" "8000"

log_header "Selesai!"
log_info "Semua paket komplit tweak telah diterapkan (yang gagal di-skip otomatis)."
