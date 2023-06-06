echo '##################################################################'
echo '#################  Configuring Git Local  #######################'
echo '##################################################################'

rm -rf ~/.gitconfig
touch ~/.gitconfig

echo "# This is Git's per-user configuration file.
[user]
	name = Gabriel Gripp
	email = 550632+grippado@users.noreply.github.com
# Please adapt and uncomment the following lines:
#	name = Gabriel Gripp
#	email = 550632+grippado@users.noreply.github.com
[pull]
	rebase = false" >> ~/.gitconfig

