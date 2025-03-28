echo '##################################################################'
echo '###################  Installing Oh-My-ZSH  #######################'
echo '##################################################################'

cmd=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)

echo '##################################################################'
echo '###################  Installing Oh-My-ZSH  #######################'
echo '##################################################################'

cd ~/.oh-my-zsh/custom/plugins && git clone https://github.com/sobolevn/wakatime-zsh-plugin.git wakatime

cd ~/.dotfiles
