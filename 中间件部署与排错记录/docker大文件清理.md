
```shell
sudo find /opt/docker_data -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr

sudo truncate -s 0
```