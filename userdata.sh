#!/bin/bash
# Update packages and install prerequisites
sudo apt update -y
sudo apt install -y wget curl gnupg lsb-release

#########################################
# 🧠 ZABBIX AGENT INSTALLATION
#########################################
echo "Adding Zabbix Repository..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://repo.zabbix.com/zabbix-official-repo.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/zabbix.gpg

echo "deb [signed-by=/usr/share/keyrings/zabbix.gpg] https://repo.zabbix.com/zabbix/6.4/ubuntu $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/zabbix.list

sudo apt update -y
sudo apt install -y zabbix-agent

sudo systemctl enable zabbix-agent
sudo systemctl start zabbix-agent

#########################################
# ☁️ CLOUDWATCH AGENT INSTALLATION
#########################################
echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

#########################################
# 🧰 CREATE BASIC CLOUDWATCH CONFIG
#########################################
echo "Creating CloudWatch Agent config..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "cpu": {
        "measurement": ["cpu_usage_idle"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

#########################################
# 🚀 START CLOUDWATCH AGENT
#########################################
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl restart amazon-cloudwatch-agent

echo "✅ Setup complete: Zabbix and CloudWatch agents are installed and configured!"
