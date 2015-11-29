#!/bin/bash

server_id="$1"
app_id="$2"
token="$3"

server_data=`curl -s -0 -X GET \
-H "token: ${token}" \
-H "app_id: ${app_id}" \
"https://netdata.io:2015/api/query_server?query=1&params=${server_id}"`

if [[ ! -f "/usr/bin/jq" ]] || [[ ! -f "/usr/bin/curl"  ]]; then
  apt-get update && apt-get install -y jq curl
fi

server_profile=$(echo "$server_data" | jq -r '.data[0].SERVER_PROFILE')
mount_point=$(echo "$server_profile" | jq -r '.mount_point')
process=$(echo "$server_profile" | jq -r '.process')
nic=$(echo "$server_profile" | jq -r '.nic')
warn_cpu=$(echo "$server_profile" | jq -r '.warn_cpu')
warn_ram=$(echo "$server_profile" | jq -r '.warn_ram')
warn_disk=$(echo "$server_profile" | jq -r '.warn_disk')
warn_conn=$(echo "$server_profile" | jq -r '.warn_conn')

tmp_path="/tmp/server_monitor"
curl -s -0 https://raw.githubusercontent.com/elgs/server_monitor/master/server_monitor.txt > "$tmp_path"
chmod +x "$tmp_path"


sed -i s/__app_id__/${app_id}/g "$tmp_path"
sed -i s/__server_id__/${server_id}/g "$tmp_path"
sed -i s/__token__/${token}/g "$tmp_path"
sed -i s/__mount_point__/$(echo ${mount_point} | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g "$tmp_path"
sed -i s/__process__/${process}/g "$tmp_path"
sed -i s/__nic__/${nic}/g "$tmp_path"
sed -i s/__warn_cpu__/${warn_cpu}/g "$tmp_path"
sed -i s/__warn_ram__/${warn_ram}/g "$tmp_path"
sed -i s/__warn_disk__/${warn_disk}/g "$tmp_path"
sed -i s/__warn_conn__/${warn_conn}/g "$tmp_path"

mv "$tmp_path" /usr/bin
