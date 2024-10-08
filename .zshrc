source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh

eval "$(starship init zsh)"

# Set locale to US English
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8

# Bind Esc to clear the current input line
bindkey '\e' kill-whole-line
