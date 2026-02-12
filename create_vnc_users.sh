#!/usr/bin/env bash
set -euo pipefail

USERS_FILE="${USERS_FILE:-./users}"
START_DISPLAY="${START_DISPLAY:-1}"            # 从 :1 开始
GEOMETRY="${GEOMETRY:-1440x900}"             # 分辨率
DEPTH="${DEPTH:-24}"                          # 色深
KILL_EXISTING="${KILL_EXISTING:-0}"           # 1=如果display已存在就先kill再启
CREATE_SYSTEMD="${CREATE_SYSTEMD:-0}"         # 1=写systemd并开机自启（可选）
MAX_DISPLAY_TRIES="${MAX_DISPLAY_TRIES:-500}" # 防止极端情况下无限递增

die() { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }

# 必须 root 执行（涉及 adduser/chpasswd/su/chown）
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "This script must be run as root. Use: sudo bash $0"
fi

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd adduser
need_cmd id
need_cmd su
need_cmd vncserver
need_cmd vncpasswd
need_cmd ss
need_cmd chpasswd
need_cmd install
need_cmd awk
need_cmd wc
need_cmd sort
need_cmd uniq
need_cmd cut
need_cmd grep

[[ -f "$USERS_FILE" ]] || die "users file not found: $USERS_FILE"

# 解析 users 文件：输出 "username<TAB>password"
# 支持：
#   user pass
#   user:pass
# 过滤空行、#注释行。每行至少2列。
parse_users() {
  awk '
    BEGIN{FS="[: \t]+"}
    /^[ \t]*$/ {next}
    /^[ \t]*#/ {next}
    NF>=2 {print $1 "\t" $2}
  ' "$USERS_FILE"
}

# 端口是否已被监听（稳：扫描 LISTEN 套接字；避免 ss 表头/退出码坑）
# ss -ltnH 输出无表头；第4列是 Local Address:Port（IPv4: 0.0.0.0:5901  IPv6: [::]:5901）
port_in_use() {
  local port="$1"
  ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
}

# 找一个空闲 display（检查 5900+N 端口）
pick_free_display() {
  local d="$1"
  local tries=0
  while true; do
    local port=$((5900 + d))
    if port_in_use "$port"; then
      d=$((d + 1))
      tries=$((tries + 1))
      if (( tries >= MAX_DISPLAY_TRIES )); then
        die "Could not find a free VNC port after $MAX_DISPLAY_TRIES tries (starting from :$1)."
      fi
      continue
    fi
    echo "$d"
    return 0
  done
}

# 写 xstartup（A 方案：XDG_RUNTIME_DIR 放到 $HOME/.run，避免 /run/user/UID）
write_xstartup() {
  local user="$1"
  local home
  home="$(eval echo "~$user")"

  su - "$user" -c "mkdir -p \"$home/.vnc\""

  cat > "/tmp/xstartup.$$" <<'SH'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# VNC 场景：使用 HOME 下的 runtime，避免 /run/user/UID 权限问题（dconf/firefox/xfce）
export XDG_RUNTIME_DIR="$HOME/.run"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

xrdb "$HOME/.Xresources"
xsetroot -solid grey

exec dbus-run-session startxfce4
SH

  install -m 755 "/tmp/xstartup.$$" "$home/.vnc/xstartup"
  chown "$user:$user" "$home/.vnc/xstartup"
  rm -f "/tmp/xstartup.$$"
}

set_user_login_password() {
  local user="$1" pass="$2"
  echo "$user:$pass" | chpasswd
}

set_user_vnc_password() {
  # TightVNC 用 ~/.vnc/passwd
  # vncpasswd -f 从stdin生成hash（无需交互）
  local user="$1" pass="$2"
  local home
  home="$(eval echo "~$user")"

  su - "$user" -c "mkdir -p \"$home/.vnc\""
  # VNC 密码有效长度最多8字符（协议限制）；超出会被截断
  su - "$user" -c "printf '%s\n' \"$pass\" | vncpasswd -f > \"$home/.vnc/passwd\""
  su - "$user" -c "chmod 600 \"$home/.vnc/passwd\""
}

kill_display_if_running() {
  local user="$1" display="$2"
  su - "$user" -c "vncserver -kill :$display >/dev/null 2>&1 || true"
}

