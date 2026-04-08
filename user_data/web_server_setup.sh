#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Create HTML page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>TechCorp Web Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; background-color: #f0f0f0; }
        .box { background-color: white; padding: 40px; border-radius: 10px; display: inline-block; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #232f3e; }
        p { color: #ff9900; font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="box">
        <h1>TechCorp Web Application</h1>
        <p>Instance ID: $INSTANCE_ID</p>
        <p>Status: Running ✅</p>
    </div>
</body>
</html>
EOF

# Setup password authentication for SSH
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
useradd -m webuser 2>/dev/null
echo "webuser:WebPass123!" | chpasswd
systemctl restart sshd