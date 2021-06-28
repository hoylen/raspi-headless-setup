#!/bin/bash
#
# Configure a Raspberry Pi for secure remote access over standard VNC.
#
# This script is run on the Raspberry Pi.
#
# - Runs sshd (if it is not already running).
# - Configures and runs the VNC server using vnc-password for authentication,
#   and restrict access to localhost.
# - Optionally change the hostname.
#
# Copyright (C) 2021, Hoylen Sue.
#================================================================

PROGRAM='pi-vnc-setup'
VERSION='1.0.0'

EXE=$(basename "$0" .sh)
EXE_EXT=$(basename "$0")

#----------------------------------------------------------------
# Error handling

# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# Exit immediately if a simple command exits with a non-zero status.
#   Trap ERR for better error messages than "set -e" gives (but ERR only
#   works for Bash and unlike "set -e" it doesn't propagate into functions.
#   Can't figure out which command failed? Run using "bash -x".
set -e
trap 'echo $EXE: aborted; exit 3' ERR

set -u # fail on attempts to expand undefined environment variables
set -o pipefail # prevents errors in a pipeline from being masked

#----------------------------------------------------------------
# Constants

VNCSERVER_SERVICE=vncserver-x11-serviced.service
VNC_COMMON_CUSTOM=/etc/vnc/config.d/common.custom
VNC_ROOT_X11_CONFIG=/root/.vnc/config.d/vncserver-x11
SSHD_SERVICE=sshd.service

#----------------
# Detect running context

IS_RASPBERRY_PI=
if [ -e /proc/device-tree/model ]; then
  # Note: file ends in a null: sed keeps only printable ASCII
  IS_RASPBERRY_PI=$(sed 's/[^\ \-\.0-9A-Za-z]//g' /proc/device-tree/model)
fi

VNC_INSTALLED=
# if systemctl list-units --full -all 2>/dev/null \
#     | grep -q -F "$VNCSERVER_SERVICE"; then
#   # Note: systemctl fails on systems that don't have it
#   # so redirect its errors to /ev/null
#   
#   # systemd unit is installed
#   VNC_INSTALLED=yes
# fi
VNC_INSTALLED=yes # the above test doesn't always work

if ! which vncpasswd >/dev/null; then
  # Could not find the vncpasswd program
  VNC_INSTALLED=
fi
if [ ! -d "$(dirname $VNC_COMMON_CUSTOM)" ] >/dev/null; then
  # Could not find the expected directory
  VNC_INSTALLED=
fi

#----------------------------------------------------------------
# Error handling

# Exit immediately if a simple command exits with a non-zero status.
# Better to abort than to continue running when something went wrong.
set -e

#----------------------------------------------------------------
# Command line arguments

HOSTNAME=
VNC_PASSWORD=
NO_VNC=
INSECURE_VNC=
NO_SSH=
QUIET=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

while [ $# -gt 0 ]
do
  case "$1" in
    -p|--password)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -n or --hostname missing value" >&2
        exit 2
      fi
      VNC_PASSWORD="$2"
      shift # past argument
      shift # past value
      ;;
    --no-vnc)
      NO_VNC=yes
      shift # past option
      ;;
    --insecure-vnc)
      INSECURE_VNC=yes
      shift
      ;;
    -n|--name|--hostname)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -n or --hostname missing value" >&2
        exit 2
      fi
      HOSTNAME="$2"
      shift # past argument
      shift # past value
      ;;
    --no-ssh)
      NO_SSH=yes
      shift # past option
      ;;
    -q|--quiet)
      QUIET=yes
      shift # past option
      ;;
    -v|--verbose)
      VERBOSE=yes
      shift # past option
      ;;
    --version)
      SHOW_VERSION=yes
      shift # past option
      ;;
    -h|--help)
      SHOW_HELP=yes
      shift # past option
      ;;
    -*)
      echo "$EXE: usage error: unknown option: $1" >&2
      exit 2
      ;;
    *)
      # Argument

      echo "$EXE: usage error: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

