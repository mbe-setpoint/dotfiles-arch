#!/bin/zsh

function prompt()
{
    read "response? $1 Continue? [Y/n] "
    response=${response:l} #tolower
    if [[ $response =~ ^(y| ) ]] || [[ -z $response ]]; then
        print -P '%F{green} \nContinuing...%f'
    else
        print -P '%F{red} \nAborting...%f'
        exit 1
    fi
}

CHECK_SYMBOL='\u2713'
X_SYMBOL='\u2A2F'

#
# Run the command passed as 1st argument and shows the spinner until this is done
#
# @param String $1 the command to run
# @param String $2 the title to show next the spinner
# @param var $3 the variable containing the return code
#
function execute_and_wait() {
  local __resultvar=$3

  eval $1 >/tmp/execute-and-wait.log 2>&1 &
  pid=$!
  delay=0.05

  frames=('\u280B' '\u2819' '\u2839' '\u2838' '\u283C' '\u2834' '\u2826' '\u2827' '\u2807' '\u280F')

  echo "$pid" >"/tmp/.spinner.pid"

  # Hide the cursor, it looks ugly :D
  tput civis
  index=0
  framesCount=${#frames[@]}
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    printf "${YELLOW}${frames[$index]}${NC} ${GREEN}$2${NC}"

    let index=index+1
    if [ "$index" -ge "$framesCount" ]; then
      index=0
    fi

    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    sleep $delay
  done


  #
  # Wait the command to be finished, this is needed to capture its exit status
  #
  wait $!
  exitCode=$?

  if [ "$exitCode" -eq "0" ]; then
    printf "${CHECK_SYMBOL} ${2}                                                                \b\n"
  else
    printf "${X_SYMBOL} ${2}                                                                \b\n"
  fi

  # Restore the cursor
  tput cnorm

  # eval $__resultvar=$exitCode
}

function print_welcome_message()
{


echo " __  __ ____  _____      _    ____   ____ _   _"
echo "|  \/  | __ )| ____|    / \  |  _ \ / ___| | | |"
echo "| |\/| |  _ \|  _|     / _ \ | |_) | |   | |_| |"
echo "| |  | | |_) | |___   / ___ \|  _ <| |___|  _  |"
echo "|_|  |_|____/|_____| /_/   \_\_| \_|\____|_| |_|"

    print "\n"
    print -P "%F{blue} This tool will install the necessary dependencies and configurations. %f"
    print -P "%F{blue} For the most part you will only need to hit \'Enter\' to continue. Input the password for you user when asked to %f"
}


function get_user_choices()
{
    local choices
    read "choices?> "
    echo $choices
}

function ip_settings()
{
    print -P "\n%F{blue}=== Step 0: Setting up IP address ===%f"

    # Detect interface
    IFACE=$(ip -o link show | awk -F': ' '!/lo/ {print $2; exit}')

    # Detect existing values (if any)
    CURRENT_IP=$(ip -o -4 addr show "$IFACE" | awk '{print $4}')
    CURRENT_GW=$(ip route | awk '/default/ && $5=="'"$IFACE"'" {print $3; exit}')
    CURRENT_DNS=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | paste -sd' ' -)

    # Fallback defaults if nothing found
    [[ -z "$CURRENT_IP" ]] && CURRENT_IP="10.0.0.180/24"
    [[ -z "$CURRENT_GW" ]] && CURRENT_GW="10.0.0.1"
    [[ -z "$CURRENT_DNS" ]] && CURRENT_DNS="1.1.1.1 8.8.8.8"

    # Interactive prompt with defaults
    read "NEW_IP?Enter static IP [$CURRENT_IP]: "
    read "NEW_GW?Enter gateway [$CURRENT_GW]: "
    read "NEW_DNS?Enter DNS [$CURRENT_DNS]: "

    # Use defaults if empty input
    NEW_IP=${NEW_IP:-$CURRENT_IP}
    NEW_GW=${NEW_GW:-$CURRENT_GW}
    NEW_DNS=${NEW_DNS:-$CURRENT_DNS}

    sudo mkdir -p /etc/systemd/network

    # Write configuration
    cat <<EOF | sudo tee /etc/systemd/network/20-static.network >/dev/null
[Match]
Name=$IFACE

[Network]
Address=$NEW_IP
Gateway=$NEW_GW
DNS=$NEW_DNS
EOF

    sudo systemctl restart systemd-networkd
    print -P "%F{green}✓ Static IP configured (%f$NEW_IP%F{green})%f"
}

function power_settings()
{
    print -P "\n%F{blue}=== Fixing power settings ===%f"
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    print -P "%F{green}✓ Power settings configured%f"
}

function git_config()
{
    print -P "\n%F{blue}=== Fixing git settings ===%f"
    git config --global user.email "mbe@setpoint.no"
    git config --global user.name "Mads Bergdal"
    print -P "%F{green}✓ Git settings configured%f"
}

