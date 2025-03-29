# ip_rotator
Rotates your IP on the Tor network at a specified interval in minutes.

## Use Tor in your browser
After getting this running, in your browser proxy settings, choose manual. Then you can specify "socks5" address:"localhost" and port:"9050".

## "Torify" Your Shell
To run commands in your terminal using Tor, you either need to specify it for each command with
```
torsocks [COMMAND]
```
OR you can run
```
source torsocks on
```
to use Tor for every command in that session

## torrc Settings
You can change the locale settings in ~/.tor/torrc to stick to a specific region(s) for exit nodes
