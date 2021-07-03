# raspi-headless-setup

Configure a Raspberry Pi OS microSD for running in headless mode.

## Synopsis

```sh
raspi-headless-setup.sh [options] SSID
```

## Description

This program is used to configure a Raspberry Pi to run headless.  A
headless Raspberry Pi is one that does not need a monitor, keyboard or
mouse. Interaction with it can be done over the network.  For example,
using the command line over SSH, or via a graphical session over
VNC. The only wired connection to the Raspberry Pi needed is the
power. Either Wi-Fi and/or a wired connection is required.


This program is run on the computer used to prepare a microSD card for
the Raspberry Pi. After imaging the Raspberry Pi OS onto the microSD
card, remount the microSD card and run this program.

This program can configure:

- Wi-Fi settings;
- SSH server;
- default "pi" user account password;
- default "pi" user account adding a SSH public key to .ssh/authorized_keys;
- hostname;
- timezone;
- locale;
- VNC server; and
- force the Raspberry Pi to  assume there is a HDMI display with a
  particular resolution.

### Options

#### Default user account credentials

- `-p | --pi-password` passwd

    Password for the "pi" user account. This can be used to change the
    default password of "raspberry".

    For better security, provide the password in a file with the `-P`
    option.

- `-P | --pi-password-file` filename

    Read the "pi" user account password from a file. This can be used
    to change the default password of "raspberry".

- `-k | --pi-ssh-pubkey` pubkey_file

    Create or add the contents of the _pubkey_file_ to the
    _.ssh/authorized_keys_ file for the "pi" user account.  By
    default, it will use the _~/.ssh/id_rsa.pub_ file, if it exists
    and `--nopubkey` has not been specified.

- `--no-pubkey`

    Do not configure the _.ssh/authorized_keys_ file for the "pi" user account.

#### Other defaults

- `-n | --hostname` name

    Set the hostname of the Raspberry Pi. This can be used to change
    the hostname from the default value of "raspberrypi".

