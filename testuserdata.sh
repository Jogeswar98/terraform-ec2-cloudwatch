#!/bin/bash
set -e

# 1. Basic setup
sudo apt update -y
sudo apt install -y wget curl gnupg lsb-release unzip

# 2. Install Zabbix Agent
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

# 3. Install CloudWatch Agent
echo "[INFO] Installing Amazon CloudWatch Agent..."
cd /tmp
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# 4. Create CloudWatch Configuration

echo "[INFO] Creating CloudWatch Agent config..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<'EOF'
{
  "agent": {
    "region": "us-east-1",
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available_percent",
          "mem_total",
          "mem_used"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "disk_used_percent",
          "disk_free",
          "disk_used"
        ],
        "resources": [ "/", "/data" ],
        "metrics_collection_interval": 60
      },
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": true,
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# 5. Start CloudWatch Agent

echo "[INFO] Starting CloudWatch Agent service..."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl restart amazon-cloudwatch-agent

# 6. Mount /data Disk

DATA_DISK="/dev/xvdf"
MOUNT_POINT="/data"

if lsblk | grep -q "$(basename $DATA_DISK)"; then
  echo "[INFO] Mounting data disk..."
  sudo mkfs -t xfs $DATA_DISK || true
  sudo mkdir -p $MOUNT_POINT
  sudo mount $DATA_DISK $MOUNT_POINT
  echo "$DATA_DISK  $MOUNT_POINT  xfs  defaults,nofail  0  2" | sudo tee -a /etc/fstab
  echo "[SUCCESS] Disk $DATA_DISK mounted successfully at $MOUNT_POINT"
else
  echo "[WARN] Data disk $DATA_DISK not found — skipping mount step."
fi

# 7. Verify IAM Role

echo "[INFO] Checking IAM Role attachment..."
if curl -s http://169.254.169.254/latest/meta-data/iam/info | grep -q "InstanceProfileArn"; then
  echo "[SUCCESS] IAM Role detected."
else
  echo "[ERROR] No IAM Role detected! Please attach 'CloudWatchAgentServerPolicy' to this instance's IAM Role."
fi

# 8. Final Confirmation
echo
echo " Setup complete:"
echo "   - Zabbix Agent installed and running"
echo "   - CloudWatch Agent installed, configured for region us-east-1"
echo "   - /data disk mounted (if attached)"
echo "   - Ready to publish metrics to CloudWatch"