#----------------
# Help and version options

if [ -n "$SHOW_HELP" ]; then
  cat <<EOF
Usage: $EXE_EXT [options]
Options:
  -p | --password        VNC password to use instead of prompting for it
       --insecure-vnc    do not restrict access to VNC from localhost only
       --no-vnc          disable and stop VNC (default: run and enable)

  -n | --hostname NEW    change the hostname to a new name (default: no change)

       --no-ssh          disable and stop SSH server (default: run and enable)

  -q | --quiet           output nothing unless an error occurs
  -v | --verbose         output extra information when running
       --version         display version information and exit
  -h | --help            display this help and exit
EOF

  if [ -n "$IS_RASPBERRY_PI" ]; then
    # Extra status information
    
    echo
    echo "Status:"
    
    if [ "$(cat /etc/hostname)" = "$(hostname)" ]; then
      echo "    hostname: $(cat /etc/hostname)"
    else
      echo "    hostname: $(hostname) (config: \"$(cat /etc/hostname)\")"
    fi

    echo "  IP address: $(hostname -I)"

    if [ -n "$VNC_INSTALLED" ]; then
      # RealVNC service installed
      if systemctl is-active $VNCSERVER_SERVICE >/dev/null; then
        VNCSERVICE_RUN=active
      else
        VNCSERVICE_RUN=stopped
      fi
      if systemctl is-enabled $VNCSERVER_SERVICE >/dev/null; then
        VNCSERVICE_ENABLE=enabled
      else
        VNCSERVICE_ENABLE=disabled
      fi
      echo "  vncservice: $VNCSERVICE_RUN; $VNCSERVICE_ENABLE"
    else
      echo "  vncservice: not installed"
    fi

    if systemctl is-active $SSHD_SERVICE >/dev/null; then
      SSHD_RUN=active
    else
      SSHD_RUN=stopped
    fi
    if systemctl is-enabled $SSHD_SERVICE >/dev/null; then
      SSHD_ENABLE=enabled
    else
      SSHD_ENABLE=disabled
    fi
    echo "        sshd: $SSHD_RUN; $SSHD_ENABLE"

    echo "      device: $IS_RASPBERRY_PI"
  fi

  exit 0
fi

if [ -n "$SHOW_VERSION" ]; then
  echo "$PROGRAM $VERSION"
  exit 0
fi

#----------------
# Other options

if [ -n "$VNC_PASSWORD" ]; then
  # A vnc password has been provided on the command line

  if [ -n "$NO_VNC" ] ; then
    echo "$EXE: usage error: cannot use both --password and --no-vnc" >&2
    exit 2
  fi

  # Check command-line provided password length
  
  if ! echo "$VNC_PASSWORD" | grep -q -E '^.{6,8}$' ; then
    echo "$EXE: error: VNC-password must be 6 to 8 characters" >&2
    exit 2
  fi
fi

if [ -n "$VERBOSE" ] && [ -n "$QUIET" ]; then
  # Verbose overrides quiet
  QUIET=
fi

#----------------------------------------------------------------
# Check for Raspberry Pi

if [ -z "$IS_RASPBERRY_PI" ]; then
  echo "$EXE: error: not running on a Raspberry Pi" >&2
  exit 1
fi

#----------------------------------------------------------------
# Check VNC is installed before proceeding to make any changes

if [ -z "$NO_VNC" ] && [ -z "$VNC_INSTALLED" ]; then
  # VNC configuration requested, but is not available.
  # This happens on the lite version of Raspberry Pi OS.

  echo "$EXE: error: cannot configure VNC: RealVNC server not installed" >&2
  exit 1
fi

#----------------------------------------------------------------
# Check for root privileges

if [ "$(id -u)" -ne 0 ]; then
  echo "$EXE: error: root privileges required" >&2
  exit 1
fi

#----------------------------------------------------------------
# SSH