- `-t | --timezone` tz_name

    Set the timezone. Timezone names are in the form of
    "Area/Location" and are case sensitive.
    
    The timezone names should be from the [tz
    database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
    For a list of available timezones, on the Raspberry Pi run:
    `timedatectl list-timezones`
    
    This program tries to determine a default value from the local
    computer. If it is not set, the Raspberry Pi's default value is
    British Standard Time.

- `-l | --locale` locale

    Set the locale.
    
    For available locale names, look inside _/etc/locale.gen_ on the
    Raspberry Pi.
    
    This program tries to determine a default value from the local
    computer. If it is not set, the Raspberry Pi's default value is
    "en_GB.UTF-8".
    
#### Wi-Fi options

- `-c | --country` code

    Two letter ISO 3166-1 country code for setting up Wi-Fi
    frequencies.  This is mandatory if Wi-Fi is being configured.  The
    value is case-insensitive.

    This program tries to determine a default value from the locak
    computer.

- `-s | --ssid-passphrase` plaintext_passphrase

    The plaintext version of the Wi-Fi passphrase.  A WPA-PSK Wi-Fi
    passphrase must be at least 8 characters long.
    
    For better security, provide the passphrase in a file with the
    `-S` option.

- `-S | --ssid-passphrase-file` file

    Read the plaintext version of the Wi-Fi passphrase from a file.

- `-k | --psk` hex_PSK_value

    Wi-Fi passphrase and SSID hashed into the PSK, and represented in
    hexadecimal. This is the preferred way of providing the Wi-Fi
    passphrase, since it avoids storing the plaintext version in the
    configuration file. If this value is not known, provide
    the passphrase in plaintext.

- `--no-wifi`

    Do not configure the Wi-Fi. Use this option if Wi-Fi is not being
    used, and only a wired network connection will be used.

#### VNC options

- `-g | --vnc-password` vnc_password

    provided the VNC password on the command line. It must be between
    6 to 8 characters long.
    
    This program does not prompt for the VNC password, but will use
    the default value of "password" if a VNC password is not provided.

- `-G | --vnc-password-file` file

    Read the VNC password from a file.

- `--no-vnc`

    Do not attempt to configure the VNC server.

- `-r | --hdmi` resolution

    The hdmi_group and hdmi_mode that defines the resolution of the
    HDMI display.

    The resolution must be either "0" to autodetect the resolution
    (only useful if a physical monitor is connected to the HDMI port)
    or the _hdmi_group_ and _hdmi_mode_ separated by a slash.
    For example `2/35` is a resolution of 1280x1024 pixels.
    There is a list of [HDMI groups and
modes](https://www.raspberrypi.org/documentation/configuration/config-txt/video.md)
    that are supported by the Raspberry Pi.

- `--no-hdmi`

    Do not configure HDMI.

#### Other options

- `-b | --boot` mount_point

    The directory where the Raspberry Pi boot partition has been
    mounted.

    This program tries to automatically determine the boot partition,
    by looking for well-known mount points (e.g. _/Volumes/boot_ on
    macOS). Use this option if it cannot detect it or detects the
    wrong one.

#### General options

- `-q | --quiet`

    No output unless there is an error.

- `-v | --verbose`

    Output extra information when running.

- `--version`

    Output the version information and exit.

- `-h | --help`

    Output a short help message and exit.

### Arguments

- SSID

    The SSID for the Wi-Fi network. This value is case sensitive.

    Note: the configuration works with either non-hidden or hidden SSIDs.

## Examples

### Step 1: image the operating system

Image a copy of the Raspberry Pi OS onto a microSD card. If the
graphical desktop interface is needed, use the full version. If only
the command line intereface is needed, the lite version can be used.

Eject and reinsert the microSD card. That should remount its _boot_
partition, which this program will add/modify files to.

### Step 2: run the setup program

To use a Wi-Fi network, the following will prompt for the Wi-Fi/SSID
password:

```sh
./raspi-headless-setup.sh "My-WiFi-SSID-name"
```

If using a wired network connection:

```sh
./raspi-headless-setup.sh --no-wifi
```

Other options can be specified. Normally, you would want to at least
change the hostname and the password for the default account

```sh
./raspi-headless-setup.sh --hostname mypi --pi-password-file password.txt "My-WiFi-SSID-name"
```

The Raspberry Pi will then have the network address of "mypi.local".

### Step 3: boot Raspberry Pi

Eject the microSD card.  Insert it into a Raspberry Pi and turn on the
power to it.

Wait for it to boot.  This first boot will take longer than usual.
How long it takes will depend on the Raspberry Pi hardware (e.g for a
Raspberry Pi Zero W, the first boot takes 4.5 minutes and subsequent
boots take about 1 minute).

### Step 4: SSH to the Raspberry Pi

Unless they were changed, the Raspberry Pi will have the hostname of
"raspberrypi" and the default "pi" user account has "raspberry" as the
password.

Connect to it using SSH:

```sh
ssh pi@raspberrypi.local
```

Note: the Raspberry Pi should be assigned a dynamic IP address by
DHCP, and it can be contacted using the fully qualified domain name of
"raspberrypi.local", because the Raspberry Pi supports mDNS.  If the
SSH client computer does not support mDNS, the IP address that was
assigned to the Raspberry Pi will have to be discovered and used
instead. Most modern operating systems have support for mDNS.

### Step 5: use the Raspberry Pi

If the VNC server is configured, create a SSH tunnel to the Raspberry
Pi and use a VNC client over the tunnel. For security, external
connections to the VNC server are rejected.

Further configurations can be done using the graphical _Raspberry Pi
Configuration_ application, or by running `sudo raspi-config`.


## Requirements

This program runs on Unix-like environments, such as macOS and Linux
(including the Raspberry Pi OS).

It has been tested on images of the Raspberry Pi OS, Buster
(2021-05-07); both the lite version and the version with desktop.

## Troubleshooting

### Cannot resolve raspberrypi.local

Possible causes:

- The Raspberry Pi is not connected to the network:

    - It does not have hardware support for Wi-Fi;
    
    - The Wi-Fi password is incorrect;

    - The configured SSID is only available on 5 GHz Wi-Fi and the
      Raspberry Pi only has hardware support for 2.4 GHz Wi-Fi; or

    - The network cable is not plugged in.

- The client computer does not support mDNS, and therefore could not
  resolve the _.local_ network name.

- The network's DHCP server did not assign the Raspberry Pi an IP
  address.

- The hostname was changed, and is no longer "raspberrypi".

## Known issues

This program cannot disable Wi-Fi or the SSH server, if they have
previously been configured. It can only be used to enable or change
the Wi-Fi configurations; and/or to enable the SSH server.

## Files

This program creates or modifies these files on the boot partition:
_wpa_supplicant.conf_, _ssh_, _config.txt_ and _cmdline.txt_.

It also creates its own _headless_setup.sh_ script, which is executed
by the _cmdline.txt_ on boot. After successfully running, it is
deleted. That script contains the passwords and Wi-Fi passphrase, so
it should be kept confidential.

## See also

- GitHub repository for [raspi-headless-setup](https://github.com/hoylen/raspi-headless-setup).
