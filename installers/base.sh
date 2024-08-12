platform='unknown'
unamestr=$(uname)

if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='macos'
fi

if [[ "$platform" == 'linux' ]]; then
  echo '##################################################################'
  echo '##############  Installing base terminal Apps  ###################'
  echo '##################################################################'
  sudo apt install git curl wget neovim lynx neofetch -y
elif [[ "$platform" == 'macos' ]]; then
  echo '##################################################################'
  echo '##############  Installing base terminal Apps  ###################'
  echo '##################################################################'
  arch -arm64 brew install git curl wget zsh
  arch -arm64 brew install neovim neofetch btop
  arch -arm64 brew install font-jetbrains-mono-nerd-font
  arch -arm64 brew install google-chrome brave-browser choosy
  arch -arm64 brew install coconutbattery appcleaner stats itsycal rectangle
  arch -arm64 brew install spotify visual-studio-code
fi