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
INIT_PACKS=
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

    if ! ping -c 1 google.com &>/dev/null; then
        prompt -e "=> Error: Network connection not available!" >&2
        return 1
    fi
}

# Perform a packages update
function checkPackageUpdates() {
    prompt -w "Checking for package updates..."

    if sudo dnf -y upgrade --refresh; then
        prompt -s "=> All packages are up to date.\n"
    else
        prompt -e "=> Error: System update failed!" >&2
        exit 1
    fi
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

# Define a função
printValues() {
    local count=0
    local valuesArray=("${@}")

    for i in "${!valuesArray[@]}"; do
        if [ "$count" -eq 3 ]; then
            printf "\n"
            count=0
        fi

        printf "%-30s" "$((i+1)). ${valuesArray[$i]}"
        count=$((count+1))

        if [ -z "${valuesArray[i+1]}" ]; then
            printf "\n"
            count=0
        fi
    done
}

function readBasePackages() {
    local count=0

    # Reads the text file and stores the values in an array
    values=($(cat packages.data))

    # Displays the values and allows the user to choose which ones to use
    prompt -i "Available values:"
    printValues ${values[@]}

    # Selection option
    prompt -i "\n Enter the number of values you want to use, separated by a comma, or '0' to select all values:"
    read -p " => " userSelection

    # Converts user selection to an array
    if [ "$userSelection" == 0 ]; then
        chosenValues=("${values[@]}")
    else
        # Stores the user chosen integer values
        chosenPositions=($(echo "$userSelection" | tr ',' ' '))

        # Converts integer values to the correct string and stores in a new array
        for i in "${!chosenPositions[@]}"; do
            chosenValues[i]="${values[${chosenPositions[$i]}]}"
        done
    fi

    # Stores the selected values in a new array
    selectedValues=()

    # Asks the user if they want to add extra values
    prompt -w "\n Add an extra value? (y/N)"
    read -p " => " userAddValues

    # If the user wants to add extra values, they are asked to enter one value per line
    if [[ "$userAddValues" =~ ^[Yy]$ ]]; then
        prompt -w "\n Enter extra values (one per line, press CTRL+D to finish):"

        while read -p " => " extraValue; do
            chosenValues+=("$extraValue")
        done

        prompt "\n"
    fi

    # Shows the finals values
    prompt -i "Final values:"
    printValues ${chosenValues[@]}

    for i in "${!chosenValues[@]}"; do
        INIT_PACKS+="${chosenValues[i]} "
    done
}

# Install base packages
function baseInstall() {
    checkCopr "$REPO_PRELOAD"
    readBasePackages

    prompt -w "Starting user base packages instalation..."

    if sudo dnf -y install "${INIT_PACKS}"; then
        prompt -s "=> All packages successfully installed / No packages needed to be installed.\n"
    else
        prompt -e "=> Error: Installation of packages failed!" >&2
        exit 1
    fi
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

if initialCheck; then
    prompt -i ">>>>>>>>>>         SYSTEM UPGRADE          <<<<<<<<<<"
    #prompt "\n+++++ SYSTEM UPGRADE +++++\n"
    checkPackageUpdates
    prompt -i ">>>>>>>>>>   BASE PACKAGES INSTALLATION    <<<<<<<<<<"
    #prompt "\n+++++ BASE PACKAGES INSTALLATION +++++n"
    baseInstall
fi

#-> Menu:
#	#	3. Instalar fontes melhores
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