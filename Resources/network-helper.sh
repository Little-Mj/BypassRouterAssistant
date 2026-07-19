#!/bin/zsh
set -euo pipefail

mode="$1"
service="$2"
interface="$3"
expected_connection_id="$4"
ip="$5"
subnet="$6"
gateway="$7"
dns="$8"
log_file="$9"
networksetup="/usr/sbin/networksetup"

valid_ipv4() {
  local address="$1"
  local -a parts
  parts=("${(@s:.:)address}")
  (( ${#parts[@]} == 4 )) || return 1
  local part
  for part in "${parts[@]}"; do
    [[ "$part" == <-> ]] || return 1
    (( part >= 0 && part <= 255 )) || return 1
  done
}

mkdir -p "${log_file:h}"
connection_summary="$(/usr/sbin/ipconfig getsummary "$interface" 2>&1 || true)"
current_connection_id="$(print -r -- "$connection_summary" | awk -F' : ' '/ConnectionID/{print $2; exit}')"
if [[ -z "$current_connection_id" ]]; then
  print "[$(date '+%Y-%m-%d %H:%M:%S')] 已阻止操作：无法确认网卡 $interface 的连接编号" >> "$log_file"
  print -u2 "无法确认当前 Wi-Fi 连接，未修改网络设置。"
  exit 3
fi
if [[ "$current_connection_id" != "$expected_connection_id" ]]; then
  print "[$(date '+%Y-%m-%d %H:%M:%S')] 已阻止操作：Wi-Fi 连接编号已由 $expected_connection_id 变为 $current_connection_id" >> "$log_file"
  print -u2 "Wi-Fi 已发生变化，未修改网络设置。请在当前网络下重试。"
  exit 3
fi

previous_info="$($networksetup -getinfo "$service")"
previous_dns="$($networksetup -getdnsservers "$service")"
previous_mode="dhcp"
[[ "$previous_info" == *"Manual Configuration"* ]] && previous_mode="manual"
previous_ip="$(print -r -- "$previous_info" | awk -F': ' '/^IP address:/{print $2; exit}')"
previous_subnet="$(print -r -- "$previous_info" | awk -F': ' '/^Subnet mask:/{print $2; exit}')"
previous_gateway="$(print -r -- "$previous_info" | awk -F': ' '/^Router:/{print $2; exit}')"

rollback() {
  local code="$1"
  trap - ZERR
  set +e
  print "[$(date '+%Y-%m-%d %H:%M:%S')] 操作失败（代码 $code），开始恢复原配置" >> "$log_file"
  if [[ "$previous_mode" == "manual" && -n "$previous_ip" && -n "$previous_subnet" && -n "$previous_gateway" ]]; then
    "$networksetup" -setmanual "$service" "$previous_ip" "$previous_subnet" "$previous_gateway" >> "$log_file" 2>&1
  else
    "$networksetup" -setdhcp "$service" >> "$log_file" 2>&1
  fi
  if [[ "$previous_dns" == *"aren't any DNS"* ]]; then
    "$networksetup" -setdnsservers "$service" Empty >> "$log_file" 2>&1
  else
    local -a dns_servers
    dns_servers=("${(@f)previous_dns}")
    "$networksetup" -setdnsservers "$service" "${dns_servers[@]}" >> "$log_file" 2>&1
  fi
  print -u2 "网络设置失败，已尝试恢复切换前配置。详情见操作日志。"
  exit "$code"
}
trap 'rollback $?' ZERR

{
  print "[$(date '+%Y-%m-%d %H:%M:%S')] 管理员操作：服务=$service，网卡=$interface，连接编号=$current_connection_id，模式=$mode"
  print "切换前："
  print -r -- "$previous_info"
  print -r -- "$previous_dns"
} >> "$log_file"

if [[ "$mode" == "旁路由" ]]; then
  valid_ipv4 "$ip" || { print -u2 "静态 IP 格式错误"; exit 2; }
  valid_ipv4 "$subnet" || { print -u2 "子网掩码格式错误"; exit 2; }
  valid_ipv4 "$gateway" || { print -u2 "网关格式错误"; exit 2; }
  valid_ipv4 "$dns" || { print -u2 "DNS 格式错误"; exit 2; }
  "$networksetup" -setmanual "$service" "$ip" "$subnet" "$gateway"
  "$networksetup" -setdnsservers "$service" "$dns"
  current_info="$($networksetup -getinfo "$service")"
  current_dns="$($networksetup -getdnsservers "$service")"
  [[ "$current_info" == *"Manual Configuration"* && "$current_info" == *"IP address: $ip"* && "$current_info" == *"Router: $gateway"* && "$current_dns" == *"$dns"* ]]
  result="已启用旁路由：$ip，网关与 DNS 为 $gateway / $dns"
elif [[ "$mode" == "DHCP" ]]; then
  "$networksetup" -setdhcp "$service"
  "$networksetup" -setdnsservers "$service" Empty
  current_info="$($networksetup -getinfo "$service")"
  current_dns="$($networksetup -getdnsservers "$service")"
  [[ "$current_info" == *"DHCP Configuration"* ]]
  result="已恢复 DHCP 和自动 DNS"
else
  print -u2 "不支持的模式：$mode"
  exit 2
fi

trap - ZERR
{
  print "$result"
  print "切换后："
  print -r -- "$current_info"
  print -r -- "$current_dns"
} >> "$log_file"
print "$result"
