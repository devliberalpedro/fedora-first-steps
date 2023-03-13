#/bin/bash
#
# This script performs a initial fedora packages instalation for piotrek

ROOT_UID=0
MAX_DELAY=20							                    # max delay to enter root password
tui_root_login=

# Variables to store values imported from configuration files
betterFonts_file_options=()
copr_file_options=()
flatpak_file_options=()
microsoftKeys_file_options=()
packages_file_options=()

# Variables to store user-selected values
betterFonts_install_options=()
copr_install_options=()
flatpak_install_options=()
microsoftKeys_install_options=()
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

function nVidiaWarning() {
cat << EOF

>>> IMPORTANT <<<

Installing nVidia drivers requires some manual procedures.

First, select option number '1' from the menu below. Some packages will be installed
and then the kernel key generation procedure for secure boot will start.

>> A password must be created when prompted. <<

The password does not need to be complex and should be easy to memorize as it will
be requested the next time the system is started.

After this, the script will ask if it should restart the system automatically (recommended)
or if you want to restart later.

>> It is important to remember this password cause the procedure can only be completed after
restarting the system and enrolling the kernel key in secure boot. <<

When the system restarts, the secure boot key enrollment system will be displayed
on the screen. This procedure is part of the BIOS and must be performed for the drivers
to be successfully installed.

>> This screen will ask for the key that was created in the step before restarting the system. <<

The steps are described below:

1. Select “Enroll MOK“.
2. Click on “Continue“.
3. Select “Yes” and enter the password generated in the previous step
4. Select "OK" and your computer will restart again

After the system restart, restart the script and select the option referring to the nVidia driver
in the main menu and, later, select option 2 of the specific menu for the nVidia drivers.

EOF
}

function nVidiaReboot() {
cat << EOF

>>> IMPORTANT <<<

When the system restarts, the secure boot key enrollment system will be displayed
on the screen. This procedure is part of the BIOS and must be performed for the drivers
to be successfully installed.

>> This screen will ask for the key that was created in the step before restarting the system. <<

The steps are described below:

1. Select “Enroll MOK“.
2. Click on “Continue“.
3. Select “Yes” and enter the password generated in the previous step
4. Select "OK" and your computer will restart again

After the system restart, restart the script and select the option referring to the nVidia driver
in the main menu and, later, select option 2 of the specific menu for the nVidia drivers.

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

# Import GPG Keys
function keyGPGImport() {
    if sudo rpm --import "$1"; then
        prompt -s ">>>   GPG Key successfully imported!   <<<" 
    else
        return 1
    fi
}

# Reads default values defined in configuration files. Ignore lines starting with hashtag
function readDataFromFile() {
    # Analyze which configuration file should be used
    if [[ "$1" == "betterFonts" || "$1" == "coprRepos" || "$1" == "flatpak" || "$1" == "microsoftKeys" || "$1" == "packages" ]]; then
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
                elif [[ "$1" == "flatpak" ]]; then
                    flatpak_file_options+=("$line")
                elif [[ "$1" == "microsoftKeys" ]]; then
                    microsoftKeys_file_options+=("$line")
                elif [[ "$1" == "packages" ]]; then
                    packages_file_options+=("$line")
                fi
            fi
        done < "$file_name"
    else
        prompt -e "ERROR: Input parameter must be 'betterFonts', 'coprRepos', 'flatpak', 'microsoftKeys' or 'packages'"
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
    if ! readDataFromFile "$1"; then
        return 1
    fi

    # Determine options array based on argument
    case "$1" in
        betterFonts)
            options=("${betterFonts_file_options[@]}")
        ;;
        coprRepos)
            options=("${copr_file_options[@]}")
        ;;
        flatpak)
            options=("${flatpak_file_options[@]}")
        ;;
        microsoftKeys)
            options=("${microsoftKeys_file_options[@]}")
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

    if [ -z "$options" ]; then
        prompt -e "There are no options available for installing/enabling"
    else
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
        flatpak)
            flatpak_install_options=("${options[@]}")
        ;;
        microsoftKeys)
            microsoftKeys_install_options=("${options[@]}")
        ;;
        packages)
            packages_install_options=("${options[@]}")
        ;;
        *)
            prompt "Invalid argument: $1"
            return 1
        ;;
    esac

    if [ -z "$options" ]; then
        prompt -i "\n No value was given to be installed or enabled!"
    else
        # Shows the finals values
        prompt -s "Final values:"
        printValues ${options[@]}
    fi
}

