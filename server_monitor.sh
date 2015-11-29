#!/bin/bash

app_id='5f04e621-b137-4fde-81be-b5d16b5c9160'
token='a1d05b7e-c025-4ca1-ae40-5e08c3aaf97c'

server_id=''
mount_point='/'
process='secret,netdata,vim'
nic='eth0'

warn_cpu=50
warn_ram=50
warn_disk=50
warn_conn=100

if [[ ! -f "/tmp/nd_server" ]]; then
  echo "$(curl -s0 https://netdata.io:2015/sys/get_server)" > /tmp/nd_server
fi
nd_server=$(cat /tmp/nd_server)

status=''

IFS=' ' read rx tx <<< $(cat /proc/net/dev | grep "$nic" | awk -F ':[ \t]*|[ \t]+' '{print $3,$11}') 

conn=$(netstat -an | wc -l)
if (( `bc <<< "${conn} >= ${warn_conn}"` )); then
  status="${status}conn:${conn},"
fi


uptime=$(date "+%Y-%m-%d %H:%M:%S" -d "`awk '{print $1}' /proc/uptime` seconds ago")

cpu=$(sed -n '2p' <(top -bn2 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'))
if (( `bc <<< "${cpu} >= ${warn_cpu}"` )); then
  status="${status}cpu:${cpu},"
fi

IFS=' ' read ram_used ram_total <<< $(free | awk 'NR==3{print $3, $3+$4}')
if (( `bc <<< "${ram_used}*100/${ram_total} >= ${warn_ram}"` )); then
  status="${status}ram:`bc<<<${ram_used}*100/${ram_total}`,"
fi

IFS=' ' read swap_used swap_total <<< $(free | awk 'NR==4{print $3, $2}')

IFS=' ' read disk_used disk_total <<< $(df "$mount_point" | awk 'NR==2{print $3, $2}')
if (( `bc <<< "${disk_used}*100/${disk_total} >= ${warn_disk}"` )); then
  status="${status}disk:`bc<<<${disk_used}*100/${disk_total}`,"
fi

mon_ps=''
IFS=',' read -ra arr_ps <<< "$process"
for ps in "${arr_ps[@]}"; do
  if [[ $(pidof "$ps") ]]; then
    mon_ps="${mon_ps}+${ps},"
  else
    status="${status}-${ps},"
    mon_ps="${mon_ps}-${ps},"
  fi
done

curl -X POST \
-H "token: ${token}" \
-H "app_id: ${app_id}" \
-d '{
  "SERVER_ID": "'"$server_id"'",
  "CPU": "'"$cpu"'",
  "RAM": "'"$ram_used"'",
  "RAM_TOTAL": "'"$ram_total"'",
  "SWAP": "'"$swap_used"'",
  "SWAP_TOTAL": "'"$swap_total"'",
  "DISK": "'"$disk_used"'",
  "DISK_TOTAL": "'"$disk_total"'",
  "NET_IN": "'"$rx"'",
  "NET_OUT": "'"$tx"'",
  "UP_TIME": "'"$uptime"'",
  "CONN": "'"$conn"'",
  "MON_PS": "'"$mon_ps"'",
  "STATUS": "'"$status"'"
}' \
"https://${nd_server}/api/server_monitor"
