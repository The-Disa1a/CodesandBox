#!/bin/bash

# Set DEBIAN_FRONTEND to noninteractive to suppress prompts
export DEBIAN_FRONTEND=noninteractive

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

NGROK_AUTH_TOKEN=""
REGION=""

# Function to create user
create_user() {
    echo "Creating User and Setting it up"
    username="user"
    password="root"
    
    useradd -m "$username"
    echo "$username:$password" | sudo chpasswd
    usermod -aG sudo "$username"
    sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd
    
    echo "User '$username' created and configured."
}

# Function to install and configure RDP using VNC and Ngrok
setup_vnc() {
    echo "Installing Desktop Environment and VNC..."
    apt update -qq > /dev/null 2>&1 && apt install -qq -y xfce4 xfce4-terminal tightvncserver wget curl tmate autocutsel nano tigervnc-standalone-server 

    echo "Installing and configuring Ngrok..."
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc 
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list 
    apt update -qq > /dev/null 2>&1 && apt install -qq -y ngrok 

    echo "Installation completed silently."
   
    ngrok config add-authtoken "$NGROK_AUTH_TOKEN"
    mkdir -p ~/.vnc
    echo "123456" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    export USER=root
    vncserver -geometry 1200x900 :1
    export DISPLAY=:1
    /usr/bin/autocutsel -fork
    /usr/bin/autocutsel -selection PRIMARY -fork
    ngrok tcp --region $REGION 5901 > /dev/null 2>&1 &
  
    echo "VNC and Ngrok setup completed."
}

# Function to install Google Chrome
install_chrome() {
    echo "Installing Google Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb
    dpkg --install /tmp/google-chrome.deb > /dev/null 2>&1 || apt install -qq -y --fix-broken > /dev/null 2>&1
    echo "Google Chrome Installed!"
}

# Execute initial setup functions
create_user
setup_vnc
install_chrome


# Show Ngrok address
ngrok_addr=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*' | sed 's/tcp:\/\///; s/"//g')
echo "$ngrok_addr"

# Main loop: live running time updated on the same line and automatic backup every 5 minutes
start_time=$(date +%s)
last_backup_time=$(date +%s)
backup_interval=3600  # 3600 seconds = 60 minutes

while true; do
    current_time=$(date +%s)
    running_time=$(( current_time - start_time ))
    live_time=$(printf "%02d:%02d:%02d" $((running_time/3600)) $(((running_time%3600)/60)) $((running_time%60)))
    
    # Update running time on the same line
    echo -ne "\rRunning Time: $live_time"
    
    # Check if 5 minutes have passed and perform backup if so
    if (( current_time - last_backup_time >= backup_interval )); then
         do_backup
         last_backup_time=$current_time
    fi
    
    sleep 15
done
