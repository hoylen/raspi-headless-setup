#!/bin/bash
#
# Configure a Raspberry Pi OS imaged microSD to have Wi-Fi and SSH running.
#
# This script is run on the computer used to setup the microSD card.
# Run it after imaging the Raspberry Pi OS onto it and before it is
# inserted into the Raspberry Pi.
#
# Copyright (C) 2021, Hoylen Sue.
#================================================================

PROGRAM='pi-init-setup'
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

#----------------
# Default HDMI display resolution

DEFAULT_RESOLUTION='2/35' # 1280x1024

#----------------
# Default country (empty string means it must be provided on the command line)
# Can be changed on the command line with the --country option.

# Try to detect from LANG environment variable
DEFAULT_COUNTRY=
if echo $LANG | grep -q '^[a-z][a-z]_[A-Z][A-Z]\.' ; then
  # en_AU.UTF-8 -> AU
  DEFAULT_COUNTRY=$(echo $LANG | sed 's/^[a-z][a-z]_\(..\)\..*/\1/')
fi

# If the above does not work, and you are tired of always specifying the
# country as a command line option, hard code the default value.

# DEFAULT_COUNTRY=AQ

#----------------------------------------------------------------
# Constants

# hdmi_mode limits from:
# https://www.raspberrypi.org/documentation/configuration/config-txt/video.md

HDMI_MODE_MAX1=107
HDMI_MODE_MAX2=86

#----------------------------------------------------------------
# Error handling

# Exit immediately if a simple command exits with a non-zero status.
# Better to abort than to continue running when something went wrong.
set -e

#----------------------------------------------------------------
# Command line arguments

WIFI_COUNTRY=$DEFAULT_COUNTRY
WIFI_SSID=
WIFI_PASSWORD_PLAINTEXT=
WIFI_PASSWORD_PSK=
NO_WIFI=
RESOLUTION=$DEFAULT_RESOLUTION
BOOT_DIR=
QUIET=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

while [ $# -gt 0 ]
do
  case "$1" in
    -c|--country)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -c or --country missing value" >&2
        exit 2
      fi
      WIFI_COUNTRY="$2"
      shift # past option
      shift # past argument
      ;;
    -p|--password)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -p or --password missing value" >&2
        exit 2
      fi
      WIFI_PASSWORD_PLAINTEXT="$2"
      shift # past option
      shift # past argument
      ;;
    -k|--psk)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -k or --psk missing value" >&2
        exit 2
      fi
      WIFI_PASSWORD_PSK="$2"
      shift # past option
      shift # past argument
      ;;
    --no-wifi)
      NO_WIFI=yes
      shift # past option
      ;;
    -r|--res|--resolution)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -r or --res missing value" >&2
        exit 2
      fi
      RESOLUTION="$2"
      shift # past option
      shift # past argument
      ;;
    --no-resolution)
      RESOLUTION=
      shift # past option
      ;;
    -b|--boot)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: -b or --boot missing value" >&2
        exit 2
      fi
      BOOT_DIR="$2"
      shift # past option
      shift # past argument
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
    *)
      # unknown option
      if echo "$1" | grep -q ^- ; then
        echo "$EXE: usage error: unknown option: \"$1\"" >&2
        exit 2
      else
        # Use as the SSID

        if [ -n "$WIFI_SSID" ]; then
          echo "$EXE: usage error: too many arguments" >&2
          exit 2
        fi
        WIFI_SSID="$1"
      fi
      shift # past argument
      ;;
  esac
done

#----------------
# Help and version options

if [ -n "$SHOW_HELP" ]; then
  if [ -n "$DEFAULT_COUNTRY" ]; then
    CTRY=" (default: $DEFAULT_COUNTRY)"
  else
    CTRY=
  fi
  
  cat <<EOF
