# pi-init-setup

Configure a Raspberry Pi OS imaged microSD to have Wi-Fi and SSH running.

## Synopsis

```sh
pi-init-setup.sh [options] SSID
```

## Description

This program is used to configure a Raspberry Pi to run headless.  A
headless Raspberry Pi is one that does not need a monitor, keyboard or
mouse. Interaction with it can be done over the network (either Wi-Fi
or wired). For example, using the command line over SSH, or via a
graphical session over VNC. The only wired connection to the Raspberry
Pi needed is the power. But if the Raspberry Pi model does not support
Wi-Fi, a network connection may also be required.

This program is run on the computer used to prepare a microSD card for
the Raspberry Pi. After imaging the Raspberry Pi OS onto the microSD
card, remount the microSD card and run this program.

This program can configure:

- the Wi-Fi settings; and

- force the Raspberry Pi to assume there is a HDMI display with a
  particular resolution.

The HDMI display settings will be needed if remote access to a
graphical desktop is later configured. It is not needed if the
Raspberry Pi will only be used via the command line over SSH.

### Options

#### Wi-Fi options

- `-c | --country` code

    Two letter ISO 3166-1 country code for setting up Wi-Fi
    frequencies.  This is mandatory if Wi-Fi is being configured. But
    it tries to detect the country to use as a default value. The
    value is case-insensitive.

- `-k | --psk` hex_PSK_value

    Wi-Fi password and SSID hashed into the PSK, and represented in
    hexadecimal. This is the preferred way of providing the Wi-Fi
    password, since it avoids storing the plaintext version of the
    password. If this value is not known, use the plaintext version of
    the password.

- `-p | --password` plaintext_passphrase

    The plaintext version of the Wi-Fi password. If provided using
    this option, the program will not interactively prompt for it. A
    Wi-Fi password must be at least 8 characters long.

- `--no-wifi`

    Do not configure the Wi-Fi. Use this option if a wired network
    connection will be used.

#### HDMI options

- `-r | --resolution` resolution

    The hdmi_group and hdmi_mode that defines the resolution of the
    HDMI display.

    The resolution must be either "0" to autodetect the resolution
    (only useful if a physical monitor is connected to the HDMI port)
    or the _hdmi_group_ and _hdmi_mode_ separated by a slash.
    For example `2/35` is a resolution of 1280x1024 pixels.
    There is a list of [HDMI groups and
modes](https://www.raspberrypi.org/documentation/configuration/config-txt/video.md)
    that are supported by the Raspberry Pi.


- `--no-resolution`

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

    Display the version information and exit.

- `-h | --help`

    Display a short help message and exit.

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

### Step 2: configure

#### 2a. Configuring for a Wi-Fi network

Run:

```sh
./pi-init-setup.sh "My-WiFi-SSID-name"
```

It will prompt for the SSID password. Note: both the SSID name and the
password are case-sensitive.

This will configure everything: the Wi-Fi and HDMI.

#### 2b. Configuring for a wired network

Run:

```sh
./pi-init-setup.sh --no-wifi
```

This will only configure the HDMI.

### Step 3: Boot Raspberry Pi

Eject the microSD card and insert it into a Raspberry Pi.

Turn the power to the Raspberry Pi on and wait for it to boot. This
can take up to a 90 seconds, since the first boot is usually slower
than subsequent boots.

### Step 4: SSH to the Raspberry Pi

Initially, the Raspberry Pi will have the hostname of "raspberrypi"
and the default user account called "pi" with "raspberry" as the
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

### Step 5: Continue configuring the Raspberry Pi

Immediately secure the Raspberry Pi by changing the default password.
This can be done using the `passwd` command.

Also consider changing the hostname, so there will not be any
conflicts with future Raspberry Pi setups.

#### Text mode configuration

If the Raspberry Pi will not be configured for remote graphical VNC
access, the password, hostname and other settings (such as locale and
timezone) can be easily configured using the text-based Raspberry Pi
configurator:

```sh
sudo raspi-config
```

#### Graphical mode configuration

If the Raspberry Pi will be configured for remote graphical VNC
access, the hostname _could_ be configured as a part of that process.
But the password should be _immediately_ changed if the well known
default password poses a security risk.

After VNC access is available, the "Welcome to Raspberry Pi"
application and graphical Raspberry Pi configurator can be used.

#### Manual configuration

Instead of using the Raspberry Pi configurators, the configurations
can be made using the command line.

Changing the password:

```sh
passwd
```

Changing the hostname:

```sh
# edit /etc/hostname
# edit /etc/hosts
hostname -F /etc/hostname
sudo systemctl restart avahi-daemon.service
```

Setting the timezone:

```sh
timedatectl list-timezones  # to show available names
sudo timedatectl set-timezone Australia/Brisbane
```

Update the software:

```sh
sudo apt-get update
sudo apt-get upgrade
```

## Advanced use

### Using the program multiple times

The program is designed to be used once, immediately after imaging the
microSD card and before it is first booted in a Raspberry Pi.

It can also be run multiple times before the microSD card is used to
boot a Raspberry Pi.

But if run after a Raspberry Pi has been booted with it, the results
are different:

- Any Wi-Fi settings will replace any existing Wi-Fi settings.  This
  is useful for changing the SSID and/or SSID password.
  
- Using `--no-wifi` makes no changes to any existing Wi-Fi settings
  that might have already been made.

- Using `--no-resolution` makes no changes to any existing settings
  that might have already been made.

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


## Known issues

This program cannot disable Wi-Fi or the SSH server, if they have
previously been configured. It can only be used to enable or change
the Wi-Fi configurations; and/or to enable the SSH server.

## Files

This program creates or modifies these files on the boot partition:
_wpa_supplicant.conf_, _ssh_ and _config.txt_.

## See also

- [GitHub repository](https://github.com/hoylen/raspberry-pi-utils)
  for raspberry-pi-utils.

- [Advanced options](https://www.raspberrypi.org/blog/raspberry-pi-imager-update-to-v1-6/) for the _Raspberry Pi Imager_.
