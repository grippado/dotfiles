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

# Create secrets file if it doesn't exist
if [ ! -f "$HOME/.secrets" ]; then
    touch "$HOME/.secrets"
    echo "# Add your secrets here" > "$HOME/.secrets"
    echo "GITHUB_TOKEN=your_github_token_here" >> "$HOME/.secrets"
    echo "Created ~/.secrets file. Please add your secrets there."
fi

# Make scripts executable
chmod +x $(pwd)/configs/secrets.sh
chmod +x $(pwd)/installers/*.sh

source $(pwd)/configs/git.sh
source $(pwd)/installers/base.sh
source $(pwd)/installers/package-manager.sh
source $(pwd)/installers/omzsh.sh
source $(pwd)/installers/fzf.sh
source $(pwd)/installers/bashtop.sh
source $(pwd)/installers/zsh-plugins.sh

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
