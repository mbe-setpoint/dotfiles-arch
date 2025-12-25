# Config from https://www.kishorenewton.com/posts/my-ultimate-developer-setup-zsh-config-2025/
fastfetch

# Path to your Oh My Zsh installation.
# export ZSH="$HOME/.oh-my-zsh"

# ZSH_THEME="setpoint"

# Initialize zinit with automatic installation
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ ! -f $ZINIT_HOME/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing zinit...%f"
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-patch-dl \

zinit snippet OMZL::git.zsh              # Git aliases and functions
zinit snippet OMZL::history.zsh          # Better history management
zinit snippet OMZL::key-bindings.zsh     # Standard key bindings
zinit snippet OMZL::theme-and-appearance.zsh  # Terminal colors
zinit snippet OMZL::completion.zsh       # Completion tweaks
zinit snippet OMZL::directories.zsh      # Directory navigation helpers

eval "$(starship init zsh)"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git)

# source $ZSH/oh-my-zsh.sh

# User configuration
# typeset -U path PATH
# path=(~/.local/share/bob/nvim-bin $path)
# export PATH
export EDITOR=nvim
export VISUAL=nvim
# Language settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# History settings
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt EXTENDED_HISTORY          # Save timestamp and duration
setopt SHARE_HISTORY             # Share between sessions
setopt HIST_IGNORE_ALL_DUPS      # No duplicates
setopt HIST_REDUCE_BLANKS        # Clean up commands

# Fast syntax highlighting and suggestions
zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting \
    atload"!_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions

zinit wait lucid for \
    agkozak/zsh-z \
    MichaelAquilina/zsh-you-should-use \
    zdharma-continuum/history-search-multi-word \
    paulirish/git-open \
    Aloxaf/fzf-tab

# Enhanced completions
zinit wait lucid for \
    blockf atpull'zinit creinstall -q .' \
        zsh-users/zsh-completions

# Initialize completion
autoload -Uz compinit && compinit

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' verbose yes
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':fzf-tab:complete:*' fzf-preview 'bat --color=always --line-range :50 {}'

function extract() {
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
      *.tar.gz)    tar xzf $1     ;;
      *.tar.xz)    tar xJf $1     ;;
      *.bz2)       bunzip2 $1     ;;
      *.rar)       unrar e $1     ;;
      *.gz)        gunzip $1      ;;
      *.tar)       tar xf $1      ;;
      *.tbz2)      tar xjf $1     ;;
      *.tgz)       tar xzf $1     ;;
      *.zip)       unzip $1       ;;
      *.Z)         uncompress $1  ;;
      *.7z)        7z x $1        ;;
      *)           echo "'$1' cannot be extracted via extract" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

function fzf_history_search() {
  local selected
  selected=$(fc -rl 1 | awk '{$1=""; print substr($0,2)}' | 
    fzf --height 40% --layout=reverse --border --color=border:blue \
        --preview='echo {}' --preview-window=down:3:wrap)
  LBUFFER=$selected
  zle reset-prompt
}
zle -N fzf_history_search
bindkey '^R' fzf_history_search

function fcd() {
  local dir
  dir=$(fd --type d --hidden --follow --exclude .git . "${1:-.}" | 
    fzf --preview 'eza --tree --level=1 --color=always {}' --preview-window=right:50%) &&
    cd "$dir"
}

function ff() {
  local file line
  read -r file line < <(rg --line-number --no-heading --color=always --smart-case "${*:-}" |
    fzf --ansi --delimiter : \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' |
    awk -F: '{print $1, $2}')
  if [[ -n "$file" ]]; then
    ${EDITOR:-vim} "$file" +$line
  fi
}

function in() {
    local -a inPkg=("$@")
    local -a arch=()
    local -a aur=()

    # Detect the AUR helper
    if pacman -Qi paru &>/dev/null ; then
        aurhelper="paru"
    elif pacman -Qi yay &>/dev/null ; then
        aurhelper="yay"
    else
        echo "No AUR helper found. Install paru or yay first."
        return 1
    fi

    # Sort packages by repo
    for pkg in "${inPkg[@]}"; do
        if pacman -Si "${pkg}" &>/dev/null ; then
            arch+=("${pkg}")
        else 
            aur+=("${pkg}")
        fi
    done

    # Install packages
    if [[ ${#arch[@]} -gt 0 ]]; then
        echo "Installing from official repositories: ${arch[@]}"
        sudo pacman -S --needed "${arch[@]}"
    fi
    
    if [[ ${#aur[@]} -gt 0 ]]; then
        echo "Installing from AUR: ${aur[@]}"
        ${aurhelper} -S --needed "${aur[@]}"
    fi
}

function command_not_found_handler() {
    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
    printf 'zsh: command not found: %s\n' "$1"
    local entries=( ${(f)"$(/usr/bin/pacman -F --machinereadable -- "/usr/bin/$1")"} )
    if (( ${#entries[@]} )) ; then
        printf "${bright}$1${reset} may be found in the following packages:\n"
        local pkg
        for entry in "${entries[@]}" ; do
            local fields=( ${(0)entry} )
            if [[ "$pkg" != "${fields[2]}" ]] ; then
                printf "${purple}%s/${bright}%s ${green}%s${reset}\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
            fi
            printf '    /%s\n' "${fields[4]}"
            pkg="${fields[2]}"
        done
    fi
    return 127
}

function update() {
    echo "📦 Starting system update..."
    
    # Determine package manager and update system packages
    if command -v paru &>/dev/null; then
        echo "⚙️ Updating with paru..."
        paru -Syu --noconfirm
    elif command -v yay &>/dev/null; then
        echo "⚙️ Updating with yay..."
        yay -Syu --noconfirm
    else
        echo "⚙️ Updating with pacman..."
        sudo pacman -Syu
    fi
    
    # Update zinit and plugins
    echo "🔌 Updating zinit plugins..."
    zinit self-update
    zinit update --parallel

    # Update other package managers if installed
    if command -v flatpak &>/dev/null; then
        echo "📄 Updating flatpak packages..."
        flatpak update -y
    fi
    
    if command -v snap &>/dev/null; then
        echo "📱 Updating snap packages..."
        sudo snap refresh
    fi
    
    # Clean up orphaned packages
    if command -v paru &>/dev/null || command -v yay &>/dev/null; then
        echo "🧹 Cleaning up orphaned packages..."
        pacman -Qtdq | sudo pacman -Rns - 2>/dev/null || echo "No orphaned packages to remove"
    fi
    
    # Clean package cache
    echo "🧼 Cleaning package cache..."
    if command -v paru &>/dev/null; then
        paru -Sc --noconfirm
    elif command -v yay &>/dev/null; then
        yay -Sc --noconfirm
    else
        sudo pacman -Sc --noconfirm
    fi
    
    echo "✅ System update complete!"
}


alias lg=lazygit
alias ld=lazydocker
alias cl=clear

#Initialize zoxide
eval "$(zoxide init zsh)"
#Initialize mise
eval "$(/usr/bin/mise activate zsh)"
