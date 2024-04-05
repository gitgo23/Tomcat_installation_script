#!/bin/bash

# Author: Enoch Gyampoh
# Date Modified: 5/04/2024

current_datetime=$(date +"%Y-%m-%d_%H:%M:%S")
logfile="/var/log/tomcat-install_${current_datetime}.log"

# Function to log and exit on error
log_and_exit() {
    echo "Error: $1" | sudo tee -a "${logfile}"
    exit 1
}

# Function to log to both file and terminal
log() {
    echo "$1" | sudo tee -a "${logfile}"
}

# Check if the log file exists; if not, create it
if [ ! -e "$logfile" ]; then
    touch "$logfile" || log_and_exit "Unable to create log file."
fi

# Set hostname
echo "Setting hostname..."
sudo hostnamectl set-hostname tomcat || log_and_exit "Unable to set hostname."
log "Setting hostname - Completed"

# Update and upgrade
echo "Updating and upgrading server..."
sudo apt update -y || log_and_exit "Unable to update packages."
sudo apt upgrade -y || log_and_exit "Unable to upgrade packages."
log "Step 2: Update and upgrade - Completed"

# Change directory to /opt/ and run commands in a subshell
(
    cd /opt/ || exit

    # Install dependencies
    echo "Installing Java Development Kit..."
    sudo apt install default-jdk -y || log_and_exit "Unable to install dependencies."     
    log "Step 3: Install dependencies - Completed"

    # Download and extract Apache Tomcat
    echo "Downloading Tomcat..."
    sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz
    sudo tar -xzvf apache-tomcat-9.0.85.tar.gz
    sudo rm apache-tomcat-9.0.85.tar.gz
    sudo mv apache-tomcat-9.0.85/ /opt/tomcat9 || log_and_exit "Unable to install Tomcat."    log "Step 4: Download and extract Apache Tomcat - Completed"

    # Giving Executable Permission to Tomcat
    sudo chmod 777 -R /opt/tomcat9 || log_and_exit "Unable to set permissions for Tomcat."
    log "Step 5: Set permissions for Tomcat - Completed"
)

# Create Symbolic Links to Start and Stop Tomcat
sudo ln -s /opt/tomcat9/bin/startup.sh /usr/bin/starttomcat
sudo ln -s /opt/tomcat9/bin/shutdown.sh /usr/bin/stoptomcat
log "Step 6: Create Symbolic Links - Completed"

# Start Tomcat
echo "Starting Tomcat server..."
sudo starttomcat || log_and_exit "Unable to start Tomcat."
log "Step 7: Start Tomcat - Completed"

# Define the content to be added to the tomcat.service file
tomcat_service_content="[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64
Environment=CATALINA_PID=/opt/tomcat9/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat9
Environment=CATALINA_BASE=/opt/tomcat9
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'  

ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh

User=root
Group=root
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target"

# Write the content to a temporary file
echo "$tomcat_service_content" > /tmp/tomcat_service_content.tmp

# Use sudo to edit the tomcat.service file with vi and paste the content from the temporary file
sudo vi -c "set paste" -c "normal G" -c "set paste" -c "normal i" -c "r /tmp/tomcat_service_content.tmp" -c "normal ZZ" /etc/systemd/system/tomcat.service

# Remove the temporary file
rm /tmp/tomcat_service_content.tmp

# Roloading Daemon
sudo systemctl daemon-reload

# Enabling Tomcat
sudo systemctl enable --now tomcat

# Comment out valve
echo "Configuring Tomcat..."
file_path=/opt/tomcat9/webapps/manager/META-INF/context.xml
start_line=21
end_line=22

sudo sed -i -e "${start_line}s/^/<!-- /" "${file_path}" || log_and_exit "Unable to comment out valve in context.xml."
sudo sed -i -e "${end_line}s/$/ -->/" "${file_path}" || log_and_exit "Unable to comment out valve in context.xml."
log "Step 8: Comment out valve in context.xml - Completed"

# Add an admin to Tomcat users
tomcat_user_content=$(cat <<EOF
<tomcat-users>
    <role rolename="manager-gui"/>
    <role rolename="manager-script"/>
    <role rolename="manager-jmx"/>
    <role rolename="manager-status"/>
    <user username="admin" password="admin" roles="manager-gui, manager-script, manager-jmx, manager-status"/>
</tomcat-users>
EOF
)

echo "${tomcat_user_content}" | sudo tee /opt/tomcat9/conf/tomcat-users.xml > /dev/null || log_and_exit "Unable to add admin to Tomcat users."
log "Step 9: Add admin to Tomcat users - Completed"

echo "Tomcat has been installed and configured successfully!" | sudo tee -a "${logfile}"  

# Checkinh System Status
echo "Checking Status ..."
sudo systemctl status tomcat

