#!/bin/bash

# Enhanced Linux System Optimization Script
# This script optimizes Linux systems for containerized environments like Kubernetes

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW'\033[1;33m'
NC='\033[0m' # No Color

# Language detection
if [[ "$LANG" == *"zh_CN"* ]]; then
    LANG_MODE="zh"
else
    LANG_MODE="en"
fi

# Function to print messages in both languages
print_msg() {
    local level=$1
    local en_msg=$2
    local zh_msg=$3

    case $level in
        "info")
            if [ "$LANG_MODE" = "zh" ]; then
                echo -e "${GREEN}[INFO] $zh_msg${NC}"
            else
                echo -e "${GREEN}[INFO] $en_msg${NC}"
            fi
            ;;
        "success")
            if [ "$LANG_MODE" = "zh" ]; then
                echo -e "${GREEN}[SUCCESS] $zh_msg${NC}"
            else
                echo -e "${GREEN}[SUCCESS] $en_msg${NC}"
            fi
            ;;
        "error")
            if [ "$LANG_MODE" = "zh" ]; then
                echo -e "${RED}[ERROR] $zh_msg${NC}"
            else
                echo -e "${RED}[ERROR] $en_msg${NC}"
            fi
            ;;
        "warn")
            if [ "$LANG_MODE" = "zh" ]; then
                echo -e "${YELLOW}[WARN] $zh_msg${NC}"
            else
                echo -e "${YELLOW}[WARN] $en_msg${NC}"
            fi
            ;;
    esac
}

print_msg "info" "Starting Linux system optimization..." "开始Linux系统优化..."

# 功能1: 禁用 firewalld 防火墙
# 原因: 容器环境通常使用 CNI 插件管理网络，系统防火墙可能干扰容器网络通信
function disable_firewalld() {
    if systemctl status firewalld | grep Active | grep -q running >/dev/null 2>&1; then
        systemctl stop firewalld >/dev/null 2>&1
        systemctl disable firewalld >/dev/null 2>&1
        print_msg "success" "Firewalld service has been stopped and disabled." "Firewalld服务已停止并禁用。"
    else
        print_msg "info" "Firewalld is not running or not installed." "Firewalld未运行或未安装。"
    fi
}

# 功能2: 禁用 UFW 防火墙
# 原因: 同上，UFW 同样会干扰容器网络的正常运行
function disable_ufw() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            ufw --force disable >/dev/null 2>&1
            print_msg "success" "UFW has been disabled." "UFW已被禁用。"
        else
            print_msg "info" "UFW is already disabled or inactive." "UFW已禁用或未激活。"
        fi
    else
        print_msg "info" "UFW is not installed on this system." "系统未安装UFW。"
    fi
}

# 功能3: 禁用 SELinux
# 原因: SELinux 的安全策略可能阻止容器操作宿主机文件系统或网络，K8s 官方建议关闭或设置为 permissive 模式
function disable_selinux() {
    if command -v getenforce >/dev/null 2>&1; then
        current_status=$(getenforce)
        if [ "$current_status" = "Enforcing" ] || [ "$current_status" = "Permissive" ]; then
            # Temporarily disable SELinux
            setenforce 0 >/dev/null 2>&1
            print_msg "success" "SELinux has been temporarily disabled." "SELinux已临时禁用。"

            # Permanently disable SELinux
            if [ -f /etc/selinux/config ]; then
                sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
                print_msg "success" "SELinux has been permanently disabled. Reboot required for full effect." "SELinux已永久禁用。需要重启系统才能完全生效。"
            fi
        else
            print_msg "info" "SELinux is already disabled." "SELinux已禁用。"
        fi
    else
        print_msg "info" "SELinux is not installed on this system." "系统未安装SELinux。"
    fi
}

