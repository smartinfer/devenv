# devenv Zsh prompt — dependency-free, fast, and readable in light/dark themes.
[[ -o interactive ]] || return 0

autoload -Uz colors vcs_info add-zsh-hook
colors
setopt prompt_subst

zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '%F{green}+%f'
zstyle ':vcs_info:git:*' unstagedstr '%F{red}*%f'
zstyle ':vcs_info:git:*' formats ' %F{magenta}git:%b%f%c%u'
zstyle ':vcs_info:git:*' actionformats ' %F{yellow}git:%b|%a%f%c%u'

devenv_prompt_precmd() {
  vcs_info
}
add-zsh-hook -d precmd devenv_prompt_precmd 2>/dev/null
add-zsh-hook precmd devenv_prompt_precmd

# Two lines keep long paths and commands from fighting for horizontal space.
# A failed command leaves its exit status beside the next prompt.
PROMPT='%F{blue}╭─%f %F{cyan}%~%f${vcs_info_msg_0_}%(?.. %F{red}exit:%?%f)
%F{blue}╰─%f %(?.%F{green}.%F{red})❯%f '
RPROMPT='%F{8}%D{%H:%M}%f'
PROMPT_EOL_MARK='%F{8}…%f'
