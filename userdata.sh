#!/bin/bash
sudo apt update -y
sudo apt install -y wget curl gnupg lsb-release

# Add Zabbix repository manually
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

# Install CloudWatch Agent 
echo "Installing CloudWatch Agent..."
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

echo "✅ Setup complete. Check agent statuses using systemctl."
