Small bash program for managing ssh keys. 

## Installation

```
sudo mkdir /var/lib/sshlsm && \
sudo curl -o /var/lib/sshlsm/sshlsm https://raw.githubusercontent.com/dalibor91/locksmith/master/locksmith.sh && \
sudo chmod +x /var/lib/sshlsm/sshlsm && \
sudo ln -s /var/lib/sshlsm/sshlsm /usr/local/bin/sshlsm
```

Script makes easy managing SSH keys, keys are splited, and program merges them all and adds them into ~/.ssh/authorized_keys

So you can name your ssh keys like 
 - joe@someserver.com
 - john@someserver.com
 - kelly@someserver.com 

and when you run 
```
~ sshlsm -l 
```
it will give you all keys that are added in authorized_keys

If you wish to add your key to some remote server you can run 
```
sshlsm --addme user@server
```

and first time you will have to use password because sshlsm needs to set up your key, next time you will be logged in automatically

If remote server uses this script for managing ssh keys, you can tun 
```
sshlsm --addmelsm user@server
```
It will ask you for password and keyname under which you want to save key on remote server.

For full list of commands run 
```
sshlsm --help
``` 