# Function used to install/enable any required copr repository
function installCopr() {
    # Store the copr command in a local variable for better code readability
    local copr_list=$(dnf copr list)

    prompt -w "Manage required repositories..."
    chooseOptions "coprRepos"

    # Install/Enable copr repositories
    for i in "${!copr_install_options[@]}"; do
        prompt -i "\n Checking for '"${copr_install_options[i]}"' repository status..."

        # Checks if the repository is active
        if echo "$copr_list" | grep -q -i "${copr_install_options[i]}"; then
            # Checks if the repository is disabled
            if echo "$copr_list" | grep -q -i "disabled"; then
                prompt -i "=> Enabling the '"${copr_install_options[$i]}"' repository..."

                # Enable the repository
                sudo dnf copr enable "${copr_install_options[$i]}" -y
                
                prompt -s "=> The '"${copr_install_options[$i]}"' repository was successfully enabled!"
            # If the repository is already activated
            else
                prompt -s "=> The '"${copr_install_options[$i]}"' repository is already enabled!"
            fi
        # If the repository is not installed
        else
            prompt -w "=> Installing the '"${copr_install_options[$i]}"' repository..."
            
            # Try to install copr repositoy
            if sudo dnf copr enable "${copr_install_options[$i]}" -y; then
                prompt -s "=> The '"${copr_install_options[$i]}"' repository was successfully installed!"
            # If install was not successful
            else
                prompt -e "=> Failed to install the '"${copr_install_options[$i]}"' repository"
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
    if ! sudo dnf -y install "${packages_install_options[@]}"; then
        return 1
    fi
}