Usage: $EXE_EXT [options] SSID-case-sensitive
Options:
  -c | --country XX      two letter ISO 3166-1 country code$CTRY
  -k | --psk HEXVALUE    Wi-Fi password and SSID encoded as PSK in hexadecimal
  -p | --password VALUE  Wi-Fi password in plaintext instead of prompting for it
       --no-wifi         do not configure Wi-Fi (default: configure it)

  -r | --resolution RES  set hdmi_group and hdmi_mode (default: $DEFAULT_RESOLUTION)
       --no-resolution   do not configure HDMI (default: configure it)

  -b | --boot DIR        mounted location of the Raspberry Pi boot partition

  -q | --quiet           output nothing unless an error occurs
  -v | --verbose         output extra information when running
       --version         display version information and exit
  -h | --help            display this help and exit

HDMI resolutions are "hdmi_group/hdmi_mode" (with "0" for auto-detect):
  e.g. 1/4=720p, 1/16=1080p, 2/16=1024x768, 2/35=1280x1024, 2/51=1600x1200
  https://www.raspberrypi.org/documentation/configuration/config-txt/video.md
EOF
  exit 0
fi

if [ -n "$SHOW_VERSION" ]; then
  echo "$PROGRAM $VERSION"
  exit 0
fi

#----------------
# Other options

if [ -z "$WIFI_SSID" ]; then
  echo "$EXE: usage error: missing SSID (-h for help)" >&2
  exit 2
fi

if [ -z "$NO_WIFI" ]; then
  # Setup Wi-Fi
  
  if [ -z "$WIFI_COUNTRY" ]; then
    echo "$EXE: usage error: missing Wi-Fi country code" >&2
    exit 2
  fi
  WIFI_COUNTRY=$(echo $WIFI_COUNTRY | tr a-z A-Z) # uppercase
  if ! echo "$WIFI_COUNTRY" | grep -q '^[A-Z][A-Z]$' ; then
    echo "$EXE: usage error: bad two-letter country code: \"$WIFI_COUNTRY\"">&2
    exit 2
  fi

else
  if [ -n "$WIFI_PASSWORD_PLAINTEXT" ] || [ -n "$WIFI_PASSWORD_PSK" ] ; then
    echo "$EXE: usage error: passwords are not needed with --no-wifi">&2
    exit 2
  fi
fi

HDMI_FORCE_HOTPLUG=
HDMI_GROUP=
HDMI_MODE=

if [ "$RESOLUTION" = '0' ]; then
  # Group 0: auto-detect from EDID (no hdmi_mode)
  HDMI_FORCE_HOTPLUG=
  HDMI_GROUP=0
  HDMI_MODE=

elif [ -n "$RESOLUTION" ]; then
  if ! echo "$RESOLUTION" | grep -q '^[1-9][0-9]*/[1-9][0-9]*$' ; then
    echo "$EXE: usage error: resolution is not \"GROUP/MODE\": $RESOLUTION" >&2
    exit 2
  fi

  HDMI_FORCE_HOTPLUG=1
  HDMI_GROUP=$(echo $RESOLUTION | sed 's/\/.*$//')
  HDMI_MODE=$(echo $RESOLUTION | sed 's/^.*\///')
  
  if [ $HDMI_GROUP -eq 1 ]; then
    # Group: Consumer Electronics Association (CEA) i.e. televisions

    if [ $HDMI_MODE_MAX1 -lt $HDMI_MODE ]; then
      echo "$EXE: usage error: hdmi_mode exceeds maximum of $HDMI_MODE_MAX1: $RESOLUTION" >&2
      exit 2
    fi

  elif [ $HDMI_GROUP -eq 2 ]; then
    # Group 2: Display Monitor Timings (DMT)
    
    if [ $HDMI_MODE_MAX2 -lt $HDMI_MODE ]; then
      echo "$EXE: usage error: hdmi_mode exceeds maximum of $HDMI_MODE_MAX2: $RESOLUTION" >&2
      exit 2
    fi
  else
    echo "$EXE: usage error: unknown HDMI group (expect 1 or 2): $RESOLUTION" >&2
    exit 2
  fi
fi

if [ -n "$VERBOSE" ] && [ -n "$QUIET" ]; then
  # Verbose overrides quiet
  QUIET=
fi

#----------------------------------------------------------------
# Check for Raspberry Pi microSD card

