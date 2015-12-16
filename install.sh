#!/bin/bash

server_id="$1"
app_id="5f04e621b1374fde81beb5d16b5c9160"
token="a1d05b7ec0254ca1ae405e08c3aaf97c"

if [[ -f "/usr/bin/apt-get" ]]; then
	if [[ ! -f "/usr/bin/jq" ]] || [[ ! -f "/usr/bin/curl"  ]] || [[ ! -f "/usr/bin/bc"  ]]; then
		apt-get update && apt-get install -y jq curl bc
	fi
elif [[ -f "/usr/bin/yum" ]]; then
	if [[ ! -f "/usr/bin/jq" ]]; then
		wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
		chmod +x /usr/bin/jq
	fi
fi

nd_server=`curl -s0 https://netdata.io:2015/sys/get_server`

server_data=`curl -s -0 -X GET \
-H "token: $token" \
-H "app_id: $app_id" \
-F "params=$server_id" \
-F "query_params=1901-01-01 00:00:00"
"https://$nd_server/api/query_server?query=1"`

server_profile=$(echo "$server_data" | jq -r '.data[0].SERVER_PROFILE')
if [[ "$server_profile" == "null" ]]; then
  >&2 echo "Failed to get server infomation. Possibly invalid server id."
  exit 1
fi

curl -s -0 -X POST \
-H "token: $token" \
-H "app_id: $app_id" \
-F "query_params=$server_id" \
"https://$nd_server/api/init?exec=1"

version=$(echo "$server_data" | jq -r '.data[0].VERSION')
update_interval=$(echo "$server_data" | jq -r '.data[0].UPDATE_INTERVAL')
exec_offset=$(echo "$server_data" | jq -r '.data[0].EXEC_OFFSET')

mount_point=$(echo "$server_profile" | jq -r '.mount_point')
process=$(echo "$server_profile" | jq -r '.process')
nic=$(echo "$server_profile" | jq -r '.nic')
warn_cpu=$(echo "$server_profile" | jq -r '.warn_cpu')
warn_ram=$(echo "$server_profile" | jq -r '.warn_ram')
warn_swap=$(echo "$server_profile" | jq -r '.warn_swap')
warn_disk=$(echo "$server_profile" | jq -r '.warn_disk')
warn_conn=$(echo "$server_profile" | jq -r '.warn_conn')
warn_rx=$(echo "$server_profile" | jq -r '.warn_rx')
warn_tx=$(echo "$server_profile" | jq -r '.warn_tx')
warn_rx_rate=$(echo "$server_profile" | jq -r '.warn_rx_rate')
warn_tx_rate=$(echo "$server_profile" | jq -r '.warn_tx_rate')


if [[ ! "$update_interval" =~ ^[0-9]+$ ]] || (( "$update_interval" == 0 )); then
	update_interval=1
fi

tmp_path="/tmp/server_monitor"
curl -s -0 https://raw.githubusercontent.com/elgs/server_monitor/master/server_monitor.txt > "$tmp_path"
#cat server_monitor.txt > "$tmp_path"
chmod +x "$tmp_path"


sed -i s/__app_id__/${app_id}/g "$tmp_path"
sed -i s/__server_id__/${server_id}/g "$tmp_path"
sed -i s/__token__/${token}/g "$tmp_path"
sed -i s/__nd_server__/${nd_server}/g "$tmp_path"
sed -i s/__version__/${version}/g "$tmp_path"
sed -i s/__mount_point__/$(echo ${mount_point} | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g "$tmp_path"
sed -i s/__process__/${process}/g "$tmp_path"
sed -i s/__nic__/${nic}/g "$tmp_path"
sed -i s/__warn_cpu__/${warn_cpu}/g "$tmp_path"
sed -i s/__warn_ram__/${warn_ram}/g "$tmp_path"
sed -i s/__warn_swap__/${warn_swap}/g "$tmp_path"
sed -i s/__warn_disk__/${warn_disk}/g "$tmp_path"
sed -i s/__warn_conn__/${warn_conn}/g "$tmp_path"
sed -i s/__warn_rx__/${warn_rx}/g "$tmp_path"
sed -i s/__warn_tx__/${warn_tx}/g "$tmp_path"
sed -i s/__warn_rx_rate__/${warn_rx_rate}/g "$tmp_path"
sed -i s/__warn_tx_rate__/${warn_tx_rate}/g "$tmp_path"

mv "$tmp_path" /usr/bin
echo "*/$update_interval * * * * root sleep $exec_offset ; /usr/bin/server_monitor > /dev/null 2>&1" > /etc/cron.d/server_monitor