# 功能4: 禁用 Swap 交换分区
# 原因: Kubernetes 要求禁用 swap，因为 kubelet 无法准确管理内存资源限制，会导致性能不可预测
function disable_swap() {
    if swapoff -a; then
        sed -i '/swap/s/^/#/' /etc/fstab
        print_msg "success" "Swap has been disabled." "交换分区已禁用。"
    else
        print_msg "info" "No swap found or swap already disabled." "未发现交换分区或交换分区已禁用。"
    fi
}

# 功能5: 检查内核版本
# 原因: 容器化功能需要内核 4.0+ 支持（如 cgroup v2、overlay2 存储驱动等）
function check_kernel_version() {
    print_msg "info" "Checking kernel version..." "检查内核版本..."
    current_kernel=$(uname -r)
    kernel_version=$(echo $current_kernel | awk -F. '{print $1}')

    print_msg "info" "Current kernel version: $current_kernel" "当前内核版本: $current_kernel"

    if [ "$kernel_version" -lt "4" ]; then
        print_msg "warn" "Kernel version must be higher than 4.0. Please upgrade the kernel to 4.0+ as soon as possible." "内核版本必须高于4.0。请尽快升级内核至4.0+版本。"
        print_msg "warn" "Some containerization features may not work properly with kernel < 4.0" "内核版本低于4.0可能导致某些容器化功能无法正常工作"
    else
        print_msg "success" "Kernel version is compatible (>= 4.0)." "内核版本兼容 (>= 4.0)。"
    fi
}

# 功能6: 优化内核参数
# 这是脚本的核心优化部分，涵盖了网络、内存、文件系统等多方面
function optimize_linux() {
    print_msg "info" "Optimizing kernel parameters..." "优化内核参数..."

    cat > /etc/sysctl.conf << EOF
# ==================== 网络桥接设置（容器网络必需） ====================
# 允许 iptables 处理桥接流量（K8s 网络策略依赖此设置）
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
# 启用 IP 转发（Pod 间通信和 Service 访问需要）
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1

# ==================== ARP 邻居表设置 ====================
# 增大 ARP 缓存表大小（大规模 Pod 部署时需要）
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
# ARP 缓存回收间隔和过期时间
net.ipv4.neigh.default.gc_interval=60
net.ipv4.neigh.default.gc_stale_time=120

# ==================== 性能监控 ====================
# 允许所有用户读取性能监控数据（Prometheus node_exporter 需要）
kernel.perf_event_paranoid=-1

# ==================== K8s 节点网络优化 ====================
# 禁用 TCP 慢启动（减少连接建立延迟）
net.ipv4.tcp_slow_start_after_idle=0
# 增大 TCP 接收缓冲区最大值（提升网络吞吐量）
net.core.rmem_max=16777216
# 增加 inotify 最大监视数（容器和 Pod 数量多时需要）
fs.inotify.max_user_watches=524288
# 软锁检测设置（便于调试内核问题）
kernel.softlockup_all_cpu_backtrace=1
kernel.softlockup_panic=0
kernel.watchdog_thresh=30

# ==================== 文件系统限制 ====================
# 系统级别最大文件句柄数
fs.file-max=2097152
# inotify 实例数和队列大小（每个容器可能使用 inotify）
fs.inotify.max_user_instances=8192
fs.inotify.max_queued_events=16384
# 内存映射区域最大数量（Elasticsearch 等应用需要较大值）
vm.max_map_count=262144
# 允许卸载已挂载的文件系统（便于清理）
fs.may_detach_mounts=1

# ==================== 网络性能调优 ====================
# 网卡队列最大长度（高并发网络请求时需要）
net.core.netdev_max_backlog=16384
# TCP 发送缓冲区（最小值/默认值/最大值）
net.ipv4.tcp_wmem=4096 12582912 16777216
# 发送缓冲区最大值
net.core.wmem_max=16777216
# Socket 监听队列最大长度（高并发连接时需要）
net.core.somaxconn=32768
# SYN 队列最大长度（防御 SYN 洪水攻击）
net.ipv4.tcp_max_syn_backlog=8096
# TCP 接收缓冲区
net.ipv4.tcp_rmem=4096 12582912 16777216

# ==================== 禁用 IPv6（可选） ====================
# 如果不需要 IPv6，禁用可以减少网络栈复杂度和安全风险
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# ==================== 内存和调试设置 ====================
# 允许 ptrace（容器调试工具如 delve 需要）
kernel.yama.ptrace_scope=0
# 降低 swap 使用倾向（配合禁用 swap 使用）
vm.swappiness=0
# 核心转储文件名包含 PID（便于调试）
kernel.core_uses_pid=1

# ==================== 安全设置 ====================
# 禁用源路由（防止 IP 欺骗攻击）
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
# 启用辅助 IP 地址升级（便于 IP 故障转移）
net.ipv4.conf.default.promote_secondaries=1
net.ipv4.conf.all.promote_secondaries=1

# ==================== 文件系统保护 ====================
# 防止创建指向关键文件的硬链接和软链接（安全加固）
fs.protected_hardlinks=1
fs.protected_symlinks=1

# ==================== 源路由验证和 ARP 设置 ====================
# 禁用反向路径过滤（容器网络可能需要）
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
# ARP 通告设置（多网卡场景下防止 ARP 冲突）
net.ipv4.conf.default.arp_announce=2
net.ipv4.conf.lo.arp_announce=2
net.ipv4.conf.all.arp_announce=2

# ==================== TCP 连接优化 ====================
# TIME_WAIT 状态的最大连接数（防止连接表溢出）
net.ipv4.tcp_max_tw_buckets=5000
# 启用 SYN Cookie（防御 SYN 洪水攻击）
net.ipv4.tcp_syncookies=1
# 主动关闭方的 FIN-WAIT-2 超时时间
net.ipv4.tcp_fin_timeout=30
# SYN-ACK 重试次数（减少无效连接等待时间）
net.ipv4.tcp_synack_retries=2
# 启用 SysRq（紧急情况下可以执行系统请求）
kernel.sysrq=1
EOF

    # Apply sysctl settings
    sysctl -p >/dev/null 2>&1
    print_msg "success" "Kernel parameters optimized successfully." "内核参数优化成功。"
}