if [ -z "$NO_SSH" ]; then
  # Run SSH
  
  if ! systemctl is-active ssh.service >/dev/null ; then
    # Start
    if [ -z "$QUIET" ]; then
      echo "$EXE: sshd start"
    fi
    sudo systemctl start $SSHD_SERVICE
  else
    # Already started
    if [ -n "$VERBOSE" ]; then
      echo "$EXE: sshd already started"
    fi
  fi

  if ! systemctl is-enabled $SSHD_SERVICE >/dev/null ; then
    # Enable
    if [ -z "$QUIET" ]; then
      echo "$EXE: sshd enable"
    fi
    sudo systemctl enable $SSHD_SERVICE
  fi
else
  # No SSH

  if systemctl is-enabled $SSHD_SERVICE >/dev/null ; then
    # Disable
    if [ -z "$QUIET" ]; then
      echo "$EXE: sshd disable"
    fi
    sudo systemctl disable $SSHD_SERVICE
  fi

  if systemctl is-active $SSHD_SERVICE >/dev/null ; then
    # Stop
    if [ -z "$QUIET" ]; then
      echo "$EXE: sshd stop"
    fi
    sudo systemctl stop $SSHD_SERVICE
  else
    # Already stopped
    if [ -n "$VERBOSE" ]; then
      echo "$EXE: sshd already stopped"
    fi
  fi

fi

#----------------------------------------------------------------
# VNC

if [ -z "$NO_VNC" ]; then
  # VNC: required

  if [ -z "$VNC_PASSWORD" ] ; then
    # No password was provided on the command line: prompt for it

    until [ -n "$VNC_PASSWORD" ]; do
      if ! read -s -p "VNC password: " VNC_PASSWORD ; then
        echo
        echo "$EXE: aborted" >&2
        exit 1
      fi

      echo
      
      if ! (echo "$VNC_PASSWORD" | grep -q -E '^.{6,8}$' ); then
        echo "Error: wrong length (must be 6 to 8 characters)">&2
        VNC_PASSWORD=
      fi
    done
  fi

  # Configure vncserver to use a VNC password

  cat > $VNC_COMMON_CUSTOM <<EOF
# RealVNC common custom config
# $VNC_COMMON_CUSTOM
# Created by $PROGRAM $VERSION [$(date '+%F %T %Z')]"

# Use standard VNC password for authentication

Authentication=VncAuth
$(echo "$VNC_PASSWORD" | vncpasswd -print)

#EOF
EOF

  if [ -z "$INSECURE_VNC" ]; then
    # Secure the VNC server by only allowing connections from localhost

    # Note: editing the file under /root.vnc since that is the one the
    # graphical options will change. While the statement could be added
    # to /etc/vnc/config.d/vncserver-x11, conflicts will occur if the
    # user attempts to use the graphical options.

    if [ ! -d "$(dirname "$VNC_ROOT_X11_CONFIG")" ]; then
      echo "$EXE: error: directory not found: $VNC_ROOT_X11_CONFIG" >&2
      exit 1
    fi

    if [ ! -e "$VNC_ROOT_X11_CONFIG" ]; then
      # Create file
      touch "$VNC_ROOT_X11_CONFIG"
    fi
    if ! grep '^IpClientAddresses=' "$VNC_ROOT_X11_CONFIG" >/dev/null 2>&1; then
      # File does not contain the statement
      
      # Add the statement so sed can then set it to the desired value
      # Deny all to fail securely, if for some reason sed fails.
      echo 'IpClientAddresses=-' >> "$VNC_ROOT_X11_CONFIG"
    fi

    sed -i s/^IpClientAddresses=.*/IpClientAddresses=+127.0.0.1,+::1,-/ \
        "$VNC_ROOT_X11_CONFIG"

    if [ -z "$QUIET" ]; then
      echo "$EXE: VNC restricted to localhost only (connect via ssh tunnel)"
    fi
  else
    # Allow VNC connections from anywhere
    
    sed -i s/^IpClientAddresses=.*/IpClientAddresses=+/ \
        "$VNC_ROOT_X11_CONFIG"

    if [ -z "$QUIET" ]; then
      echo "$EXE: warning: VNC is insecurely exposed to the network"
    fi
  fi
  
  # Start/restart and enable the service
  
  if ! systemctl is-active $VNCSERVER_SERVICE >/dev/null ; then
    # Start
    if [ -z "$QUIET" ]; then
      echo "$EXE: vncserver start"
    fi
    sudo systemctl start $VNCSERVER_SERVICE

  else
    # Restart
    if [ -z "$QUIET" ]; then
      echo "$EXE: vncserver restart"
    fi
    sudo systemctl restart $VNCSERVER_SERVICE
  fi

  if ! systemctl is-enabled $VNCSERVER_SERVICE >/dev/null ; then
    # Enable
    if [ -z "$QUIET" ]; then
      echo "$EXE: vncserver enable"
    fi
    sudo systemctl enable $VNCSERVER_SERVICE
  fi

