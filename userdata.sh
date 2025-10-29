#!/bin/bash
set -e
sudo apt update -y
sudo apt install -y wget curl gnupg lsb-release awscli

# ---------- ZABBIX INSTALL ----------
echo "Adding Zabbix Repository..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/zabbix.gpg

echo "deb [signed-by=/usr/share/keyrings/zabbix.gpg] https://repo.zabbix.com/zabbix/6.4/ubuntu $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/zabbix.list

sudo apt update -y
sudo apt install -y zabbix-agent || echo "Zabbix install failed!"
sudo systemctl enable zabbix-agent
sudo systemctl start zabbix-agent


# ---------- CLOUDWATCH AGENT INSTALL ----------
echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# ---------- CLOUDWATCH CONFIG ----------
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
        "resources": ["/", "/data"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl restart amazon-cloudwatch-agent


# ---------- DISK MOUNT ----------
DATA_DISK="/dev/xvdf"
MOUNT_POINT="/data"

if [ -b "$DATA_DISK" ]; then
  echo "Mounting data disk..."
  sudo mkfs -t xfs $DATA_DISK
  sudo mkdir -p $MOUNT_POINT
  sudo mount $DATA_DISK $MOUNT_POINT
  echo "$DATA_DISK  $MOUNT_POINT  xfs  defaults,nofail  0  2" | sudo tee -a /etc/fstab
  echo "Disk $DATA_DISK mounted successfully at $MOUNT_POINT"
else
  echo "Data disk not found: $DATA_DISK"
fi


# ---------- CREATE CLOUDWATCH ALARMS ----------
echo "Creating CloudWatch Alarms..."

# Get the current instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# CPU Alarm - Trigger if CPU > 80% for 5 minutes
aws cloudwatch put-metric-alarm \
  --alarm-name "High-CPU-Utilization-${INSTANCE_ID}" \
  --metric-name CPUUtilization \
  --namespace "CWAgent" \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:YOUR_SNS_TOPIC \
  --treat-missing-data notBreaching \
  --alarm-description "Alarm when CPU exceeds 80%"

# Memory Alarm - Trigger if memory usage > 80%
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Memory-Usage-${INSTANCE_ID}" \
  --metric-name mem_used_percent \
  --namespace "CWAgent" \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:YOUR_SNS_TOPIC \
  --treat-missing-data notBreaching \
  --alarm-description "Alarm when memory usage exceeds 80%"

# Disk Alarm - Trigger if disk usage > 85%
aws cloudwatch put-metric-alarm \
  --alarm-name "High-Disk-Usage-${INSTANCE_ID}" \
  --metric-name disk_used_percent \
  --namespace "CWAgent" \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID,Name=path,Value=/data \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:YOUR_SNS_TOPIC \
  --treat-missing-data notBreaching \
  --alarm-description "Alarm when disk usage exceeds 85%"

echo "✅ Setup complete: Zabbix, CloudWatch agent, and alarms configured!"