start_vnc_for_user() {
  local user="$1" display="$2"
  su - "$user" -c "vncserver :$display -geometry \"$GEOMETRY\" -depth \"$DEPTH\""
}

maybe_create_systemd_template() {
  [[ "$CREATE_SYSTEMD" == "1" ]] || return 0

  cat > /etc/systemd/system/vncserver@.service <<'UNIT'
[Unit]
Description=TightVNC Server for user %i
After=network.target

[Service]
Type=forking
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:%d.pid
ExecStartPre=-/usr/bin/vncserver -kill :%d
ExecStart=/usr/bin/vncserver :%d -geometry 1440x900 -depth 24
ExecStop=/usr/bin/vncserver -kill :%d

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload >/dev/null 2>&1 || true
  warn "CREATE_SYSTEMD=1: template written. Note: template does not map 'user -> fixed display' automatically."
}

main() {
  maybe_create_systemd_template

  # ---- 预检查：统计有效用户行数 + 重复用户名检测 ----
  TOTAL_USERS="$(parse_users | wc -l | tr -d ' ')"
  if [[ "$TOTAL_USERS" -le 0 ]]; then
    die "No valid users found in $USERS_FILE (expected: 'user pass' or 'user:pass')"
  fi

  DUPES="$(parse_users | cut -f1 | sort | uniq -d || true)"
  if [[ -n "$DUPES" ]]; then
    echo "[ERROR] Duplicate usernames in $USERS_FILE:"
    echo "$DUPES"
    exit 1
  fi

  info "Reading users from: $USERS_FILE"
  info "Found $TOTAL_USERS user(s) in $USERS_FILE"
  info "Starting display from :$START_DISPLAY  geometry=$GEOMETRY depth=$DEPTH"
  echo

  local display="$START_DISPLAY"
  local idx=0

  printf "%-12s %-10s %-8s %-8s\n" "USERNAME" "DISPLAY" "PORT" "PASSWORD"
  printf "%-12s %-10s %-8s %-8s\n" "--------" "-------" "----" "--------"

  while IFS=$'\t' read -r user pass; do
    [[ -n "$user" && -n "$pass" ]] || continue
    idx=$((idx + 1))

    info "[$idx/$TOTAL_USERS] provisioning user=$user ..."

    # 找空闲 display（避免端口冲突）
    display="$(pick_free_display "$display")"
    local port=$((5900 + display))

    # 创建用户（如果不存在）
    if id "$user" >/dev/null 2>&1; then
      info "user exists: $user"
    else
      info "creating user: $user"
      adduser --gecos "" --disabled-password "$user" >/dev/null
    fi

    # 设置登录密码 + 写VNC启动脚本(A方案) + 设置VNC密码
    set_user_login_password "$user" "$pass"
    write_xstartup "$user"
    set_user_vnc_password "$user" "$pass"

    # 启动 vncserver
    if [[ "$KILL_EXISTING" == "1" ]]; then
      info "killing existing vncserver :$display (if any) for $user"
      kill_display_if_running "$user" "$display"
    fi

    # 保险：如果端口仍被占用（极少见），再挪一个 display
    if port_in_use "$port"; then
      warn "port $port already in use; picking next free display..."
      display=$((display + 1))
      display="$(pick_free_display "$display")"
      port=$((5900 + display))
    fi

    info "starting vncserver for $user on :$display (port $port)"
    start_vnc_for_user "$user" "$display" >/dev/null

    printf "%-12s :%-9s %-8s %-8s\n" "$user" "$display" "$port" "$pass"

    # systemd 开机自启（可选）
    if [[ "$CREATE_SYSTEMD" == "1" ]]; then
      systemctl enable "vncserver@${user}.service" >/dev/null 2>&1 || true
    fi

    display=$((display + 1))
  done < <(parse_users)

  echo
  echo "[DONE] Use RealVNC to connect: <server-ip>:<PORT>  (e.g. 5901, 5902, ...)"
  echo "[NOTE] VNC password max effective length is 8 chars (protocol limit). Longer will be truncated."
  echo "[NOTE] A-scheme enabled: XDG_RUNTIME_DIR is set to \$HOME/.run in ~/.vnc/xstartup"
}

main "$@"

