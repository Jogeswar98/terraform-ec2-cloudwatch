#!/bin/bash
yum update -y

# 1. Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Create config file for CloudWatch agent
cat <<EOF >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem": {"measurement": ["mem_used_percent"], "metrics_collection_interval": 60},
      "disk": {"measurement": ["used_percent"], "metrics_collection_interval": 60, "resources": ["/"]},
      "cpu": {"measurement": ["cpu_usage_idle"], "metrics_collection_interval": 60, "totalcpu": true}
    }
  }
}
EOF

# Start the CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# 2. Install Zabbix Agent
yum install -y zabbix-agent
systemctl enable zabbix-agent
systemctl start zabbix-agent

# 3. Mount the Data Disk
DATA_DISK="/dev/sdf"
MOUNT_POINT="/data"

if [ -b "$DATA_DISK" ]; then
  mkfs -t xfs $DATA_DISK
  mkdir -p $MOUNT_POINT
  mount $DATA_DISK $MOUNT_POINT
  echo "$DATA_DISK  $MOUNT_POINT  xfs  defaults,nofail  0  2" >> /etc/fstab
fi
