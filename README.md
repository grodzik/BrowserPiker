BrowserPiker
============

Browser proxy to choose which browser should open a link issued from 3rd party applications.

# Instalation

First of all you need latest version of Pike, you can obtain it from [this site](http://http://pike.lysator.liu.se).
Make sure that your version contains Standards.JSON pmod.

1. Copy BrowserPiker.pike to any of `$PATH` locations, most preferably some system one (for example `/usr/local/bin`).
2. Copy BrowserPiker.destop to `$HOME/.local/share/applications` or `/usr/share/applications`
3. Copy BrowserPiker.conf.sample to `$HOME/.config/BrowserPiker.conf` and edit it to your needs. This file contains
sample configuration that works on Ubuntu 12.04 and 1920x1080 resolution. This file is required for BrowserPiker
to work properly.

4. Additionally you can make BrowserPiker default web browser, for example using xdg-settings:
```xdg-settings set default-web-browser BrowserPiker.desktop```

# Configuration

## Complete list of config options:

### Main options
|option|type|is required|
-------|----|------------
browsers|array|yes
position|object|no
default_browser|string|no

### `browsers` options
|option|type|is required|
-------|----|------------
name|string|yes
cmd|string|yes
icon|string|yes
domains|array|no

### `position` options
|option|type|is required|
-------|----|------------
x|integer|no
y|integer|no
save_postion_on_exit|boolean|no
