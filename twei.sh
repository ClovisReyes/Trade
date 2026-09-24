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

# Fungsi untuk menulis secara aman. 
# Script tidak akan error walau file read-only, ia hanya akan melakukan "skip".
safe_sys_write() {
    local val="$1"
    local path="$2"
    if [ -f "$path" ]; then
        if [ -w "$path" ]; then
            # Mencoba menulis, jika error karena hypervisor lock akan ditangkap
            (echo "$val" > "$path") 2>/dev/null
            if [ $? -eq 0 ]; then
                log_ok "Berhasil: $path -> $val"
                return 0
            fi
        fi
    fi
    log_skip "Dilarang oleh sistem: $path"
    return 1
}

# Fungsi setprop yang aman
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
log_header "Ultimate CloudPhone Tweaker"
log_info "Mengecek semua limitasi OS dan menerapkan tweak secara dinamis..."

IS_ROOT=0
if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
    IS_ROOT=1
    log_ok "Akses Root (su) tersedia."
else
    log_skip "Akses Root (su) tidak tersedia. Sebagian besar tweak akan dilewati."
fi

log_header "1. VM & RAM Tweaks (Kernel)"
if [ "$IS_ROOT" -eq 1 ]; then
    # Mengurangi I/O untuk storage, meningkatkan penggunaan RAM untuk cache
    safe_sys_write 100 /proc/sys/vm/swappiness
    safe_sys_write 10 /proc/sys/vm/dirty_background_ratio
    safe_sys_write 30 /proc/sys/vm/dirty_ratio
    safe_sys_write 20480 /proc/sys/vm/extra_free_kbytes
    safe_sys_write 4096 /proc/sys/vm/min_free_kbytes
    safe_sys_write 0 /proc/sys/vm/page-cluster
    safe_sys_write 1 /proc/sys/vm/oom_kill_allocating_task
else
    log_skip "VM Tweaks (Membutuhkan Root)"
fi

log_header "2. CPU Governor Tweaks"
if [ "$IS_ROOT" -eq 1 ]; then
    for cpu in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        if [ -d "$cpu" ]; then
            avail=$(cat "$cpu/scaling_available_governors" 2>/dev/null)
            # Mencoba mengaktifkan mode performance atau schedutil
            if echo "$avail" | grep -qw "performance"; then
                safe_sys_write "performance" "$cpu/scaling_governor"
            elif echo "$avail" | grep -qw "schedutil"; then
                safe_sys_write "schedutil" "$cpu/scaling_governor"
            elif echo "$avail" | grep -qw "interactive"; then
                safe_sys_write "interactive" "$cpu/scaling_governor"
            fi
        fi
    done
else
    log_skip "CPU Tweaks (Membutuhkan Root)"
fi

log_header "3. Network / TCP Tweaks"
if [ "$IS_ROOT" -eq 1 ]; then
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_low_latency
    safe_sys_write 3 /proc/sys/net/ipv4/tcp_fastopen
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_mtu_probing
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_sack
    safe_sys_write 1 /proc/sys/net/ipv4/tcp_window_scaling
else
    log_skip "Network Tweaks (Membutuhkan Root)"
fi

log_header "4. I/O Scheduler (Storage Speed)"
if [ "$IS_ROOT" -eq 1 ]; then
    for block in /sys/block/*/queue; do
        if [ -d "$block" ]; then
            safe_sys_write 0 "$block/add_random"
            safe_sys_write 0 "$block/iostats"
            
            avail_sched=$(cat "$block/scheduler" 2>/dev/null)
            # noop biasanya paling cepat untuk storage VM/Cloud
            if echo "$avail_sched" | grep -qw "noop"; then
                safe_sys_write "noop" "$block/scheduler"
            elif echo "$avail_sched" | grep -qw "deadline"; then
                safe_sys_write "deadline" "$block/scheduler"
            fi
        fi
    done
else
    log_skip "I/O Tweaks (Membutuhkan Root)"
fi

log_header "5. OOM Killer (Low Memory Killer)"
if [ "$IS_ROOT" -eq 1 ]; then
    # Menyesuaikan parameter batas LMK agar aplikasi berat tidak gampang force close
    safe_sys_write "15360,19200,23040,26880,34415,43737" /sys/module/lowmemorykiller/parameters/minfree
    safe_sys_write "0,100,200,300,900,906" /sys/module/lowmemorykiller/parameters/adj
else
    log_skip "LMK Tweaks (Membutuhkan Root)"
fi

log_header "6. Properties & HW Overlays (Build.prop Dynamic)"
safe_setprop "debug.sf.disable_hw_overlays" "1"
safe_setprop "debug.composition.type" "gpu"
safe_setprop "debug.performance.tuning" "1"
safe_setprop "persist.sys.purgeable_assets" "1"
safe_setprop "persist.sys.use_dithering" "0"
safe_setprop "windowsmgr.max_events_per_sec" "150"
# ro.* biasanya Read-Only, script otomatis akan skip jika tidak bisa
safe_setprop "ro.ril.disable.power.collapse" "1"

log_header "Selesai!"
log_info "Semua tweak telah dicek dan diterapkan secara aman tanpa error 'Read-Only'."
