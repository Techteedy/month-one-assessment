#!/bin/bash
yum update -y

# Install PostgreSQL
amazon-linux-extras enable postgresql14
yum install -y postgresql-server postgresql-contrib

# Initialize and start PostgreSQL
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql

# Setup postgres password and database
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'DBPass123!';"
sudo -u postgres psql -c "CREATE DATABASE techcorp_db;"

# Allow password authentication
sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf
sed -i 's/peer/md5/g' /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

# Setup password authentication for SSH
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
useradd -m dbuser 2>/dev/null
echo "dbuser:DBPass123!" | chpasswd
systemctl restart sshd