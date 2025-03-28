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
  arch -arm64 brew install git curl wget neovim neofetch
fi