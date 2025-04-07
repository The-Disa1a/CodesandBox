#!/bin/bash

# Set DEBIAN_FRONTEND to noninteractive to suppress prompts
export DEBIAN_FRONTEND=noninteractive

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

NGROK_AUTH_TOKEN=""

# Function to create user
create_user() {
    echo "Creating user and setting it up..."
    username="user"
    password="root"

    useradd -m "$username"
    echo "$username:$password" | chpasswd
    usermod -aG sudo "$username"
    sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd

    echo "User '$username' created and configured."
}

# Function to install and configure NoMachine and Ngrok
setup_nx_ngrok() {
    echo "Installing NoMachine..."
    wget -q https://download.nomachine.com/download/8.10/Linux/nomachine_8.10.1_1_amd64.deb -O /tmp/nomachine.deb
    dpkg -i /tmp/nomachine.deb > /dev/null 2>&1 || apt install -qq -y --fix-broken > /dev/null 2>&1

    echo "Installing Ngrok..."
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list > /dev/null
    apt update -qq > /dev/null 2>&1 && apt install -qq -y ngrok

    ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

    echo "Starting Ngrok tunnel on port 4000 (NoMachine default)..."
    ngrok tcp --region 4000 > /dev/null 2>&1 &

    echo "NoMachine and Ngrok setup complete."
}

# Function to install Google Chrome
install_chrome() {
    echo "Installing Google Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb
    dpkg -i /tmp/google-chrome.deb > /dev/null 2>&1 || apt install -qq -y --fix-broken > /dev/null 2>&1
    echo "Google Chrome installed!"
}

# Execute setup functions
create_user
setup_nx_ngrok
install_chrome

# Show Ngrok address for NoMachine
sleep 5
ngrok_addr=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*')
echo -e "\nAccess your NoMachine session via:\n$ngrok_addr"

# Main loop: live running time updated on the same line
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    running_time=$(( current_time - start_time ))
    live_time=$(printf "%02d:%02d:%02d" $((running_time/3600)) $(((running_time%3600)/60)) $((running_time%60)))

    echo -ne "\rRunning Time: $live_time"
    sleep 15
done
