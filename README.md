# Raspberry Pi utilities

Utility programs for setting up a Raspberry Pi.

These utilities makes setting up a headless Raspberry Pi easier.
Remote access can be made available via the command line with SSH, or
to the graphical desktop with VNC.

## Setting up a headless Raspberry Pi

### Requirements

- A computer to create the microSD card and to be a SSH/VNC client;
- microSD card;
- Wi-Fi or wired network that has a DHCP service; and
- Raspberry Pi with power supply;

Since it will be headless, the Raspberry Pi will not need a monitor, keyboard or mouse.

### Process

#### Initial setup for network and SSH

1. Image a copy of the Raspberry Pi OS onto a microSD card.

    Use the **lite** version of Raspberry Pi OS, if the graphical
    desktop is not required. It is smaller and has less running
    processes: there is no sense running the graphical desktop if it
    will never be used.

    Use a **desktop** or **full** version of Raspberry Pi OS, if the
    graphical desktop is required.  It is possible to start with the
    lite version and then install the necessary packages to run a
    graphical desktop, but it is more work.

    Eject and reinsert the microSD card.

2. On the computer setting up the microSD card, run the
   _pi-init-setup.sh_ program. That will prepare the microSD
   card to configure the Wi-Fi network and the SSH server on the
   Raspberry Pi.

    `./pi-init-setup.sh myNetworkSSID`

    It will prompt for the SSID password, if it is not provided as a
    command line option.
    
    If using the Raspberry Pi with only a wired network connection,
    use the `--no-wifi` option to only configure the SSH server.

    Eject the microSD card and insert it into the Raspberry Pi.

3. Startup the Raspberry Pi with the microSD card.

   Wait until the Raspberry Pi finishes booting. This can take
   up to 90 seconds.

4. If VNC will be needed, copy the _pi-vnc-setup.sh_ program to the
   Raspberry Pi.

    `scp pi-vnc-setup.sh pi@raspberrypi.local:`

    The default hostname is "raspberrypi", so use the network address
    of "raspberrypi.local" to locate the Raspberry Pi. The default
    "pi" user account has the default password of "raspberry".

5. SSH to the Raspberry Pi.

    `ssh pi@raspberrypi.local`

6. Configure the Raspberry Pi. The most important configuration is to
   change the default password.

    `pi@raspberrypi:~ $ passwd`

#### Setting up VNC

The following steps are only needed if using VNC to access the
graphical desktop:

6. On the Raspberry Pi, run the _pi-vnc-setup.sh_ script to configure
   the VNC server.  Changing the default hostname of "raspberrypi" is
   optional, but recommended if there will be other Raspberry Pi
   computers on the network.

    `pi@raspberrypi:~ $ sudo ./pi-vnc-setup.sh --hostname myNewHostname`

    It will prompt for the VNC password to use, if it is not provided
    as a command line option. It must be between 6 to 8 characters
    long.  By itself, the VNC protocol is not secure, so don't worry
    too much about picking a secure password.
   
    Note: the VNC server is configured to be more secure by only allow
    connections from localhost. All VNC traffic will be sent over a
    secure VNC tunnel, instead of over the network in the clear.

7. Restart the Raspberry Pi.

     `pi@raspberrypi:~ $ sudo shutdown -r now`

8. Establish a SSH tunnel, to the VNC server running on port 5900 on
   the Raspberry Pi, from an unused port on the client machine (port
   9000 is used in the example below).

    Note: use the new hostname, if it was changed from the default
    hostname of "raspberrypi".

    `ssh -L 9000:localhost:5900 pi@myNewHostname.local`
    
9. Use a VNC client program to connect to the local port (port 9000 if
   the above example was used).  The VNC client should prompt for the
   VNC password.

#### Initial configurations

If using the graphical desktop, the "Welcome to Raspberry Pi"
application can also be used for the intial configurations.

Alternatively, various command line programs can also be used:

- Password: `passwd` to change the user account's password;

- Hostname: edit _/etc/hostname_ and _/etc/hosts_, then then run `sudo
  systemctl restart avahi-daemon.service` or restart the Raspberry Pi
  so the mDNS service uses the new value;

- Timezone: `timedatectl list-timezones` to show the available
  timezones and then run `sudo timedatectl set-timezone ...` to set
  the timezone;

- Update software: `sudo apt-get update; sudo apt-get upgrade`.

#### Other configurations

One of the Raspberry Pi configuration programs can be used for other
common configurations:

- The graphical version is under the Raspberry Pi menu > Preferences >
  Raspberry Pi Configuration.
  
- The text-based version is started by running `sudo raspi-config`
  from the command line.
  

## See also

- [GitHub repository](https://github.com/hoylen/raspberry-pi-utils)
  for raspberry-pi-utils.
