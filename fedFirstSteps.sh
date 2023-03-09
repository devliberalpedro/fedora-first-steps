#/bin/bash
#
# This script performs a initial fedora packages instalation for piotrek

ROOT_UID=0
MAX_DELAY=20							                    # max delay to enter root password
tui_root_login=

# Variables to store values imported from configuration files
betterFonts_file_options=()
copr_file_options=()
gpgKeys_file_options=()
packages_file_options=()

# Variables to store user-selected values
betterFonts_install_options=()
copr_install_options=()
gpgKeys_install_options=()
packages_install_options=()

# Colors scheme
CDEF="\033[0m"                                 	        	# default color
CCIN="\033[0;36m"                              		        # info color
CGSC="\033[0;32m"                              		        # success color
CRER="\033[0;31m"                              		        # error color
CWAR="\033[0;33m"                              		        # waring color
b_CDEF="\033[1;37m"                            		        # bold default color
b_CCIN="\033[1;36m"                            		        # bold info color
b_CGSC="\033[1;32m"                            		        # bold success color
b_CRER="\033[1;31m"                            		        # bold error color
b_CWAR="\033[1;33m"                            		        # bold warning color

# Exit Immediately if a command fails
set -o errexit

# Display message colors
prompt () {
	case ${1} in
		"-s"|"--success")
			echo -e "${b_CGSC}${@/-s/}${CDEF}";;            # print success message
		"-e"|"--error")
			echo -e "${b_CRER}${@/-e/}${CDEF}";;            # print error message
		"-w"|"--warning")
			echo -e "${b_CWAR}${@/-w/}${CDEF}";;            # print warning message
		"-i"|"--info")
			echo -e "${b_CCIN}${@/-i/}${CDEF}";;            # print info message
		*)
			echo -e "$@"
		;;
	 esac
}

#######################################
#   :::::: F U N C T I O N S ::::::   #
#######################################

# how to use
function usage() {
cat << EOF

Usage: $0 [OPTION]...

OPTIONS (assumes '-a' if no parameters is informed):
  -a, --all          run all update system (dnf, flatpal and fwupdmgr) [Default]
  -d, --dnf          run 'dnf upgrade --refresh'
  -f, --flatpak      run 'flatpak update'
  -x, --firmware     run firmware update commands (fwupdmgr)

  -h, --help         Show this help

EOF
}

function initialCheck() {
    # Check for root access or if password is cached (if cache timestamp has not expired yet)
    if [[ "$UID" -eq "$ROOT_UID" ]] || sudo -n true > /dev/null 2>&1; then
        return 0
    else
        # Check if the variable 'tui_root_login' is not empty
        if [ -n "${tui_root_login}" ]; then
            return 0
        # If the variable 'tui_root_login' is empty, ask for passwork
        else
            prompt -w "[ NOTICE! ] -> Please, run me as root!"
            read -r -p " [ Trusted ] -> Specify the root password:" -t "${MAX_DELAY}" -s password
            
            if sudo -S <<< "${password}" true > /dev/null 2>&1; then
                prompt "\n"
                return 0
            else
                sleep 3
                prompt -e "[ ERROR!! ] -> Incorrect password!"
                return 1
            fi
        fi
    fi

    # Check for network connection and print an error message if it's not available
    if ! ping -c 1 google.com &>/dev/null; then
        prompt -e "=> ERROR: Network connection not available!" >&2
        return 1
    fi
}

# Perform a packages update
function checkPackageUpdates() {
    prompt -w "Checking for package updates..."

    # Try to execute user-selected packages installation
    if sudo dnf -y upgrade --refresh; then
        prompt -s ">>>   All packages are up to date!   <<<\n"
    # Print an error message if not successful
    else
        prompt -e ">>>   ERROR: System update failed   <<<" >&2
        exit 1
    fi
}

# Function to print the values of an array on screen
printValues() {
    # Counter local variable
    local count=0
    # Stores the array received by parameter
    local valuesArray=("${@}")

    # Loops through all values in the array
    for i in "${!valuesArray[@]}"; do
        # Inserts a line break after every three values read
        if [ "$count" -eq 2 ]; then
            printf "\n"
            count=0
        fi

        # Prints the value of position 'i' of the matrix and increments the counter
        printf "%-60s" "$((i+1)). ${valuesArray[$i]}"
        count=$((count+1))

        # Checks if it has reached the end of the array and, if so, inserts a line break
        if [ -z "${valuesArray[i+1]}" ]; then
            printf "\n"
            count=0
        fi
    done
}

