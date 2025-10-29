# ----------------------------------------------------------
# SECURITY GROUP
# ----------------------------------------------------------
resource "aws_security_group" "my_sg" {
  name        = "simple-sg-01"
  description = "Allow SSH and monitoring ports"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10050
    to_port     = 10050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Zabbix agent
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------------------------------------
# IAM ROLE + INSTANCE PROFILE (for CloudWatch Agent)
# ----------------------------------------------------------

resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "CloudWatchAgentInstanceProfile"
  role = aws_iam_role.cloudwatch_agent_role.name
}

# ----------------------------------------------------------
# EC2 INSTANCE
# ----------------------------------------------------------
resource "aws_instance" "myec2" {
  ami           = "ami-0360c520857e3138f"  # Ubuntu
  instance_type = "t2.micro"
  key_name      = "jpkey"
  security_groups = [aws_security_group.my_sg.name]

  iam_instance_profile = aws_iam_instance_profile.cloudwatch_agent_profile.name

  user_data = file("testuserdata.sh")

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "simple-ec2"
  }
}

# ----------------------------------------------------------
# EXTRA DATA DISK
# ----------------------------------------------------------
resource "aws_ebs_volume" "data_disk" {
  availability_zone = aws_instance.myec2.availability_zone
  size              = 10
  tags = {
    Name = "data-disk"
  }
}

resource "aws_volume_attachment" "attach_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data_disk.id
  instance_id = aws_instance.myec2.id
}

# ----------------------------------------------------------
# CLOUDWATCH ALARMS
# ----------------------------------------------------------

# CPU Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU usage above 80%"
  dimensions = {
    InstanceId = aws_instance.myec2.id
  }
}

# Memory Alarm
resource "aws_cloudwatch_metric_alarm" "mem_high" {
  alarm_name          = "HighMemoryAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory usage above 80%"
  dimensions = {
    InstanceId = aws_instance.myec2.id
  }
}

# Disk Alarm (root "/")
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "HighDiskAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Disk usage above 85%"
  dimensions = {
    InstanceId = aws_instance.myec2.id
    path       = "/"
  }
}

# Status Check Alarm
resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  alarm_name          = "StatusCheckFailedAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"
  dimensions = {
    InstanceId = aws_instance.myec2.id
  }
}
