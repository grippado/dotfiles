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

# declaring variables to install dependencies
wakatime='2eb832d9-2ddb-44fa-85c3-cd9c16fd8853'
    #  waka_2eb832d9-2ddb-44fa-85c3-cd9c16fd8853
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
