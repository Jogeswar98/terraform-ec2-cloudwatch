#!/bin/bash
# Update system and install basic tools
sudo apt update -y
sudo apt install -y wget curl unzip gnupg

# Install Zabbix repository and agent
echo "Installing Zabbix Agent..."
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-3+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_6.4-3+ubuntu24.04_all.deb
sudo apt update -y
sudo apt install -y zabbix-agent

# Start and enable zabbix-agent service
sudo systemctl enable zabbix-agent
sudo systemctl start zabbix-agent

# Verify zabbix-agent
systemctl status zabbix-agent | grep "Active"

# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Start and enable CloudWatch agent
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

echo "Zabbix and CloudWatch agents installed successfully."
