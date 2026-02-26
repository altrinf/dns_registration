#!/bin/bash
if (( $EUID != 0 )); then
	echo "Please run as root (sudo)."
	exit 1
fi

USER_FILE="users.txt"

touch "$USER_FILE"
	
register_user() {
	read -p "Username: " user
			
	if grep -q "^$user," "$USER_FILE"; then
		echo "Error: Username '$user' already exists."
	else
		read -s -p "Enter password: " pass
		echo ""
		
		hashed_pass=$(echo -n "$pass" | sha256sum | awk '{print $1}')
		
		echo "$user,$hashed_pass" >> "$USER_FILE"
		echo "User '$user' registered successfully."
	fi
}

login_user(){
	read -p "Username: " user
	read -s -p "Password: " pass
	
	hashed_pass=$(echo -n "$pass" | sha256sum | awk '{print $1}')
	
	if grep -q "^$user,$hashed_pass$" "$USER_FILE"; then
		echo -e "\nLogin successful! Welcome, $user."
		USER="$user"
		return 0
	else
		echo -e "\nError: Invalid username or password."
		return 1
		
	fi
}

IP="127.0.0.1"
HOSTS_FILE="/etc/hosts"

backup_hosts() {
    HOSTS_FILE="/etc/hosts"
    BACKUP_FILE="/etc/hosts.$(date +%F_%H-%M-%S).bak"

    if [[ -f "$HOSTS_FILE" ]]; then
        sudo cp "$HOSTS_FILE" "$BACKUP_FILE"
        echo "Backup created at $BACKUP_FILE"
    else
        echo "Error: $HOSTS_FILE not found!"
        exit 1
    fi
}

add_domain(){
	read -p "Enter custom domain (e.g. mytest.local): " domain
	HOST_ENTRY="${IP}	${domain}"
	validate="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"
	
	if [[ -z "$domain" ]]; then
		echo "Error: Domain can not be empty"
		exit 1
	fi
	
	if [[ "$domain" =~ $validate ]]; then
		echo "Syntax Valid: $domain"
		
		if grep -qE "[[:space:]]$domain([[:space:]]|\$)" "$HOSTS_FILE"; then
    			echo "Domain $domain exists in /etc/hosts."
   	 	else
   	 		backup_hosts
   	 		echo "$IP	$domain" >> "$HOSTS_FILE"
			echo "Adding new hosts: $IP	$domain"
			echo "New DNS added successfully."
			cat "$HOSTS_FILE" | grep "$domain"
		fi
	else
		echo "Error: Invalid domain name syntax."
    		exit 1
	fi
	
}

change_pass(){
	echo "--- Change Password ---"
	read -s -p "Enter old Password: " oldpass
	
	hashed_pass_old=$(echo -n "$oldpass" | sha256sum | awk '{print $1}')
	echo
	
	if grep -q "^$USER,$hashed_pass_old$" "$USER_FILE"; then
		read -s -p "Enter new Password: " pass1
		echo 
		read -s -p "Enter your Password again: " pass2
		
		if [[ "$pass1" != "$pass2" ]]; then
			echo -e "\nPassword doesn't match!"
		else
			hashed_pass_new=$(echo -n "$pass2" | sha256sum | awk '{print $1}')
			
			sed -i "s/^$USER,$hashed_pass_old$/$USER,$hashed_pass_new/" "$USER_FILE"
			echo -e "\nPassword changed successfully!"
		fi
	else
		echo "Old Password incorrect!"
	fi
}

remove_domain(){
	read -p "Enter the Domain you want to remove: " remove_domain
	
	if [[ -z "$remove_domain" ]]; then
		echo "Error: Domain can not be empty"
		exit 1
	fi
	
	if grep -qE "[[:space:]]$remove_domain([[:space:]]|\$)" "$HOSTS_FILE"; then
		sed -i "/$remove_domain/d" "$HOSTS_FILE"
		echo -e "\nDomain removed successfully!"
		cat "$HOSTS_FILE"
	else
		echo -e "\nDomain doesn't exist!"
		exit 1
	fi
}

delete_user(){
	read -p "Are you sure you want to delete you user? (y/n) " answer
	
	if [[ "$answer" == "y" ]]; then
		read -p "Please confirm again. (y/n) " answer1
		
		if [[ "$answer1"=="y" ]]; then
			sed -i "/$USER/d" "$USER_FILE"
			echo "User deleted successfully!"
			exit
		fi
	elif [[ "$answer" == "n" ]]; then
		return
	else
		echo -e "\nPlease enter 'y' or 'n'."
		return
	fi		
}

delete_other_user(){
	read -p "Enter the user you want to delete: " deluser
	
	if [[ -z "$deluser" ]]; then
		echo "Error: User can not be empty"
		exit
	fi
	
	if grep -q "$deluser" "$USER_FILE"; then
		read -p "Please confirm again if you want to delete $deluser. (y/n) " answer
		
		if [[ "$answer" == "y" ]]; then
			sed -i "/$deluser/d" "$USER_FILE"
			echo -e "\nUser deleted successfully!"
		elif [[ "$answer" == "n" ]]; then
			return
		else
			echo -e "\nPlease enter 'y' or 'n'."
			return
		fi

	else
		echo -e "\nUser doesn't exist!"
		
	fi
}



while true; do
	echo -e "\n--- Main Menu ---\n1. Register\n2. Login\n3. Exit"
	read -p "Select an option: " choice
	
	case $choice in
		1)
			register_user
			;;
		
		2)
			if login_user; then
				if [[ "$USER" == "admin" ]]; then
					while true; do
						echo -e "\n--- Main Menu ---\n1. Add Domain\n2. Remove Domain\n3. List Domains\n4. Change Password\n5. List Users\n6. Delete Other User\nq. Exit"
						read -p "Select an option: " c
						case $c in
							1)
								add_domain
							;;
							
							2)
								remove_domain
							;;
							
							3)
								cat /etc/hosts
							;;
							
							4)
								change_pass
							;;
							
							5)
								echo -e "\n--- Registered Users ---"
								cat "$USER_FILE" | cut -d',' -f1
							;;
							
							6)
								delete_other_user	
							;;
							
							q)
								echo "Exiting..."
								exit 0
								;;
							*)
								echo "Invalid option!"
								;;
						esac
				done	
				else
					while true; do
						echo -e "\n--- Main Menu ---\n1. Add Domain\n2. Remove Domain\n3. List Domains\n4. Change Password\n5. Delete User\nq. Exit"
						read -p "Select an option: " c
						case $c in
							1)
								add_domain
							;;
							
							2)
								remove_domain
							;;
							
							3)
								cat /etc/hosts
							;;
							
							4)
								change_pass
							;;
							
							5)
								delete_user
							;;
							
							q)
								echo "Exiting..."
								exit 0
								;;
							*)
								echo "Invalid option!"
								;;
						esac
					done	
				fi
			fi
			;;
			
		q)
			echo "Exiting..."
			exit 0
			;;
		*)
			echo "Invalid option!"
			;;
	esac
done