_has_raspberry_pi_os_files () {
  DIR=$1

  for F in config.txt start.elf bootcode.bin LICENCE.broadcom cmdline.txt; do
    if [ ! -f "$DIR/$F" ] ; then
      return 1 # failed
    fi
  done

  return 0 # passed
}

if [ -z "$BOOT_DIR" ]; then
  # No boot location provided, try and automatically find it

  # Trying these candidate places:
  # - macOS: /Volumes/boot
  # - Raspberry Pi OS: /media/pi/boot
  # - Others?
  #
  # Note: on a running Raspberry Pi, /boot is the boot partition. But
  # this script should not need to update it, since in a running
  # Raspberry Pi there are more direct ways to configure Wi-Fi and the
  # SSH server. If you really want to use this script on the currently
  # running Raspberry Pi's boot partition, use "--boot /boot" to
  # explicity choose it.
  
  for CANDIDATE in /Volumes/boot /media/pi/boot ; do
    if [ -d "$CANDIDATE" ] ; then
      # Directory exists
      # Check some contents are expected for a Raspberry Pi image

      if _has_raspberry_pi_os_files "$CANDIDATE" ; then
        BOOT_DIR="$CANDIDATE"
        break
      fi
    fi
  done

  if [ -z "$BOOT_DIR" ]; then
    echo "$EXE: error: mounted Raspberry Pi boot partition not found (use --boot)" >&2
    exit 1
  fi

else
  # Boot location provided: it must contain a real Raspberry Pi boot partition
  if ! _has_raspberry_pi_os_files "$BOOT_DIR"; then
    echo "$EXE: error: not a Raspberry Pi image: missing files: $BOOT_DIR">&2
    exit 1
  fi
fi

if [ -n "$VERBOSE" ]; then
  echo "$EXE: Raspberry Pi OS boot partition: $BOOT_DIR"
fi

# Check if first boot has already happened or not

ALREADY_BOOTED=
if ! grep -q 'init_resize.sh' "$BOOT_DIR/cmdline.txt" ; then
  ALREADY_BOOTED=yes
fi

#----------------------------------------------------------------
# Constants: files on boot partition to be configured

WIFI_CONF=$BOOT_DIR/wpa_supplicant.conf
CONFIG_FILE=$BOOT_DIR/config.txt
SSH_FILE=$BOOT_DIR/ssh

#----------------------------------------------------------------
# Check permission

if [ ! -w "$BOOT_DIR" ]; then
  echo "$EXE: error: insufficient privileges to write to $BOOT_DIR" >&2
  exit 1
fi

if [ ! -w "$CONFIG_FILE" ]; then
  echo "$EXE: error: insufficient privileges to write to $CONFIG_FILE" >&2
  exit 1
fi

#----------------------------------------------------------------
# Configure Wi-Fi

