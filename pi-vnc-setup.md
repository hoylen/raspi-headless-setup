# pi-vnc-setup

Configure a Raspberry Pi for secure remote access over standard VNC.

## Synopsis

```sh
pi-vnc-setup.sh [options]
```

## Description

This program is used to configure the RealVNC server on a Raspberry Pi
for secure remote access using standard VNC.

It must be copied onto the Raspberry Pi and run on it.

### Options

#### VNC options

- `-p | --password` vnc_password

    provided the VNC password on the command line. The program does
    not prompt for the VNC password.

- `--insecure-vnc`

    Do not restrict access to VNC to localhost only.  That is, it can
    be directly accessed from other hosts on the network (as long as
    firewall rules permit it).

- `--no-vnc`

    Disable and stop the VNC server.

#### Hostname options

- `-n | --hostname` new_hostname

   Change the hostname.

#### SSH server options

- `--no-ssh`

    Disable and stop the SSH server.

#### General options

- `-q | --quiet`

    No output unless there is an error.

- `-v | --verbose`

    Output extra information when running.

- `--version`

    Display the version information and exit.

- `-h | --help`

    Display a short help message and exit.


## Examples

```sh
sudo ./pi-vnc-setup.sh --hostname newpi
```

The program will prompt for the VNC password to use. Which, in
standard VNC, must be between 6 and 8 characters.

```sh
ssh -L 5900:localhost:5900 pi@newpi.local
```

Use a standard VNC client program and connect to port 5900 (the first
number in the argument to the `-L` option) on the client machine.

## Requirements

This program runs on the Raspberry Pi OS.

It has been tested on the Raspberry Pi OS, Buster (2021-05-07), with
desktop.

## Troubleshooting

### Error "No session for pid ..."

The desktop was started after the VNC was started, so the _lxpolkit_
could not work properly. This usually occurs when VNC and the desktop
is installed onto a lite version of Raspberry Pi OS.

Restart the Raspberry Pi, so the desktop starts up before the VNC
session.

### VNC shows "Cannot currently show the desktop"

The graphical desktop is not running on the Raspberry Pi. This usually
happens when using the lite version of Raspberry Pi OS. While the
RealVNC has been installed, the desktop has not.

Install the desktop.

## See also

- [GitHub repository](https://github.com/hoylen/raspberry-pi-utils)
  for raspberry-pi-utils.