# Reads default values defined in configuration files. Ignore lines starting with hashtag
function readDataFromFile() {
    # Analyze which configuration file should be used
    if [[ "$1" == "betterFonts" || "$1" == "coprRepos" || "$1" == "gpgKeys" || "$1" == "packages" ]]; then
        file_name="$1.config"

        prompt "Config file: $file_name\n"

        # Check if the file exists
        if [ ! -f "$file_name" ]; then
            prompt -e "ERROR: The file $file_name does not exist"
            return 1
        fi

        # Stores the values from the file in an array
        while read -r line; do
            # Verifies if the line is not a comment (starts with '#')
            if [[ ! $line =~ ^\s*# ]]; then
                if [[ "$1" == "betterFonts" ]]; then
                    betterFonts_file_options+=("$line")
                elif [[ "$1" == "coprRepos" ]]; then
                    copr_file_options+=("$line")
                elif [[ "$1" == "gpgKeys" ]]; then
                    gpgKeys_file_options+=("$line")
                elif [[ "$1" == "packages" ]]; then
                    packages_file_options+=("$line")
                fi
            fi
        done < "$file_name"
    else
        prompt -e "ERROR: Input parameter must be 'betterFonts', 'coprRepos', 'gpgKeys' or 'packages'"
        return 1
    fi
}

# Defines user choices for installation/enablements during script execution
function chooseOptions() {
    # Receive file values
    local options=()
    # Receive user-selected values
    local chosen=()

    # Read default values from config file
    readDataFromFile "$1"

     # Determine options array based on argument
    case "$1" in
        betterFonts)
        options=("${betterFonts_file_options[@]}")
        ;;
        coprRepos)
        options=("${copr_file_options[@]}")
        ;;
        gpgKeys)
        options=("${gpgKeys_file_options[@]}")
        ;;
        packages)
        options=("${packages_file_options[@]}")
        ;;
        *)
        prompt "Invalid argument: $1"
        return 1
        ;;
    esac

    # Displays the values and allows the user to choose which ones to use
    prompt -i "Available packages/repositories:"
    printValues "${options[@]}"

    # Selection option
    prompt -i "\n Enter the numbers of packages/repositories you want to use separated by a comma or '0' to select all values [default: 0]:"
    read -p " => " userSelection

    # Validate user inserts and converts user selection to an array
    if [[ -z "$userSelection" ||  "$userSelection" == 0 ]]; then
        chosen=("${options[@]}")
        prompt "Selected all values: ${chosen[*]}"
    else
        # Convert user input to array of indices
        IFS=',' read -ra indices <<< "$userSelection"

        # Validate indices and convert to array of options
        for i in "${indices[@]}"; do
            if [[ "$i" =~ ^[0-9]+$ && "$i" -gt 0 && "$i" -le ${#options[@]} ]]; then
                chosen+=("${options[$i-1]}")
            else
                prompt -e "Invalid value: $i"
            fi
        done

        if [[ "${#chosen[@]}" -eq 0 ]]; then
            prompt -w "No values selected"
        else
            prompt "Selected values: ${chosen[*]}"
        fi
    fi

    # Asks the user if they want to add extra values
    prompt -w "\n Add an extra packages/repositories? (y/N)"
    read -p " => " userAddValues

    # If the user wants to add extra values, they are asked to enter one value per line
    if [[ "$userAddValues" =~ ^[Yy]$ ]]; then
        prompt -w "\n Enter an extra packages/repositories (one per line, press CTRL+D to finish):"

        while read -p " => " extraValue; do
            chosen+=("$extraValue")
        done

        prompt "\n"
    fi

    options=("${chosen[@]}")

    case "$1" in
        betterFonts)
            betterFonts_install_options=("${options[@]}")
        ;;
        coprRepos)
            copr_install_options=("${options[@]}")
        ;;
        gpgKeys)
            gpgKeys_install_options=("${options[@]}")
        ;;
        packages)
            packages_install_options=("${options[@]}")
        ;;
        *)
            prompt "Invalid argument: $1"
            return 1
        ;;
    esac

    # Shows the finals values
    prompt -s "Final values:"
    printValues ${options[@]}
}

# Function used to install/enable any required copr repository
function installCopr() {
    # Store the copr command in a local variable for better code readability
    local copr_list=$(dnf copr list)

    prompt -w "Manage required repositories..."
    chooseOptions "coprRepos"

    # Install/Enable copr repositories
    for i in "${!copr_copr_options[@]}"; do
        prompt -w "\n Checking for '"${copr_copr_options[i]}"' repository status..."

        # Checks if the repository is active
        if echo "$copr_list" | grep -q -i "${copr_copr_options[i]}"; then
            # Checks if the repository is disabled
            if echo "$copr_list" | grep -q -i "disabled"; then
                prompt -i "=> Enabling the '"${copr_copr_options[$i]}"' repository..."

                # Enable the repository
                sudo dnf copr enable "${copr_copr_options[$i]}" -y
                
                prompt -s "=> The '"${copr_copr_options[$i]}"' repository was successfully enabled!"
            # If the repository is already activated
            else
                prompt -s "=> The '"${copr_copr_options[$i]}"' repository is already enabled!"
            fi
        # If the repository is not installed
        else
            prompt -w "=> Installing the '"${copr_copr_options[$i]}"' repository..."
            
            # Try to install copr repositoy
            if sudo dnf copr enable "${copr_copr_options[$i]}" -y; then
                prompt -s "=> The '"${copr_copr_options[$i]}"' repository was successfully installed!"
            # If install was not successful
            else
                prompt -e "=> Failed to install the '"${copr_copr_options[$i]}"' repository"
                return 1
            fi
        fi
    done
}

