if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end
# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#	echo "Sairam!"
#end
# This fish greeting controls the whole greeting. Only touch when you have time.
function mkcd
	mkdir -p "$1" && cd -p "$1"
end
abbr hx helix
alias ls eza
abbr screenshot-area "grimblast save area"
abbr screenshot "grimblast save screen"
alias l eza
alias .. "cd .."
alias ... "cd ../.."
alias .... "cd ../../.."
abbr opencode "bunx opencode-ai"
abbr sairam "echo Sairam"
abbr rustcoresrc "cd $HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src"
abbr c clear
# zoxide
zoxide init fish | source
# bun
set --export BUN_INSTALL "$HOME/.bun"
fish_add_path --append "$BUN_INSTALL/bin"
