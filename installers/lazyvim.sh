echo '##################################################################'
echo '###################  Installing LazyVim  #########################'
echo '##################################################################'

# required
mv ~/.config/nvim{,.bak}

# optional but recommended
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}

echo 'Cloning LazyVim...'
git clone https://github.com/LazyVim/starter ~/.config/nvim

echo 'Removing LazyVim git directory...'
rm -rf ~/.config/nvim/.git

echo 'Start Neovim :)'