# Function used to install packages
function installPackages() {
    prompt -w "\n Default packages management..."
    chooseOptions "packages"

    prompt -w "\n Starting user base packages instalation..."

    # Try to install all packages in array
    if ! sudo dnf -y install "${packages_install_options[@]}" -y; then
        return 1
    fi
}

# Function used to install better fonts packages
function installBetterFonts() {
    prompt -w "\n Default packages management..."
    chooseOptions "betterFonts"

    prompt -w "\n Starting better fonts packages instalation..."

    # Try to install all packages in array
    if ! sudo dnf -y install "${betterFonts_install_options[@]}" -y; then
        return 1
    fi
}

# Install base packages
function baseInstall() {
    # Execute the copr manager function
    if installCopr; then
        prompt -s ">>>   copr repositories have been successfully installed!   <<<"
    else
        prompt -e ">>>   ERROR: Failed to install copr repositories!   <<<"
        exit 1
    fi

    # Install default packages (packages.config file)
    if installPackages; then
        prompt -s ">>>   All packages have been successfully installed!   <<<"
    else
        prompt -e ">>>   ERROR: Failed to installing packages!   <<<"
        exit 1
    fi

    # Install better fonts packages (betterFonts.config file)
    if installBetterFonts; then
        prompt -s ">>>   Fonts have been successfully installed!   <<<\n"
    else
        prompt -e ">>>   ERROR: Failed to installing fonts!   <<<"
        exit 1
    fi
}

# Install VSCode package
function vscodeInstall() {
    prompt -w "Installing VSCode package..."
    chooseOptions "gpgKeys"

    # Import Microsoft signed GPG Key
    if sudo rpm --import "${gpgKeys_install_options[@]}"; then
        prompt -s ">>>   GPG Keys successfully imported!   <<<" 
    else
        return 1
    fi

    # Local variables to vscode config file and vscode repository file
    local file_name="vscode.config"
    local yum_path="/etc/yum.repos.d/vscode.repo"

    prompt "Config file: $file_name\n"

    # Check if the config file exists
    if [ ! -f "$file_name" ]; then
        prompt -e "ERROR: The file $file_name does not exist"
        exit 1
    fi

    # Check if the vscode.repo file exists
    if [ ! -f "$yum_path" ]; then
        # Stores the values from the file in an array
        while read -r line; do
            # Verifies if the line is not a comment (starts with '#')
            if [[ ! $line =~ ^\s*# ]]; then
                echo "$line"
                echo "$line" | sudo tee -a "$yum_path" >> /dev/null
            fi
        done < "$file_name"
    else
        prompt -i "VSCode repository file already exists, ignoring current command"
    fi

    #
    local vscode_package="code"
    
    # Update packages cache
    prompt -w "Updating DNF cache and installing VSCode package..."
    if ! sudo dnf check-update; then
        prompt -e ">>>   ERROR: DNF cache update failed!   <<<"
        exit 1
    elif ! sudo dnf install "$vscode_package" -y; then
        prompt -e ">>>   ERROR: VSCode package install failed!   <<<"
        exit 1
    fi

    prompt -s ">>>   VSCode have been successfully installed!   <<<"
}

#############################
#   :::::: M A I N ::::::   #
#############################
if initialCheck; then
    prompt -i ">>>>>>>>>>         SYSTEM UPGRADE          <<<<<<<<<<"
    checkPackageUpdates
    prompt -i ">>>>>>>>>>   BASE PACKAGES INSTALLATION    <<<<<<<<<<"
    baseInstall
    prompt -i ">>>>>>>>>>      VS CODE INSTALLATION       <<<<<<<<<<"
    vscodeInstall
fi


#-> Menu:	
#	5. First flatpak install
#		- (Add repositório)
#		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
		
#		- (DBeaver)
#		flatpak install -y flathub io.dbeaver.DBeaverCommunity
		
#		- (Flatseal)
#		flatpak install -y flathub com.github.tchx84.Flatseal
		
#		- (Spotify)
#		flatpak install -y flathub com.spotify.Client
