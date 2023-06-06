platform='unknown'
unamestr=$(uname)

if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='macos'
fi

echo 'I see you are using...' $platform
echo "Let's go"

if [[ "$platform" == 'linux' ]]; then
   echo '##################################################################'
   echo '#################  Update and Upgrade APT  #######################'
   echo '##################################################################'
   sudo apt update -y && sudo apt upgrade -y
elif [[ "$platform" == 'macos' ]]; then
   echo '##################################################################'
   echo '################  Install or Upgrade BREW  #######################'
   echo '##################################################################'
   which -s brew
      if [[ $? != 0 ]] ; then
         echo "Brew not founded, Installing"
         # Install Homebrew
         cmd=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
      else
         echo "Brew is here, upgrading"
         arch -arm64 brew upgrade
      fi
fi