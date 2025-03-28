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
  arch -arm64 brew install git curl wget zsh --force
  arch -arm64 brew install neovim neofetch btop --force
  arch -arm64 brew install font-jetbrains-mono-nerd-font --force
  arch -arm64 brew install google-chrome brave-browser choosy --force
  arch -arm64 brew install coconutbattery appcleaner stats itsycal rectangle --force
  arch -arm64 brew install spotify visual-studio-code hyper --force
fi