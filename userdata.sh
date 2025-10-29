#!/bin/bash
sudo apt update -y
sudo apt install -y wget curl gnupg lsb-release

#  ZABBIX Installation
echo "Adding Zabbix Repository..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/zabbix.gpg

# Create the repo list manually
echo "deb [signed-by=/usr/share/keyrings/zabbix.gpg] https://repo.zabbix.com/zabbix/6.4/ubuntu $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/zabbix.list

# Install Zabbix agent
sudo apt update -y
sudo apt install -y zabbix-agent || echo "Zabbix install failed!"

sudo systemctl enable zabbix-agent || true
sudo systemctl start zabbix-agent || true


# CLOUDWATCH agent Installation

echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb


# CREATE BASIC CLOUDWATCH CONFIG

echo "Creating CloudWatch Agent config..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "region": "us-east-1"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/", "/mnt/data"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

#  START CLOUDWATCH AGENT

sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl restart amazon-cloudwatch-agent
echo "Setup complete: Zabbix and CloudWatch agents are installed and configured!"
# 3. Mount the Data Disk
DATA_DISK="/dev/xvdf"
MOUNT_POINT="/data"

# Format the disk
sudo mkfs -t xfs $DATA_DISK

# Create the mount directory
sudo mkdir -p $MOUNT_POINT

# Mount the disk
sudo mount $DATA_DISK $MOUNT_POINT

# Make the mount persistent
echo "$DATA_DISK  $MOUNT_POINT  xfs  defaults,nofail  0  2" | sudo tee -a /etc/fstab

echo "Disk $DATA_DISK mounted successfully at $MOUNT_POINT"

echo "Setup complete: Zabbix and CloudWatch agents are installed and configured!"
