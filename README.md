# ip_rotator
A bash script to automatically rotate your IP on the Tor network at a specified interval in minutes and, optionally, choose exit node regions.

The script will default to a 10 min rotation time and random exit nodes if you don't pass it any args.

## Installation and Use
You can clone the whole repo
```
git clone https://github.com/jshuntley/ip_rotator.git
```

You can also just curl the script itself
```
curl -O https://raw.githubusercontent.com/jshuntley/ip_rotator/refs/heads/main/rotor.sh \
chmod +x rotor.sh
```

Then run the script with
```
./rotor.sh [time in mins] [exit nodes separated by commas]
```

The script also supports --help & -h args

### Use Tor in your browser
After getting this running, in your browser proxy settings, choose manual. Then you can specify "socks5" address:"localhost" and port:"9050".

### "Torify" Your Shell
To run commands in your terminal using Tor, you either need to specify it for each command with
```
torsocks [COMMAND]
```
OR you can run
```
source torsocks on
```
to use Tor for every command in that session

### torrc Settings
You can change the locale settings in ~/.tor/torrc to stick to a specific region(s) for exit nodes
