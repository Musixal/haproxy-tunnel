#!/bin/bash

# Logo
show_logo() {
echo -e "${BLUE}"
cat << "EOF"
 _   _   ___  ____________ _______   ____   __
| | | | / _ \ | ___ \ ___ \  _  \ \ / /\ \ / /
| |_| |/ /_\ \| |_/ / |_/ / | | |\ V /  \ V / 
|  _  ||  _  ||  __/|    /| | | |/   \   \ /  
| | | || | | || |   | |\ \\ \_/ / /^\ \  | |  
\_| |_/\_| |_/\_|   \_| \_|\___/\/   \/  \_/ 
                  by github.com/Musixal v1.0 
EOF
  echo -e "${NC}"
}

# Check if the script is being run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi


# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Installing..."
        if [[ $(uname) == "Darwin" ]]; then
            brew install jq
        else
            sudo apt-get update
            sudo apt-get install -y jq
        fi
    else
        echo "jq is already installed."
    fi
}

# Install jq
install_jq

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Fetch server country using ip-api.com
SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

# Function to display server location and IP
display_server_info() {
    echo -e "${GREEN}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${GREEN}Server IP:${NC} $SERVER_IP"
}

# Function to show HAProxy status
show_haproxy_status() {
    # Check if HAProxy is installed
    if ! command -v haproxy &>/dev/null; then
        echo -e "${RED}HAProxy is not installed.${NC}"
        return
    fi

    # Check the status of HAProxy service
    systemctl is-active --quiet haproxy && echo -e "${GREEN}HAProxy is active${NC}" || echo -e "${RED}HAProxy is not active${NC}"
}


# Function to install HAProxy
install_haproxy() {
    # Check if HAProxy is already installed
    if command -v haproxy &>/dev/null; then
        echo "HAProxy is already installed."  && sleep 1
        return
    fi

    echo "Installing HAProxy..."
    # Install HAProxy
    apt-get update
    apt-get install -y haproxy
    # Check if installation was successful
    if [ $? -eq 0 ]; then
        echo "HAProxy installed successfully."
    else
        echo "Failed to install HAProxy. Please check your internet connection or try again later."
    fi
    read -p "Press Enter to continue..."
}


# Function to configure tunnel
configure_tunnel() {

# Prompt the user for confirmation
read -p "All your previous configs will be deleted, continue? (yes/no): " confirm

# Check user's response
if ! [[ $confirm == "yes" || $confirm == "Yes" || $confirm == "YES" ]]; then
	echo -e "${RED}Operation cancelled by user.${NC}" && sleep 1
	return 
fi

# Define the default HAProxy configuration file path
haproxy_config_file="/etc/haproxy/haproxy.cfg"

# Verify if the file exists, if not, create it
if [ ! -f "$haproxy_config_file" ]; then
    touch "$haproxy_config_file"
fi

# Prompt the user for HAProxy bind port and corresponding Destination IP and port
echo "# HAProxy configuration generated by script" > "$haproxy_config_file"
echo "global" >> "$haproxy_config_file"
echo "    log /dev/log    local0" >> "$haproxy_config_file"
echo "    log /dev/log    local1 notice" >> "$haproxy_config_file"
echo "    chroot /var/lib/haproxy" >> "$haproxy_config_file"
echo "    stats socket /run/haproxy/admin.sock mode 660 level admin" >> "$haproxy_config_file"
echo "    stats timeout 30s" >> "$haproxy_config_file"
echo "    user haproxy" >> "$haproxy_config_file"
echo "    group haproxy" >> "$haproxy_config_file"
echo "    daemon" >> "$haproxy_config_file"
echo "" >> "$haproxy_config_file"
echo "defaults" >> "$haproxy_config_file"
echo "    log     global" >> "$haproxy_config_file"
echo "    mode    tcp" >> "$haproxy_config_file"
echo "    option  tcplog" >> "$haproxy_config_file"
echo "    option  dontlognull" >> "$haproxy_config_file"
echo "    timeout connect 5000ms" >> "$haproxy_config_file"
echo "    timeout client  50000ms" >> "$haproxy_config_file"
echo "    timeout server  50000ms" >> "$haproxy_config_file"
echo "" >> "$haproxy_config_file"

while true; do
    read -p "Enter HAProxy bind port: " haproxy_bind_port
    read -p "Enter Destination (Kharej) IP address: " destination_ip
    read -p "Enter Destination port: " destination_port

    # Append frontend and backend configurations to HAProxy configuration file
    echo "frontend frontend_$haproxy_bind_port" >> "$haproxy_config_file"
    echo "    bind *:$haproxy_bind_port" >> "$haproxy_config_file"
    echo "    default_backend backend_server_$haproxy_bind_port" >> "$haproxy_config_file"
    echo "" >> "$haproxy_config_file"
    echo "backend backend_server_$haproxy_bind_port" >> "$haproxy_config_file"
    echo "    server server_$haproxy_bind_port $destination_ip:$destination_port" >> "$haproxy_config_file"
    echo "" >> "$haproxy_config_file"

    read -p "Do you want to add another config? (yes/no): " add_another
    if [[ $add_another != "yes" ]]; then
        break
    fi
done

echo -e "${GREEN}Configuration updated successfully in $haproxy_config_file${NC}"

  
    # Restart HAProxy service
    systemctl restart haproxy
    
    read -p "Press Enter to continue..."
}

# Function to destroy tunnel
destroy_tunnel() {
    echo -e "${RED}Stop HAProxy service...${NC}"
    
    # Stop HAProxy service
    systemctl stop haproxy

    echo "Tunnel destroyed."
    echo "The config file is stored in /etc/haproxy/haproxy.cfg path"
    read -p "Press Enter to continue..."
}

# Function to reset service
reset_service() {
    echo "Restarting HAProxy service..."
    systemctl restart haproxy
    echo -e "${GREEN}HAProxy service restarted.${NC}"
    read -p "Press Enter to continue..."

}

view_haproxy_log_realtime() {
    # Define HAProxy log file path
    haproxy_log_file="/var/log/haproxy.log"

    # Check if HAProxy log file exists
    if [ ! -f "$haproxy_log_file" ]; then
        echo "HAProxy log file not found at $haproxy_log_file"
        return 1
    fi

    # Display HAProxy log in real-time
    echo "Displaying real-time HAProxy log ($haproxy_log_file):"
    tail -f "$haproxy_log_file"
}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Function to display menu
display_menu(){
	clear
	show_logo
	display_server_info
	echo "-------------------------------"
	show_haproxy_status
    echo "-------------------------------"
    echo "Menu:"
    echo -e "${GREEN}1. Install HAProxy${NC}"
    echo -e "${BLUE}2. Tunnel Configure${NC}"
    echo -e "${RED}3. Stop HAProxy Service${NC}"
    echo -e "${YELLOW}4. Restart HAProxy Service${NC}"
    echo -e "5. View HAProxy real-time logs"
    echo "6. Exit"
    echo "-------------------------------"
  }
# Function to read user input
read_option(){
    read -p "Enter your choice (1-5): " choice
    case $choice in
        1) install_haproxy ;;
        2) configure_tunnel ;;
        3) destroy_tunnel ;;
        4) reset_service ;;
        5) view_haproxy_log_realtime ;;
        6) echo "Exiting..." && exit ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
    esac
}

# Main loop
while true
 do
	display_menu
	read_option
done