if [ -z "$NO_WIFI" ]; then

  #----------------
  # Get password
  
  if [ -n "$WIFI_PASSWORD_PLAINTEXT" ]; then
    # Plaintext password provided
    
    if [ -n "$WIFI_PASSWORD_PSK" ]; then
      echo "$EXE: usage error: do not use both --password and --psk" >&2
      exit 2
    fi
  else
    if [ -n "$WIFI_PASSWORD_PSK" ]; then
      # PSK password provided

      # Check value is hexadecimal
      if ! echo "$WIFI_PASSWORD_PSK" |  grep -q -E '^[0-9A-Fa-f]{66}$'; then
        echo "$EXE: usage error: --psk value must be 64 hexadecimal chars" >&2
        exit 2
      fi
    else
      # No password provided on command line
      
      # Prompt for the plaintext Wi-Fi password
      
      until [ -n "$WIFI_PASSWORD_PLAINTEXT" ];
      do
        # Note: -s works in Bash and Zsh, but not in all shells
        if ! read -s -p "Wi-Fi password for \"$WIFI_SSID\": " \
             WIFI_PASSWORD_PLAINTEXT ; then
          echo
          echo "$EXE: aborted" >&2
          exit 1
        fi

        echo

        if ! (echo "$WIFI_PASSWORD_PLAINTEXT" | grep -q -E ^.{8}); then
          echo "Error: wrong length (must be 8 characters or longer)">&2
          WIFI_PASSWORD_PLAINTEXT=
        fi
      done
    fi
  fi

  #----------------
  # Configure Wi-Fi
  
  # https://www.raspberrypi.org/documentation/configuration/wireless/headless.md
  # https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md
  # https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf

  if [ -n "$WIFI_PASSWORD_PSK" ]; then
    # PSK provided

    # Store the PSK (value NOT in quotes means PSK in hexadecimal)
    PSK_ENTRY="psk=$WIFI_PASSWORD_PSK"
  else
    # Plaintext passphrase provided

    if which wpa_passphrase >/dev/null 2>&1; then
      # wpa_password program available: use it to hash the SSID and passphrase
      # wpa_password is installed on the Raspberry Pi OS

      # Store the PSK (value NOT in quotes means PSK in hexadecimal)
      PSK_ENTRY=$(wpa_passphrase "$WIFI_SSID" "$WIFI_PASSWORD_PLAINTEXT" \
                    | sed 's/^[\t ]*psk=/psk=/' \
                    | grep -E '^psk=[0-9A-Fa-f]{64}')
    else
      # Store passphrase as plaintext (value in double quotes means plaintext)
      PSK_ENTRY="psk=\"$WIFI_PASSWORD_PLAINTEXT\"" # value in quotes

      # TODO: find a way to calculate the PSK without using wpa_passphrase
      # http://jorisvr.nl/wpapsk.html
      # PSK = pbkdf2_hmac_sha1(password_, salt_ssid, iter=4096, key_len=256)
    fi
  fi

  cat > "$WIFI_CONF" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$WIFI_COUNTRY

network={
  scan_ssid=1
  ssid="$WIFI_SSID"
  $PSK_ENTRY
}
EOF

  if [ -z "$QUIET" ]; then
    echo "$EXE: created: $WIFI_CONF" >&2
  fi

  if [ -n "$VERBOSE" ]; then
    cat "$WIFI_CONF"
  fi

else
  # No Wi-Fi

  if [ -e "$WIFI_CONF" ]; then
    rm  "$WIFI_CONF"
    if [ -z "$QUIET" ]; then
      echo "$EXE: deleted: $WIFI_CONF" >&2
    fi
  fi

  if [ -n "$ALREADY_BOOTED" ]; then
    # The Raspberry Pi has already been booted, so if the Wi-Fi is
    # already set up, the absence of the "wpa_supplicant.conf" file will not
    # disable it.
    echo "$EXE: warning: already booted: Wi-Fi might have been configured" >&2
  fi
fi

#----------------------------------------------------------------
# HDMI_MODE

_set_config () {
  ITEM=$1
  VALUE=$2

  # Use temporary file instead of "sed -i" since the -i option
  # is not portable between BSD and GNU versions of sed.
  
  TMP="/tmp/${PROGRAM}-$$.tmp"
  
  # Revert statement to original commented form, if it has been uncommented
  sed "s/^[ \t]*$ITEM=.*/#$ITEM=/" $CONFIG_FILE > $TMP
  
  if [ -n "$VALUE" ]; then
    # Change commented statement to desired value
    sed "s/^[ \t]*#$ITEM=.*/$ITEM=$VALUE/" $TMP > $CONFIG_FILE
  else
    cp $TMP $CONFIG_FILE
  fi

  rm $TMP
}

#----------------

if [ -n "$HDMI_GROUP" ]; then
  # Configure HDMI

  _set_config hdmi_force_hotplug "$HDMI_FORCE_HOTPLUG"
  _set_config hdmi_group "$HDMI_GROUP"
  _set_config hdmi_mode "$HDMI_MODE"

  if [ -z "$QUIET" ]; then
    echo "$EXE: configuring HDMI to $HDMI_GROUP/$HDMI_MODE: $CONFIG_FILE" >&2
  fi
fi

#----------------------------------------------------------------
# SSH

touch $SSH_FILE

if [ -z "$QUIET" ]; then
  echo "$EXE: created: $SSH_FILE" >&2
fi

#----------------------------------------------------------------
# Finished

if [ -z "$QUIET" ]; then
  echo "$EXE: done"
fi

#EOF
