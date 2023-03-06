#/bin/bash
#
# This script performs a initial fedora packages instalation for piotrek

#
#DNF_CMD="sudo dnf install -y "
#DNF_COPR="sudo dnf copr enable -y "
#RPM_IMPORT="sudo rpm --import "

ROOT_UID=0
MAX_DELAY=20							                    # max delay to enter root password
tui_root_login=

#
INIT_PACKS_1="bleachbit chntpw darktable discord dnfdragora fira-code-fonts gimp gnome-extensions-app gnome-screenshot gnome-tweaks 'google-roboto*' grub-customizer"
INIT_PACKS_2="hexchat keepassxc 'mozilla-fira*' preload pycharm-community p7zip p7zip-plugins steam transmission udisks unzip unrar vim vlc zsh"
FONTS_PACK_1="fontconfig-font-replacements"
FONTS_PACK_2="fontconfig-enhanced-defaults"

# copr repositories variables
REPO_PRELOAD="elxreno/preload"
REPO_FONTS="chriscowleyunix/better_fonts"

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

# Function used to install/enable any required copr repository
function checkCopr() {
    # Store the copr command in a local variable for better code readability
    local copr_list=$(dnf copr list)
    
    prompt -w "Checking for '"$1"' repository status..."

    # Checks if the repository is active
    if echo "$copr_list" | grep -q -i "$1"; then
        # Checks if the repository is disabled
        if echo "$copr_list" | grep -q -i "disabled"; then
            prompt -w "=> Enabling the '"$1"' repository..."

            # Enable the repository
            sudo dnf copr enable "$1" -y
            
            prompt -s "=> The '"$1"' repository was successfully enabled!"
        # If the repository is already activated
        else
            prompt -s "=> The '"$1"' repository is already enabled!"
        fi
    # If the repository is not installed
    else
        prompt -w "=> Installing the '"$1"' repository..."
        
        # Try to install copr repositoy
        if sudo dnf copr enable "$1" -y; then
            prompt -s "=> The '"$1"' repository was successfully installed!"
        # If install was not successful
        else
            prompt -e "=> Failed to install the '"$1"' repository"
            exit 1
        fi
    fi
}

function readBasePackages() {
    # Reads the text file and stores the values in an array
    values=($(cat packages.data))

    # Displays the values and allows the user to choose which ones to use
    prompt -i "Available values:"

    for i in "${!values[@]}"; do
        echo "$((i+1)). ${values[$i]}"
    done

    # Selection option
    prompt -i "Enter the number of values you want to use, separated by a comma, or '0' to select all values:"
    read userSelection

    # Converts user selection to an array
    if [ "$userSelection" == 0 ]; then
        choosedValues=("${values[@]}")
    else
        choosedValues=($(echo "$userSelection" | tr ',' ' '))
    fi

    # Stores the selected values in a new array
    selectedValues=()

    for i in "${choosedValues[@]}"; do
        selectedValues+=("${values[$((i-1))]}")
    done

    # Displays selected values
    echo "Selected values:"

    for value in "${selectedValues[@]}"; do
        echo "$value"
    done

    # Asks the user if they want to add extra values
    echo "Add an extra value? (y/N)"
    read userAddValues

    # If the user wants to add extra values, they are asked to enter one value per line
    if [[ "$userAddValues" =~ ^[Yy]$ ]]; then
        echo "Enter extra values (one per line, press CTRL+D to finish):"
        while read extraValue; do
            choosedValues+=("$extraValue")
        done
    fi

    # Shows the finals values
    echo "Final values:"
    
    for value in "${choosedValues[@]}"; do
        echo "$value"
    done
}

# Perform a packages update
function checkPackageUpdates() {
    if [[ $EUID -ne 0 ]]; then
        prompt -e "=> Error: This function must be run as root!" >&2
        exit 1
    fi

    if ! ping -c 1 google.com &>/dev/null; then
        prompt -e "=> Error: Network connection not available!" >&2
        exit 1
    fi

    prompt -w "Checking for package updates..."

    if sudo dnf -y upgrade --refresh; then
        prompt -s "=> All packages are up to date."
    else
        prompt -e "=> Error: System update failed!" >&2
        exit 1
    fi
}

# Install base packages
function baseInstall() {
    prompt -i "\n=> Enabling elxreno/preload..."
    sudo dnf -y upgrade --refresh
}

# Install packages for better fonts
function betterFonts() {
    prompt -i "\n=> Cheking for packages updates..."
    sudo dnf -y upgrade --refresh
}

# Install VSCode package
function installVSCode() {
    prompt -i "\n=> Cheking for packages updates..."
    sudo dnf -y upgrade --refresh
}

#############################
#   :::::: M A I N ::::::   #
#############################

# Check for root access and proceed if it is present
if [[ "$UID" -eq "$ROOT_UID" ]]; then
    checkPackageUpdates
    prompt "\n+++++\n"
    checkCopr "$REPO_PRELOAD"
    prompt "\n+++++\n"
    readBasePackages
# Check if password is cached (if cache timestamp has not expired yet)
elif sudo -n true > /dev/null 2>&1; then
    checkPackageUpdates
    checkCopr "$REPO_PRELOAD"
    readBasePackages
else
    # Check if the variable 'tui_root_login' is not empty
    if [ -n "${tui_root_login}" ]; then
        checkPackageUpdates
        checkCopr "$REPO_PRELOAD"
        readBasePackages
    # If the variable 'tui_root_login' is empty, ask for passwork
    else
        prompt -w "[ NOTICE! ] -> Please, run me as root!"
        read -r -p "[ Trusted ] Specify the root password:" -t "${MAX_DELAY}" -s password
        #read -r -p " [ Trusted ] Specify the root password : " -t ${MAX_DELAY} -s password
        
        if sudo -S <<< "${password}" true > /dev/null 2>&1; then
            checkPackageUpdates
            checkCopr "$REPO_PRELOAD"
            readBasePackages
        else
            sleep 3
            prompt -e "\n [ Error! ] -> Incorrect password!\n"
            exit 1
        fi
    fi
fi

#-> Menu:
#	2. First DNF install (basic packages)
#		- (pre-requisito para o preload)
#		sudo dnf copr enable elxreno/preload -y
#		
#		- sudo dnf install -y bleachbit chntpw darktable discord dnfdragora fira-code-fonts gimp gnome-extensions-app gnome-screenshot gnome-tweaks 'google-roboto*' grub-customizer hexchat keepassxc 'mozilla-fira*' preload pycharm-community p7zip p7zip-plugins steam transmission udisks unzip unrar vim vlc zsh 
#	3. Instalar fontes melhores
#		- sudo dnf copr enable chriscowleyunix/better_fonts -y
#		- sudo dnf install fontconfig-font-replacements -y
#		- sudo dnf install fontconfig-enhanced-defaults -y
#	4. Instalar o VSCode
#		- (Importar chave GPG assinada pela Microsoft)
#		sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 
#		
#		- (Adicionar o repositório oficial do Microsoft Visual Studio Code)
#		sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
#		
#		- (Atualizar cache de pacotes) - Ou atualizar sistema com dnf upgrade --refresh
#		sudo dnf check-update
#		
#		- Instalar pacote VSCode
#		sudo dnf install code
#		
#	5. First flatpak install
#		- (Add repositório)
#		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#		
#		- (DBeaver)
#		flatpak install -y flathub io.dbeaver.DBeaverCommunity
#		
#		- (Flatseal)
#		flatpak install -y flathub com.github.tchx84.Flatseal
#		
#		- (Spotify)
#		flatpak install -y flathub com.spotify.Client
#*/