elif [ -n "$VNC_INSTALLED" ]; then
  # VNC: not required (and it has been installed)

  if systemctl is-enabled $VNCSERVER_SERVICE >/dev/null ; then
    # Disable
    if [ -z "$QUIET" ]; then
      echo "$EXE: vncserver disable"
    fi
    sudo systemctl disable $VNCSERVER_SERVICE
  fi

  if systemctl is-active $VNCSERVER_SERVICE >/dev/null ; then
    # Stop
    if [ -z "$QUIET" ]; then
      echo "$EXE: vncserver stop"
    fi
    sudo systemctl stop $VNCSERVER_SERVICE
    
  else
    # Already stopped
    if [ -n "$VERBOSE" ]; then
      echo "$EXE: vncserver already stopped"
    fi   
  fi
fi

#----------------------------------------------------------------
# Screen resolution

# This is easiest done with the text-based `raspi-config` program.

#It can be done by editing the `hdmi_mode` entry in
# _/boot/config.txt_, but that requires knowing the numeric value to set

#[hdmi_mode](https://www.raspberrypi.org/documentation/configuration/config-txt/README.md)

#----------------------------------------------------------------
# Change static IP address
# TODO: add feature to setup static IP address
# This involves editing the /etc/dhcpcd.conf file

DHCP_CONFIG=/etc/dhcpcd.conf

# Edit $DHCP_CONFIG file
#
# interface eth0
# static ip_address=10.0.0.42/24
# static ip6_address=.../64
# static routers=10.0.0.1
# static domain_name_servers=10.0.0.1 8.8.8.8

#----------------------------------------------------------------
# Change hostname

if [ -n "$HOSTNAME" ]; then
  OLD_HOSTNAME=$(cat /etc/hostname)

  # Replace hostname
  echo $HOSTNAME > /etc/hostname

  # Change its entry in the hosts file
  sed -i "s/\t$OLD_HOSTNAME\$/\t$HOSTNAME/" /etc/hosts
  
  if [ "$(hostname)" != "$HOSTNAME" ]; then
    # The new hostname is really different

    # Set the current hostname
    hostname -F /etc/hostname

    # Restart the mDNS server so it uses it
    systemctl restart avahi-daemon.service
  fi

  if [ -z "$QUIET" ]; then
    echo "$EXE: hostname changed from \"$OLD_HOSTNAME\" to \"$HOSTNAME\""
  fi
fi

# Show IP address

if [ -n "$VERBOSE" ]; then
  echo "$EXE: IP address: $(hostname -I)"
fi

#----------------------------------------------------------------
# Finished

if [ -z "$QUIET" ]; then
  if [ -z "$NO_VNC" ] ; then

    # If the desktop was not started before VNC was setup (e.g. a
    # headless setup), the LXPanel (menu bar panel) won't be running
    # and the lxpolkit won't have a correct session (the desktop will
    # display an error dialog saying "No session for pid"). This is
    # most easily fixed by rebooting.
    #
    # A reboot is not needed if the desktop was started before VNC was
    # setup (e.g. not a headless setup), a restart is not required.

    echo "$EXE: done (restart may be required)"
  else
    echo "$EXE: done"
  fi
fi

#EOF