# Function used to install better fonts packages
function installBetterFonts() {
    prompt -w "\n Fonts packages management..."
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
function microsoftInstall() {
    prompt -w "Importing Microsoft signed GPG Key..."
    chooseOptions "microsoftKeys"

    # Import Microsoft signed GPG Key
    keyGPGImport "${microsoftKeys_install_options[@]}"

    # Local variables to Microsoft VSCode config file, repository file and package name
    local file_name_vscode="vscode.config"
    local yum_path_vscode="/etc/yum.repos.d/vscode.repo"
    local vscode_package="code"

    prompt -w "\n Installing Microsoft apps packages..."
    prompt "Config file: $file_name_vscode\n"

    # Check if the config file exists
    if [ ! -f "$file_name_vscode" ]; then
        prompt -e "ERROR: The file $file_name_vscode does not exist"
        exit 1
    fi

    prompt -i "Installing VSCode package..."
    prompt "Config file: $file_name_vscode\n"

    # Check if the vscode.repo file exists
    if [ ! -f "$yum_path_vscode" ]; then
        # Stores the values from the file in an array
        while read -r line; do
            # Verifies if the line is not a comment (starts with '#')
            if [[ ! $line =~ ^\s*# ]]; then
                echo "$line"
                echo "$line" | sudo tee -a "$yum_path_vscode" >> /dev/null
            fi
        done < "$file_name_vscode"
    else
        prompt -i "VSCode repository file already exists, ignoring current command\n"
    fi
    
    # Update packages cache
    prompt -w "Updating DNF cache and installing VSCode package..."
    if ! sudo dnf check-update; then
        prompt -e ">>>   ERROR: DNF cache update failed!   <<<"
        exit 1
    elif ! sudo dnf install "$vscode_package" -y; then
        prompt -e ">>>   ERROR: VSCode package install failed!   <<<"
        exit 1
    fi

    # Local variables to Microsoft teams config file, repository file and package name
    local file_name_teams="teams.config"
    local yum_path_teams="/etc/yum.repos.d/teams.repo"
    local teams_package="teams"

    prompt -w "\n Installing Microsoft teams package..."
    prompt "Config file: $file_name_teams\n"

    # Check if the vscode.repo file exists
    if [ ! -f "$yum_path_teams" ]; then
        # Stores the values from the file in an array
        while read -r line; do
            # Verifies if the line is not a comment (starts with '#')
            if [[ ! $line =~ ^\s*# ]]; then
                echo "$line"
                echo "$line" | sudo tee -a "$yum_path_teams" >> /dev/null
            fi
        done < "$file_name_teams"
    else
        prompt -i "Microsoft teams repository file already exists, ignoring current command\n"
    fi

    # Update packages cache
    prompt -w "Updating DNF cache and installing VSCode package..."
    if ! sudo dnf check-update; then
        prompt -e ">>>   ERROR: DNF cache update failed!   <<<"
        exit 1
    elif ! sudo dnf install "$teams_package" -y; then
        prompt -e ">>>   ERROR: Microsoft teams package install failed!   <<<"
        #exit 1
    fi

    prompt -s ">>>   Microsoft VSCode and Teams have been successfully installed!   <<<\n"
}

function flatpakInstall() {
    #
    local flatpakPackages="flatpak.x86_64 flatpak-libs.x86_64 flatpak-selinux.noarch flatpak-session-helper.x86_64"
    local flatpakRepo="https://flathub.org/repo/flathub.flatpakrepo"
    
    prompt -w "Install flatpak packages..."

    # Check if flatpak packages are installed
    if ! sudo dnf list installed | grep -q -i "flatpak"; then
        prompt -e "Flatpak is not installed on the system..."
        prompt -i "Installing flatpak on the system..."

        # Install flatpak packages if are not installed
        if ! sudo dnf -y install "$flatpakPackages"; then
            prompt -e ">>>   ERROR: Flatpak packages install failed!   <<<"
            exit 1
        fi
    fi

    # Enable flatpak repository
    if ! flatpak remote-add --if-not-exists flathub "$flatpakRepo"; then
        prompt -e ">>>   ERROR: Flatpak repository install failed!   <<<"
        exit 1
    fi

    chooseOptions "flatpak"
}

function installnVidia() {
: '
    local rpmFusionFree="https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    local rpmFusionNonFree="https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

    # Install RPMFusion repositories
    if ! sudo dnf install "$rpmFusionFree"; then
        prompt -e "Fail to install RPM Fusion free repositorie!"
        exit 1
    elif ! sudo dnf install "$rpmFusionNonFree"; then
        prompt -e "Fail to install RPM Fusion non-free repositorie!"
        exit 1
    elif ! sudo dnf upgrade --refresh && ! sudo dnf groupupdate core; then
        prompt -e "System repositories update faleid!"
        exit 1
    else
        prompt -e "Fail to install RPM Fusion repositories" 
        exit 1
    fi
'    
    # Receive file values
    local nVidiaPre="akmods kmodtool mokutil openssl"

    # Receive user-selected values
    local nVidiaPackages="akmod-nvidia gcc kernel-devel kernel-headers xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs xorg-x11-drv-nvidia-libs.i686"

    nVidiaWarning

    prompt -w ">>> This script install nVidia drivers in a clean install! <<<"
    prompt -w ">>> DO NOT USE TO UPDATE YOUR ALREADY INSTALLED DRIVERS! <<<\n"

    # Print menu
    prompt -w "nVidia drivers menu (automatically sign NVidia kernel)"
    prompt "1. Before key enrollment"
    prompt "2. After key enrollment\n"
    read -p "Choose only one option: " optionsSelection

    if [[ $optionsSelection -eq 1 ]]; then
        #
        prompt -w "Installing nVidia prerequisite packages"

        if ! sudo dnf -y install $nVidiaPre; then
            prompt -e "Error installing nVidia prerequisite packages!"
            exit 1
        else
            prompt -s "nVidia prerequisite packages successfuly installed"
        fi

        #
        prompt -w "Generate a signing key..."
        if ! sudo kmodgenca -a; then
            prompt -e "Error while generate a signing key!"
            exit 1
        fi

        #
        prompt -w "Initiate the key enrollment (make Linux kernel trust drivers signed with your key)..."
        if ! sudo mokutil --import /etc/pki/akmods/certs/public_key.der; then
            prompt -e "Error while initiate the key enrollment! "
        fi

        # Print menu
        prompt -w "It is highly recommended that you reboot your system now to continue the key enrollment process."

        #
        nVidiaReboot

        #
        read -p "Reboot system now? [Y/n]: " rebootSystem

        # 
        if [[ -z "$rebootSystem" ||  "$rebootSystem" =~ ^[Yy]$ ]]; then
            prompt -s "Rebooting..."
            #sudo reboot
        elif [[ "$rebootSystem" =~ ^[Nn]$ ]]; then
            prompt -w "Please restart as soon as possible."
            return 0
        else
            prompt -e "ERROR: Invalid option!"
            exit 1
        fi
    # 
    elif [[ $optionsSelection -eq 2 ]]; then
        prompt -w "Installing nVidia packages"
        if ! sudo dnf -y install $nVidiaPackages; then

            prompt -e "Error installing nVidia prerequisite packages!"
            exit 1
        else
            prompt -s "nVidia packages successfuly installed"
        fi

        #
        prompt -w "It is recommended to wait a few seconds before confirming that the kernel module has been compiled and boot image have been loaded."
        prompt -i "Waiting 5 seconds..."
        sleep 5

        # Make sure the kernel modules got compiled
        if ! sudo akmods --force; then
            prompt -e "ERROR: Kernel module has not been compiled"
        # Make sure the boot image got updated as well
        elif ! sudo dracut --force; then
            prompt -e "ERROR: Boot image has not been updated"
        else
            prompt -s "Kernel modules compiled and boot image update successfuly "
        fi

         # Print menu
        prompt -w "A system restart is required for all changes to take effect."
        read -p "Reboot system now? [Y/n]: " rebootSystemFinal

        # 
        if [[ -z "$rebootSystemFinal" ||  "$rebootSystemFinal" =~ ^[Yy]$ ]]; then
            prompt -s "Rebooting..."
            #sudo reboot
        elif [[ "$rebootSystemFinal" =~ ^[Nn]$ ]]; then
            prompt -w "Please restart as soon as possible."
            return 0
        else
            prompt -e "ERROR: Invalid option!"
            exit 1
        fi
    # 
    else
        prompt -w "Valor inválido! Por favor, escolha '1' ou '2'"
        prompt -e "Falha ao instalar os drivers nVidia!"
        exit 1
    fi
}

#############################
#   :::::: M A I N ::::::   #
#############################

# Welcome message
prompt -s "\t************************************************"
prompt -s "\t*           'sysUpdate (by piotrek)'           *"
prompt -s "\t*--                                          --*"
prompt -s "\t*  run ./fedFirstSteps.sh -h for more options  *"
prompt -s "\t************************************************\n"

# Check for root and internet connection
if initialCheck; then
    # Receive file values
    menuOptions=()
    # Receive user-selected values
    menuChosen=()

    # Print menu
    prompt -w "Menu (Choose one or more options separated by comman)"
    prompt "1. System upgrade (sudo dnf -y upgrade --refresh)"
    prompt "2. Base install (copr repositories, packages and better fonts)"
    prompt "3. Microsoft poackages (VSCode and Teams)"
    prompt "4. Flatpak packages install"
    prompt "5. nVidia install (Requires manual intervention)"
    prompt "0. All steps above"
    prompt "\n"
    read -p "Choose one or more options separated by comma: " optionsSelection

    # Validate user inserts and converts user selection to an array
    if [[ -z "$optionsSelection" ||  "$optionsSelection" == 0 ]]; then
        finalValues=("0")
        prompt -s "Selected all values!"
    else
        # Convert user input to array of indices
        IFS=',' read -ra indices <<< "$optionsSelection"

        # Validate indices and convert to array of options
        for i in "${indices[@]}"; do
            if [[ $i =~ ^[0-9]+$ && "$i" -gt 0 && $i -le 5 ]]; then
                menuChosen+=("$i")
            else
                prompt -e "Invalid value: $i"
                exit 1
            fi
        done

        # Remove duplicate elements and sort the array values
        finalValues=($(echo "${menuChosen[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

        # Check if the length of the array "menuChosen" is equal to 0
        if [[ "${#finalValues[@]}" -eq 0 ]]; then
            prompt -w "No values selected"
        else
            prompt "Selected values: ${finalValues[*]}"
        fi
    fi

    prompt -e "Final Values: ${finalValues[@]}"

    #
    for i in "${finalValues[@]}"; do
        echo "$i"
        case "$i" in
            0)
                prompt -i ">>>>>>>>>>         SYSTEM UPGRADE          <<<<<<<<<<"
                checkPackageUpdates
                prompt -i ">>>>>>>>>>   BASE PACKAGES INSTALLATION    <<<<<<<<<<"
                baseInstall
                prompt -i ">>>>>>>>>>   MICROSOFT APPS INSTALLATION   <<<<<<<<<<"
                microsoftInstall
                prompt -i ">>>>>>>>>>      FLATPAK INSTALLATION       <<<<<<<<<<"
                flatpakInstall
                prompt -i ">>>>>>>>>>   NVIDIA DRIVER INSTALLATION    <<<<<<<<<<"
                installnVidia
            ;;
            1)
                prompt -i ">>>>>>>>>>         SYSTEM UPGRADE          <<<<<<<<<<"
                checkPackageUpdates
            ;;
            2)
                prompt -i ">>>>>>>>>>   BASE PACKAGES INSTALLATION    <<<<<<<<<<"
                baseInstall
            ;;
            3)
                prompt -i ">>>>>>>>>>   MICROSOFT APPS INSTALLATION   <<<<<<<<<<"
                microsoftInstall
            ;;
            4)
                prompt -i ">>>>>>>>>>      FLATPAK INSTALLATION       <<<<<<<<<<"
                flatpakInstall
            ;;
            5)
                prompt -i ">>>>>>>>>>   NVIDIA DRIVER INSTALLATION    <<<<<<<<<<"
                installnVidia
            ;;
            *)
                prompt "Invalid argument: $i"
            ;;
        esac
    done
fi

: '
1. Verificar pacotes com caracteres especiais (packages.config) - baseInstall
2. Verifciar saída dupla ao atualizar o cache do dnf (microsoftInstall)
3. Verificar erro no respositório do Teams
'