# 功能7: 优化系统资源限制
# 原因: 容器化环境下，单个节点可能运行数百个容器，需要更大的文件描述符和进程数限制
function optimize_limits() {
    print_msg "info" "Optimizing system limits..." "优化系统限制..."

    cat > /etc/security/limits.conf <<EOF

# ==================== 文件描述符和进程限制 ====================
# * 表示对所有用户生效
# nofile: 最大打开文件数（每个容器都需要文件描述符）
# nproc:  最大进程/线程数（容器本质上是进程）
* soft nofile 1024000
* hard nofile 1024000
* soft nproc 1024000
* hard nproc 1024000
EOF

    print_msg "success" "System limits optimized successfully." "系统限制优化成功。"
}

# Main execution
print_msg "info" "========================================" "========================================"
print_msg "info" "Linux System Optimization Script" "Linux系统优化脚本"
print_msg "info" "========================================" "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_msg "error" "This script must be run as root. Please use sudo." "此脚本必须以root权限运行，请使用sudo。"
    exit 1
fi

# Execute optimization functions
disable_firewalld
disable_ufw
disable_selinux
disable_swap
check_kernel_version
optimize_linux
optimize_limits

print_msg "info" "========================================" "========================================"
print_msg "success" "System optimization completed!" "系统优化完成！"
print_msg "info" "========================================" "========================================"
print_msg "warn" "Please reboot the system to ensure all changes take effect." "请重启系统以确保所有更改生效。"
print_msg "warn" "Especially important for SELinux changes to be fully applied." "特别是SELinux更改需要重启才能完全生效。"