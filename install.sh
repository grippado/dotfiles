#!/bin/bash

echo '
  ▄▀  █▄▄▄▄ ▄█ █ ▄▄  █ ▄▄  ██   ██▄   ████▄            
▄▀    █  ▄▀ ██ █   █ █   █ █ █  █  █  █   █            
█ ▀▄  █▀▀▌  ██ █▀▀▀  █▀▀▀  █▄▄█ █   █ █   █            
█   █ █  █  ▐█ █     █     █  █ █  █  ▀████            
 ███    █    ▐  █     █       █ ███▀                   
       ▀         ▀     ▀     █                         
                            ▀                          
██▄   ████▄    ▄▄▄▄▀ ▄████  ▄█ █     ▄███▄     ▄▄▄▄▄   
█  █  █   █ ▀▀▀ █    █▀   ▀ ██ █     █▀   ▀   █     ▀▄ 
█   █ █   █     █    █▀▀    ██ █     ██▄▄   ▄  ▀▀▀▀▄   
█  █  ▀████    █     █      ▐█ ███▄  █▄   ▄▀ ▀▄▄▄▄▀    
███▀          ▀       █      ▐     ▀ ▀███▀             
                       ▀                               
                                                       '
source $(pwd)/configs/git.sh

source $(pwd)/installers/brew.sh
source $(pwd)/installers/base.sh
source $(pwd)/installers/nvm.sh
source $(pwd)/installers/omzsh.sh
source $(pwd)/installers/fzf.sh

# declaring variables to install dependencies
wakatime=''
bettervim=''

echo "Creating config files"
rm -rf ~/.zshrc
touch ~/.zshrc
echo "#source zsh files" >> ~/.zshrc
echo "source $(pwd)/zsh/.zshrc_base" >> ~/.zshrc

echo '##################################################################'
echo '######################  Reload Configs  ##########################'
echo '##################################################################'

exec zsh -l

echo "Done!!"
