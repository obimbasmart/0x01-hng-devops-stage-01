#!/bin/bash

# Check if the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if a filename is provided as an argument
if [ $# -eq 0 ]; then
    echo "Please provide a filename as an argument"
    exit 1
fi

# Set up log file and password file
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create log file if it doesn't exist
touch $LOG_FILE

# Create /var/secure directory if it doesn't exist
mkdir -p /var/secure

# Create password file if it doesn't exist and set permissions
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to log messages
log_message() {
    echo "$(date): $1" >> $LOG_FILE
}

# Read the input file line by line
while IFS=';' read -r username groups || [[ -n "$username" ]]; do
    # Remove leading/trailing whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping."
        continue
    fi

    # Create the user with a home directory
    useradd -m "$username"
    log_message "Created user: $username"

    # Create a personal group for the user
    groupadd "$username"
    usermod -g "$username" "$username"
    log_message "Created personal group for $username"

    # Generate a random password
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> $PASSWORD_FILE
    log_message "Set password for $username"

    # Add user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" > /dev/null 2>&1; then
            groupadd "$group"
            log_message "Created group: $group"
        fi
        usermod -a -G "$group" "$username"
        log_message "Added $username to group: $group"
    done

done < "$1"

echo "User creation process completed. Check $LOG_FILE for details."