function dotfiles_and_software()
{
    print -P "\n%F{blue}=== Installing oh-my-zsh ===%f"
    if (( ${+ZSH} )); then
        print -P '%F{yellow}$ZSH is already present.\n%f'
        prompt ''
    else
        export RUNZSH=no
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        prompt 'Oh-my-zsh installed.'
    fi
    print -P "%F{green}✓ Oh-my-zsh setup completed%f"


    print -P "\n%F{blue}=== Installing packages ===%f"
    sudo pacman -S --needed base-devel btop caligula tmux virt-manager starship stow docker docker-compose ghostty fastfetch zoxide lazygit lazydocker bat ripgrep fzf eza mise
    if command -v paru >/dev/null 2>&1; then
	    print -P "%F{yellow}✓ paru already installed - skipping%f"
    else
	    git clone https://aur.archlinux.org/paru.git
	    cd paru
	    makepkg -si
	    git restore .
    fi
    sudo pacman -Fy #Syncs all sources

    mise plugins add neovim
    mise use --global neovim@nightly
    rm -rf ~/.config/nvim
    rm -rf ~/.local/share/nvim
    rm -rf ~/.local/state/nvim
    rm -rf ~/.cache/nvim
    rm -rf ~/.config/nvim/.git

    print -P "\n%F{blue}=== Installing dotfiles ===%f"
    git clone https://github.com/tmux-plugins/tpm.git ~/.tmux/plugins/tpm
    git clone https://github.com/mbe-setpoint/dotfiles-arch ~/.dotfiles
    cd ~/.dotfiles
    stow --adopt .
    git restore .
    cd ~
    source ~/.zshrc
    # git clone https://github.com/LazyVim/starter ~/.config/nvim
    git clone git@github.com-setpoint:mbe-setpoint/nvim-mbe.git ~/.config/nvim
    print -P "%F{green}✓ Dotfiles setup completed%f"
    
    prompt 'Install extra software?'

    print -P "\n%F{blue}=== Installing extra software ===%f"
    if command -v 1password >/dev/null 2>&1; then
	    print -P "%F{yellow}✓ 1password already installed - skipping%f"
    else
	    paru -S --noconfirm 1password
    fi
    if command -v zen-browser >/dev/null 2>&1; then
	    print -P "%F{yellow}✓ zen-browser already installed - skipping%f"
    else
	    paru -S --noconfirm zen-browser
    fi
    if command -v zeditor >/dev/null 2>&1; then
	    print -P "%F{yellow}✓ zed already installed - skipping%f"
    else
	    paru -S --noconfirm zed
    fi
    print -P "%F{green}✓ Extra software installed%f"
}

function ssh_service()
{
    print -P "\n%F{blue}=== Enabling and starting SSH service ===%f"
    if (sudo systemctl is-active --quiet sshd); then
        print -P "%F{yellow}SSH is already running.\n%f"
        prompt ''
    else
        sudo systemctl enable sshd
        sudo systemctl start sshd
        prompt 'SSH Daemon started.'
    fi
    print -P "%F{green}✓ SSH service setup completed%f"
}

function docker_service()
{
    print -P "\n%F{blue}=== Enabling and starting Docker service ===%f"
    if (sudo systemctl is-active --quiet docker); then
        print -P "%F{yellow}Docker is already running.\n%f"
        prompt ''
    else
        sudo systemctl enable docker
        sudo systemctl start docker
        # Add setpoint user to docker group
        print "Adding setpoint user to docker group"
        sudo usermod -aG docker setpoint
        prompt 'Docker service started.'
    fi
    print -P "%F{green}✓ Docker service setup completed%f"
}

function sync_browser()
{
  print -P "\n%F{blue}=== Browser sync: Syncing Browser data ===%f"
  if pgrep -x "zen-bin" > /dev/null; then
    prompt "Zen browser is running, it needs to be closed to sync."
    pkill -x "zen-bin"
  fi
  if [[ -d ~/.zen ]]; then
    print -P "%F{yellow}0)%f Backing up .zen folder"
    mv ~/.zen ~/.zen_backup
  fi
  git clone git@github.com-setpoint:mbe-setpoint/zen-sync.git ~/.zen

  print -P "%F{green}✓ Browser data syncked.%f"

}

function show_menu()
{
    print -P "\n%F{cyan}=== Wave Server Setup Menu ===%f"
    print -P "%F{white}Choose which steps to execute:%f\n"
    print -P "%F{yellow}0)%f Set static ip"
    print -P "%F{yellow}1)%f Fix power settings (disable hibernate/sleep)"
    print -P "%F{yellow}2)%f Configure git settings"
    print -P "%F{yellow}3)%f Install dotfiles and extra software"
    print -P "%F{yellow}4)%f Enable and start services"
    print -P "%F{yellow}5)%f Sync Browser data"
    print -P "%F{green}6)%f Run default steps"
    print -P "%F{red}9)%f Exit"
    print -P "\n%F{white}Enter your choices (e.g., 1,3,5 or 6): %f"
}

function execute_steps()
{
    local choices=$1
    local -a selected_steps

    # Parse comma-separated choices
    selected_steps=(${(s:,:)choices})

    for step in $selected_steps; do
        case $step in
            0)
                ip_settings
                ;;
            1)
                power_settings
                ;;
            2)
                git_config
                ;;
            3)
                dotfiles_and_software
                ;;
            4)
                ssh_service
                docker_service
                ;;
            5)
              sync_browser
                ;;
            6)
                print -P "\n%F{green}=== Running default steps ===%f"
                git_config
                dotfiles_and_software
                ssh_service
                docker_service
                break
                ;;
            9)
                print -P "\n%F{red}Exiting setup...%f"
                exit 0
                ;;
            *)
                print -P "%F{red}Invalid choice: $step%f"
                ;;
        esac
    done
}

# Main execution
print_welcome_message

while true; do
    show_menu
    choices=$(get_user_choices)

    # Handle exit choice
    if [[ $choices == "9" ]]; then
        print -P "\n%F{red}Exiting setup...%f"
        exit 0
    fi

    # Validate input
    if [[ -z $choices ]]; then
        print -P "%F{red}No choices entered. Please try again.%f"
        continue
    fi

    execute_steps $choices

    print -P "\n%F{green}=== Setup completed for selected steps ===%f"
    print -P "%F{blue}Now log out and log in again to start using the server%f"

    read "response? Would you like to run more steps? [y/N] "
    response=${response:l}
    if [[ ! $response =~ ^(y) ]]; then
        break
    fi
done

