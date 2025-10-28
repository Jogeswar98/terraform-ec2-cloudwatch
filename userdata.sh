#!/bin/bash
# Update system and install prerequisites
sudo apt update -y
sudo apt install -y wget curl gnupg2 lsb-release

# Download and install Zabbix repo for Ubuntu 22.04 (works on 24.04 too)
echo "Installing Zabbix Agent..."
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-3+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.4-3+ubuntu22.04_all.deb
sudo apt update -y

# Install Zabbix Agent
sudo apt install -y zabbix-agent

# Enable and start Zabbix Agent
sudo systemctl enable zabbix-agent
sudo systemctl start zabbix-agent

# Check Zabbix Agent status
systemctl status zabbix-agent | grep Active

# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Enable and start CloudWatch Agent
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

echo "✅ Installation complete: Zabbix and CloudWatch agents are installed and running."
