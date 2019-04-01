# High Performance Elasticsearch Container for EC2

When I tried to get the best performance of Elasticsearch cluster within limited number of nodes, I needed to optimize the host machine and needed to use G1GC.
This is a note that what I did for achieving this.

## What is this?
- Leveraging the Elastic's official docker image.
- Using G1GC for working with a large JVM heap size over 32GB.
- Some advices on the host machine settings to optimize the performance.

## Pre requirements
- AWS EC2 based.
- Instance types with NVMe ephemeral storage are recommended.

## Preparing the host machine

Every operations below should be executed by root or use `sudo`.

### Update
```bash
yum -y update
yum -y install docker
```

### Add lines to limits.conf
```bash
bash -c 'echo root soft nofile 1048576 >> /etc/security/limits.conf'
bash -c 'echo root hard nofile 1048576 >> /etc/security/limits.conf'
bash -c 'echo * soft nofile 1048576 >> /etc/security/limits.conf'
bash -c 'echo * hard nofile 1048576 >> /etc/security/limits.conf'
bash -c 'echo * soft memlock unlimited >> /etc/security/limits.conf'
bash -c 'echo * hard memlock unlimited >> /etc/security/limits.conf'
```

### Add lines to sysctl.conf
```bash
bash -c 'echo net.ipv4.tcp_tw_reuse = 1 >> /etc/sysctl.conf'
bash -c 'echo net.ipv4.tcp_fin_timeout = 30 >> /etc/sysctl.conf'
bash -c 'echo net.ipv4.ip_local_port_range = 16384 65535 >> /etc/sysctl.conf'
bash -c 'echo vm.max_map_count = 262144 >> /etc/sysctl.conf'
bash -c 'echo vm.swappiness = 1 >> /etc/sysctl.conf'
```

### Create rc.local to configure a RAID0 automatically

`vim /etc/rc.local` then add the following lines.
For i3, start use from /dev/nvme0n1. for Nitro Generation　instance types, nvme0n1 is used by EBS so use from nvme1n1.

```bash
# Set Hostname
hostname "$(curl -s http://169.254.169.254/latest/meta-data/instance-id |sed 's/\./-/g')"

# Init RAID
if [ ! -d /data ]
then
    mkdir /data  
fi

if [ ! -d /dev/md0 ]
then

	# Initialize the RAID with four NVMe drives
	mdadm --create --verbose --level=0 /dev/md0 --name=DATA --raid-devices=4 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
	mkfs.ext4 /dev/md0
	mdadm --detail --scan | tee -a /etc/mdadm.conf

	# Just in case, Update the kernel option
	dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)

	# Mount the RAID
	mount -a

fi

chmod 777 /data
```

### Add a line to fstab
```bash
bash -c 'echo /dev/md0 /data ext4 defaults,nofail,noatime,discard 0 2 >> /etc/fstab'
```

### Apply all changes
```bash
reboot
```

## Build
```bash
docker build -t elasticsearch .
```

## Launch

- Set values for both `Xms` and `Xmx` should be the same and it should be 50% of host memory. Don't need to consider 32GB limit.
- If you want to use the persistence storage on the host, add `-v /your/data/dir:/usr/share/elasticsearch/data`
- If you build a cluster, remove `-e "discovery.type=single-node"` and add `-e "cluster.name=elasticsearch_cluster" \`
- In this sample, `node.name` will be an instance ID of EC2. (`169.254.169.254` is AWS's API for providing the instance information.)

### Elasticsearch
```
docker run -d --net=host \
-e "node.master=true" \
-e "node.data=true" \
-e "node.ingest=true" \
-e "node.name=$(curl -s http://169.254.169.254/latest/meta-data/instance-id |sed 's/\./-/g')" \
-e "ES_JAVA_OPTS=-Xms128G -Xmx128G -XX:-UseConcMarkSweepGC -XX:-UseCMSInitiatingOccupancyOnly -XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=75" \
-e "network.host=0.0.0.0" \
-e "bootstrap.memory_lock=true" \
-e "thread_pool.bulk.queue_size=1000" \
-e "discovery.type=single-node" \
--ulimit nofile=524288:524288 --ulimit memlock=-1:-1 \
--privileged \
--name elasticsearch \
elasticsearch
```

### Kibana
```
docker run -d --net=host \
-e "ELASTICSEARCH_URL=http://localhost:9200" \
-e "XPACK_SECURITY_ENABLED=false" \
-e "XPACK_GRAPH_ENABLE=false" \
-e "XPACK_APM_ENABLED=false" \
-e "XPACK_WATCHER_ENABLED=true" \
-e "XPACK_ML_ENABLED=false" \
-e "XPACK_MONITORING_ENABLED=true" \
-e "XPACK_MONITORING_UI_CONTAINER_ELASTICSEARCH_ENABLED=false" \
-e "SERVER_NAME=kibana" \
--ulimit nofile=524288:524288 --ulimit memlock=-1:-1 \
--name kibana \
docker.elastic.co/kibana/kibana:6.6.2
```
