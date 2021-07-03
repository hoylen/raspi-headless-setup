#!/bin/bash
#
# Configure a Raspberry Pi OS imaged microSD for use in a headless setup.
#
# - Wi-Fi network (optional)
# - SSH server
# - User account "pi" password
# - User account "pi" SSH public key for logging (optional)
# - hostname
# - timezone
# - VNC server (optional)
#
# This script is run on the computer used to setup the microSD card.
# Run it after imaging the Raspberry Pi OS onto it and before it is
# inserted into the Raspberry Pi.
#
# Copyright (C) 2021, Hoylen Sue.
#================================================================

PROGRAM='raspi-headless-setup'
VERSION='1.1.0'

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

DEFAULT_HDMI='2/35' # 1280x1024

#----------------
# Default country (empty string means it must be provided on the command line)
# Can be changed on the command line with the --country option.

# Try to detect country from LANG environment variable
DEFAULT_COUNTRY=
if echo $LANG | grep -q '^[a-z][a-z]_[A-Z][A-Z]\.' ; then
  # en_AU.UTF-8 -> AU
  DEFAULT_COUNTRY=$(echo $LANG | sed 's/^[a-z][a-z]_\(..\)\..*/\1/')
  HELP_CTRY=" (default: $DEFAULT_COUNTRY)"
else
  HELP_CTRY=
fi

# If the above does not work, and you are tired of always specifying the
# country as a command line option, hard code the default value.

# DEFAULT_COUNTRY=AQ

#----------------
# Default hostname: default value for the Raspberry Pi OS

DEFAULT_HOSTNAME=raspberrypi

# Default timezone

if [ -L /etc/localtime ]; then
  # Could be under /var/db/timezone/zoneinfo or /usr/share/zoneinfo
  # Extract the last to components of the path
  A=$(readlink /etc/localtime)
  B=$(basename "$A")
  C=$(basename "$(dirname "$A")")
  DEFAULT_TIMEZONE="$C/$B"
  HELP_DTZ=" (default: $DEFAULT_TIMEZONE)"
else
  DEFAULT_TIMEZONE=
  HELP_DTZ=
fi

# Default locale

DEFAULT_LOCALE="$LANG"
if [ -n "$DEFAULT_LOCALE" ]; then
  HELP_LOC=" (default: $DEFAULT_LOCALE)"
else
  HELP_LOC=
fi

# Default password for the "pi" user: default value for the Raspberry Pi OS

DEFAULT_PI_PASSWORD=raspberry

CANDIDATE_PUBKEY="$HOME/.ssh/id_rsa.pub"
if [ -r "$CANDIDATE_PUBKEY" ]; then
  DEFAULT_PI_PUBKEY="$CANDIDATE_PUBKEY"
fi

# Since VNC is not a secure protocol, the VNC password is not to be
# depended upon for security. Especially, when it must be only 6 to 8
# characters long.

DEFAULT_VNC_PASSWORD=password

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

PI_PASSWORD=
PI_PASSWORD_FILE=
PI_SSH_PUBKEY="$DEFAULT_PI_PUBKEY"

HOSTNAME="$DEFAULT_HOSTNAME"

TIMEZONE=$DEFAULT_TIMEZONE
LOCALE=$DEFAULT_LOCALE

WIFI_COUNTRY=$DEFAULT_COUNTRY
WIFI_SSID=
WIFI_PASSPHRASE_PSK=
WIFI_PASSPHRASE_FILE=
WIFI_PASSPHRASE_TEXT=
NO_WIFI=

VNC_PASSWORD=
VNC_PASSWORD_FILE=
NO_VNC=

HDMI_RES=$DEFAULT_HDMI

BOOT_DIR=
QUIET=
VERBOSE=
SHOW_VERSION=
SHOW_HELP=

NO_CMDLINE_UPDATE=

while [ $# -gt 0 ]
do
  case "$1" in
    -p|--pi-password)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if [ -z "$2" ]; then
        echo "$EXE: error: pi user password cannot be an empty string" >&2
        exit 2
      fi
      PI_PASSWORD="$2"
      shift # past option
      shift # past argument
      ;;
    -P|--pi-password-file)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      PI_PASSWORD_FILE="$2"
      shift # past option
      shift # past argument
      ;;
    -k|--pi-pubkey)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      PI_SSH_PUBKEY="$2"
      shift # past option
      shift # past argument
      ;;
    --no-pubkey)
      PI_SSH_PUBKEY=
      shift
      ;;
    -n|--hostname)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if [ -z "$2" ]; then
        echo "$EXE: error: hostname cannot be an empty string" >&2
        exit 2
      fi
      HOSTNAME="$2"
      shift # past option
      shift # past argument
      ;;
    -t|--timezone)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if ! echo "$2" | grep -qE '^[0-9A-Za-z_-]+\/[0-9A-Za-z_-]+$' ; then
        echo "$EXE: error: invalid timezone (expecting name/name): $2" >&2
        exit 2
      fi
      TIMEZONE="$2"
      shift # past option
      shift # past argument
      ;;
    -l|--locale)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if [ -z "$2" ]; then
        echo "$EXE: error: locale cannot be an empty string" >&2
        exit 2
      fi
      LOCALE="$2"
      shift # past option
      shift # past argument
      ;;
    -c|--country)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      WIFI_COUNTRY="$2"
      shift # past option
      shift # past argument
      ;;
    -s|--ssid-passphrase|--ssid)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if [ -z "$2" ]; then
        echo "$EXE: error: Wi-Fi passphrase cannot be an empty string" >&2
        exit 2
      fi
      WIFI_PASSPHRASE_TEXT="$2"
      shift # past option
      shift # past argument
      ;;
    -S|--ssid-passphrase-file)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      WIFI_PASSPHRASE_FILE="$2"
      shift # past option
      shift # past argument
      ;;
      
    -d|--psk)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      WIFI_PASSPHRASE_PSK="$2"
      shift # past option
      shift # past argument
      ;;
    --no-wifi)
      NO_WIFI=yes
      shift # past option
      ;;
    -g|--vnc-password)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      if [ -z "$2" ]; then
        echo "$EXE: error: VNC password cannot be an empty string" >&2
        exit 2
      fi
      VNC_PASSWORD="$2"
      shift # past option
      shift # past argument
      ;;
    -G|--vnc-password-file)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      VNC_PASSWORD_FILE="$2"
      shift # past option
      shift # past argument
      ;;
    --no-vnc)
      NO_VNC=yes
      shift # past option
      ;;
    -r|--hdmi)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
        exit 2
      fi
      HDMI_RES="$2"
      shift # past option
      shift # past argument
      ;;
    --no-hdmi)
      HDMI_RES=
      shift # past option
      ;;
    -b|--boot)
      if [ $# -lt 2 ]; then
        echo "$EXE: usage error: \"$1\" missing value" >&2
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

  cat <<EOF
Usage: $EXE_EXT [options] SSID-case-sensitive
Options:
  -p | --pi-password SECRET      pi user account password (default: $DEFAULT_PI_PASSWORD)
  -P | --pi-password-file FILE   read pi user account password from a file

       --no-pubkey               do not configure .ssh/authorized_keys
  -k | --pi-pubkey FILE          configure .ssh/authorized_keys for pi user
EOF

  if [ -n "$DEFAULT_PI_PUBKEY" ]; then
    echo "                                 (default: $DEFAULT_PI_PUBKEY)"
  fi
  
  cat <<EOF

  -n | --hostname NAME           Pi's hostname (default: $DEFAULT_HOSTNAME)

  -t | --timezone TZ             set timezone$HELP_DTZ
  -l | --locale LOCALE           set locale$HELP_LOC

  -c | --country XX              two letter ISO 3166-1 country$HELP_CTRY
  -s | --ssid-passphrase SECRET  Wi-Fi plaintext passphrase
  -S | --ssid-passphrase-file F  read Wi-Fi passphrase from a file
  -d | --psk HEXVALUE            Wi-Fi passphrase and SSID as hexadecimal PSK
       --no-wifi                 do not configure Wi-Fi

  -g | --vnc-password SECRET     VNC password; 6-8 chars (default: $DEFAULT_VNC_PASSWORD)
  -G | --vnc-password-file FILE  read VNC password from a file
       --no-vnc                  do not attempt to configure VNC server

  -r | --hdmi RESOLUTION         hdmi_group and hdmi_mode (default: $DEFAULT_HDMI)
       --no-hdmi                 do not configure HDMI

  -b | --boot MOUNT_DIR          location of the Raspberry Pi boot partition

  -q | --quiet                   output nothing unless an error occurs
  -v | --verbose                 output extra information when running
       --version                 output version information and exit
  -h | --help                    output this help and exit

HDMI resolutions: "0" to auto-detect, or "hdmi_group/hdmi_mode":
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

# Pi user password

if [ -n "$PI_PASSWORD_FILE" ]; then
  # pi user account password: read from a file

  if [ -n "$PI_PASSWORD" ] ; then
    echo "$EXE: usage error: multiple pi user passwords provided" >&2
    exit 2
  fi
  if [ ! -r  "$PI_PASSWORD_FILE" ]; then
    echo "$EXE: error: cannot read pi user password: $PI_PASSWORD_FILE" >&2
    exit 2
  fi

  PI_PASSWORD=$(head -1 "$PI_PASSWORD_FILE") # only use the first line
  if [ -z "$PI_PASSWORD" ]; then
    echo "$EXE: error: no pi user password in file: $PI_PASSWORD_FILE" >&2
    exit 2
  fi

elif [ -z "$PI_PASSWORD" ]; then
  # pi user account password: Use default
  PI_PASSWORD=$DEFAULT_PI_PASSWORD
fi
# At this point PI_PASSWORD will always have a value

# Pi user public key

if [ -n "$PI_SSH_PUBKEY" ] && [ ! -r "$PI_SSH_PUBKEY" ]; then
  echo "$EXE: usage error: SSH public key file not found: $PI_SSH_PUBKEY" >&2
  exit 2
fi

# Hostname

if ! echo $HOSTNAME | grep -qE '^[A-Za-z]' ; then
  echo "$EXE: usage error: hostname must start with a letter: $HOSTNAME" >&2
  exit 2
fi
if echo $HOSTNAME | grep -qE '.-$' ; then
  echo "$EXE: usage error: hostname cannot end with a hyphen: $HOSTNAME" >&2
  exit 2
fi
if ! echo $HOSTNAME | grep -qE '^[0-9A-Za-z-]*$' ; then
  echo "$EXE: usage error: hostname has unexpected characters: $HOSTNAME" >&2
  exit 2
fi
if ! echo $HOSTNAME | grep -qE '^.{1,63}$' ; then
  echo "$EXE: usage error: hostname too long: $HOSTNAME" >&2
  exit 2
fi

# Wi-Fi network

if [ -z "$NO_WIFI" ]; then
  # Wi-Fi will be configured

  if [ -z "$WIFI_SSID" ]; then
    echo "$EXE: usage error: missing Wi-Fi SSID (-h for help)" >&2
    exit 2
  fi

  if [ -z "$WIFI_COUNTRY" ]; then
    echo "$EXE: usage error: missing Wi-Fi country code" >&2
    exit 2
  fi
  WIFI_COUNTRY=$(echo $WIFI_COUNTRY | tr a-z A-Z) # uppercase for consistency
  if ! echo "$WIFI_COUNTRY" | grep -q '^[A-Z][A-Z]$' ; then
    echo "$EXE: usage error: bad two-letter country code: \"$WIFI_COUNTRY\"">&2
    exit 2
  fi

  if [ -n "$WIFI_PASSPHRASE_PSK" ]; then
    # Expect PSK is the only one: use it
    
    if [ -n "$WIFI_PASSPHRASE_FILE" ] || [ -n "$WIFI_PASSPHRASE" ] ; then
      echo "$EXE: usage error: multiple Wi-Fi passwords provided" >&2
      exit 2
    fi
    # Check PSK value is exactly 64 hexadecimal characters
    if ! echo "$WIFI_PASSPHRASE_PSK" |  grep -q -E '^[0-9A-Fa-f]{64}$'; then
      echo "$EXE: usage error: --psk value must be 64 hexadecimal chars" >&2
      exit 2
    fi

  elif [ -n "$WIFI_PASSPHRASE_FILE" ]; then
    # Expect password file is the only one: load it
    
    if [ -n "$WIFI_PASSPHRASE_TEXT" ]; then
      echo "$EXE: usage error: multiple Wi-Fi passwords provided" >&2
      exit 2
    fi
    if [ ! -r "$WIFI_PASSPHRASE_FILE" ]; then
      echo "$EXE: error: cannot read password file: $PI_PASSWORD_FILE" >&2
      exit 2
    fi

    WIFI_PASSPHRASE_TEXT=$(head -1 "$WIFI_PASSPHRASE_FILE")
    # It can be an empty string? If so, the following test is not required
    # if [ -z "$WIFI_PASSPHRASE_TEXT" ]; then
    #   echo "$EXE: error: no passphrase in file: $WIFI_PASSPHRASE_FILE" >&2
    #   exit 2
    # fi
  fi
  # At this point, **at most one** of WIFI_PASSPHRASE_TEXT or
  # WIFI_PASSPHRASE_PSK will have a value: never both, but possibly
  # neither. If neither, this script will later prompt for the
  # plaintext passphrase.
  
else
  # Wi-Fi will not be configured
  
  if [ -n "$WIFI_PASSPHRASE_TEXT" ] \
       || [ -n "$WIFI_PASSPHRASE_FILE" ] \
       || [ -n "$WIFI_PASSPHRASE_PSK" ] ; then
    echo "$EXE: usage error: Wi-Fi passwords not needed with --no-wifi">&2
    exit 2
  fi
fi

# VNC password options

if [ -z "$NO_VNC" ]; then
  if [ -n "$VNC_PASSWORD_FILE" ]; then
    # Password from file: read it
  
    if [ -n "$VNC_PASSWORD" ] ; then
      echo "$EXE: usage error: multiple VNC passwords provided" >&2
      exit 2
    fi
    if [ ! -r "$VNC_PASSWORD_FILE" ]; then
      echo "$EXE: error: cannot read VNC password file: $VNC_PASSWORD_FILE" >&2
      exit 2
    fi

    VNC_PASSWORD=$(head -1 "$VNC_PASSWORD_FILE")
    if [ -z "$VNC_PASSWORD" ]; then
      echo "$EXE: error: no VNC password in file: $VNC_PASSWORD_FILE" >&2
      exit 2
    fi
    
  elif [ -n "$VNC_PASSWORD" ]; then
    # Password from command line: use it

    if [ -z "$VNC_PASSWORD" ]; then
      echo "$EXE: error: VNC password cannot be an empty string" >&2
      exit 2
    fi

  else
    # Use default VNC password
    VNC_PASSWORD=$DEFAULT_VNC_PASSWORD
  fi
  # At this point VNC_PASSWORD will always have a value.
  
else
  if [ -n "$VNC_PASSWORD" ] ||  [ -n "$VNC_PASSWORD_FILE" ] ; then
    echo "$EXE: usage error: VNC password provided when using --no-vnc" >&2
    exit 2
  fi
fi

# Parse the HDMI options

HDMI_FORCE_HOTPLUG=
HDMI_GROUP=
HDMI_MODE=

if [ "$HDMI_RES" = '0' ]; then
  # Group 0: auto-detect from EDID (no hdmi_mode)
  HDMI_FORCE_HOTPLUG=
  HDMI_GROUP=0
  HDMI_MODE=

elif [ -n "$HDMI_RES" ]; then
  if ! echo "$HDMI_RES" | grep -q '^[1-9][0-9]*/[1-9][0-9]*$' ; then
    echo "$EXE: usage error: resolution is not \"GROUP/MODE\": $HDMI_RES" >&2
    exit 2
  fi

  HDMI_FORCE_HOTPLUG=1
  HDMI_GROUP=$(echo $HDMI_RES | sed 's/\/.*$//')
  HDMI_MODE=$(echo $HDMI_RES | sed 's/^.*\///')

  if [ $HDMI_GROUP -eq 1 ]; then
    # Group: Consumer Electronics Association (CEA) i.e. televisions

    if [ $HDMI_MODE_MAX1 -lt $HDMI_MODE ]; then
      echo "$EXE: usage error: hdmi_mode exceeds maximum of $HDMI_MODE_MAX1: $HDMI_RES" >&2
      exit 2
    fi

  elif [ $HDMI_GROUP -eq 2 ]; then
    # Group 2: Display Monitor Timings (DMT)

    if [ $HDMI_MODE_MAX2 -lt $HDMI_MODE ]; then
      echo "$EXE: usage error: hdmi_mode exceeds maximum of $HDMI_MODE_MAX2: $HDMI_RES" >&2
      exit 2
    fi
  else
    echo "$EXE: usage error: unknown HDMI group (expect 1 or 2): $HDMI_RES" >&2
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

  for F in cmdline.txt config.txt LICENCE.broadcom start.elf bootcode.bin; do
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
    echo "$EXE: error: Raspberry Pi boot partition not found (use --boot)" >&2
    exit 1
  fi

else
  # Boot location provided: it must contain a real Raspberry Pi boot partition
  if ! _has_raspberry_pi_os_files "$BOOT_DIR"; then
    echo "$EXE: error: not a Raspberry Pi image: missing files: $BOOT_DIR">&2
    exit 1
  fi
fi

# Check if first boot has already happened or not

ALREADY_BOOTED=
if ! grep -q 'init_resize.sh' "$BOOT_DIR/cmdline.txt" ; then
  ALREADY_BOOTED=yes
fi

#----------------------------------------------------------------
# Constants: files on boot partition to be configured

WIFI_CONF="$BOOT_DIR/wpa_supplicant.conf"
CONFIG_FILE="$BOOT_DIR/config.txt"
SSH_FILE="$BOOT_DIR/ssh"

INIT_NAME="headless_init.sh"
INIT_FILE="$BOOT_DIR/$INIT_NAME"

CMD_FILE="$BOOT_DIR/cmdline.txt"

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

  if [ -n "$WIFI_PASSPHRASE_TEXT" ] && [ -n "$WIFI_PASSPHRASE_PSK" ]; then
    # Prompt for the plaintext Wi-Fi password

    until [ -n "$WIFI_PASSPHRASE_TEXT" ];
    do
      # Note: -s works in Bash and Zsh, but not in all shells
      if ! read -s -p "Wi-Fi password for \"$WIFI_SSID\": " \
           WIFI_PASSPHRASE_TEXT ; then
        echo
        echo "$EXE: aborted" >&2
        exit 1
      fi

      echo

      if ! (echo "$WIFI_PASSPHRASE_TEXT" | grep -q -E ^.{8}); then
        echo "Error: wrong length (must be 8 characters or longer)">&2
        WIFI_PASSPHRASE_TEXT=
      fi
    done
  fi

  #----------------
  # Configure Wi-Fi

  # https://www.raspberrypi.org/documentation/configuration/wireless/headless.md
  # https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md
  # https://w1.fi/cgit/hostap/plain/wpa_supplicant/wpa_supplicant.conf

  if [ -n "$WIFI_PASSPHRASE_PSK" ]; then
    # PSK provided

    # Store the PSK (value NOT in quotes means PSK in hexadecimal)
    PSK_ENTRY="psk=$WIFI_PASSPHRASE_PSK"

  elif which wpa_passphrase >/dev/null 2>&1; then
    # Plaintext passphrase provided, but wpa_password program is available
    # to hash the SSID and passphrase into a PSK

    # Store the PSK (value NOT in quotes means PSK in hexadecimal)
    PSK_ENTRY=$(wpa_passphrase "$WIFI_SSID" "$WIFI_PASSPHRASE_TEXT" \
                  | sed 's/^[\t ]*psk=/psk=/' \
                  | grep -E '^psk=[0-9A-Fa-f]{64}')
  else
    # Store passphrase as plaintext (value in double quotes means plaintext)
    PSK_ENTRY="psk=\"$WIFI_PASSPHRASE_TEXT\""

    # TODO: find a way to calculate the PSK without using wpa_passphrase
    # http://jorisvr.nl/wpapsk.html
    # PSK = pbkdf2_hmac_sha1(password_, salt_ssid, iter=4096, key_len=256)
  fi

  # Create the wpa_supplicant.conf file
  
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
    echo "$EXE: $WIFI_CONF"
  fi
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   SSID=$WIFI_SSID (country: $WIFI_COUNTRY)"
  fi

else
  # No Wi-Fi

  if [ -e "$WIFI_CONF" ]; then
    rm  "$WIFI_CONF"
    if [ -z "$QUIET" ]; then
      echo "$EXE: deleted: $WIFI_CONF"
    fi
  fi

  if [ -n "$ALREADY_BOOTED" ]; then
    # The Raspberry Pi has already been booted, so if the Wi-Fi is
    # already set up, the absence of the "wpa_supplicant.conf" file will not
    # disable it.
    echo "$EXE: warning: already booted: Wi-Fi may have been configured" >&2
  fi
fi

#----------------------------------------------------------------
# SSH

touch "$SSH_FILE"

if [ -z "$QUIET" ]; then
  echo "$EXE: $SSH_FILE"
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   sshd will be enabled"
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
  sed "s/^[ \t]*$ITEM=.*/#$ITEM=/" "$CONFIG_FILE" > "$TMP"

  if [ -n "$VALUE" ]; then
    # Change commented statement to desired value
    sed "s/^[ \t]*#$ITEM=.*/$ITEM=$VALUE/" "$TMP" > "$CONFIG_FILE"
  else
    cp "$TMP" "$CONFIG_FILE"
  fi

  rm "$TMP"
}

#----------------

if [ -n "$HDMI_GROUP" ]; then
  # Configure HDMI

  _set_config hdmi_force_hotplug "$HDMI_FORCE_HOTPLUG"
  _set_config hdmi_group "$HDMI_GROUP"
  _set_config hdmi_mode "$HDMI_MODE"

  if [ -z "$QUIET" ]; then
    echo "$EXE: $CONFIG_FILE"
    if [ -n "$VERBOSE" ]; then
      echo "$EXE:   hdmi_force_hotplug: $HDMI_FORCE_HOTPLUG"
      echo "$EXE:   HDMI group/mode: $HDMI_GROUP/$HDMI_MODE"
    fi
  fi

fi

#----------------------------------------------------------------
# Create the headless setup init script

if [ -z "$QUIET" ]; then
  echo "$EXE: $INIT_FILE"
fi

if [ -n "$VERBOSE" ]; then
  if [ "$PI_PASSWORD" != "$DEFAULT_PI_PASSWORD" ]; then
    echo "$EXE:   pi user: password will be set"
  else
    echo "$EXE:   pi user: using default password ($DEFAULT_PI_PASSWORD)"
  fi
fi

# Start file

cat > "$INIT_FILE" <<EOF
#!/bin/sh
# $INIT_NAME
# Created by $PROGRAM $VERSION ($(date +%FT%T%z))
#----------------------------------------------------------------

if [ "\$(id -u)" -ne 0 ]; then
  echo "$INIT_NAME: error: root privileges required" >&2
  exit 1
fi

EOF

# User "pi" authentication

cat >> "$INIT_FILE" <<EOF
#----------------
# Default "pi" user account: password

USERNAME='pi'
PASSWORD='$PI_PASSWORD'

ERRORS="/home/\$USERNAME/$(basename $INIT_NAME .sh).errors"

echo "\$USERNAME:\$PASSWORD" | chpasswd

EOF

if [ -n "$PI_SSH_PUBKEY" ]; then
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   pi user: SSH public key: $PI_SSH_PUBKEY"
  fi

  cat >> "$INIT_FILE" <<EOF
#----------------
# Default "pi" user account: authorized keys file with SSH public key

if [ ! -e /home/\$USERNAME/.ssh ]; then
  mkdir /home/\$USERNAME/.ssh
  chown \$USERNAME: /home/\$USERNAME/.ssh
  chmod 755 /home/\$USERNAME/.ssh
fi

cat >> /home/\$USERNAME/.ssh/authorized_keys <<PUBKEY_EOF
$(cat "$PI_SSH_PUBKEY")
PUBKEY_EOF

chown \$USERNAME: /home/\$USERNAME/.ssh/authorized_keys
chmod 644 /home/\$USERNAME/.ssh/authorized_keys

EOF
else
  if [ -n "$ALREADY_BOOTED" ]; then
    # The Raspberry Pi has already been booted
    echo "$EXE: warning: already booted: .ssh/authorized_keys may exist" >&2
  fi

fi

# Hostname

if [ -n "$VERBOSE" ]; then
  echo "$EXE:   hostname: $HOSTNAME (mDNS name: $HOSTNAME.local)"
fi

cat >> "$INIT_FILE" <<EOF
#----------------
# Hostname

NEW_HOSTNAME='$HOSTNAME'

OLD_HOSTNAME=\$(cat /etc/hostname)
echo "\$NEW_HOSTNAME" > /etc/hostname
sed -i "s/\t\$OLD_HOSTNAME\$/\t\$NEW_HOSTNAME/" /etc/hosts

## Not needed, since will Pi will be rebooted
##
## hostname -F /etc/hostname # use it
## systemctl restart avahi-daemon.service # mDNS server

EOF

# Timezone

if [ -n "$TIMEZONE" ]; then
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   timezone: $TIMEZONE"
  fi

  cat >> "$INIT_FILE" <<EOF
#----------------
# Timezone

# For zones: run "timedatectl list-timezones" or look under /usr/share/zoneinfo

TIMEZONE='$TIMEZONE'

if [ -e "/usr/share/zoneinfo/\$TIMEZONE" ]; then
  # Set timezone

  ln -f -s "/usr/share/zoneinfo/\$TIMEZONE" /etc/localtime
  echo "\$TIMEZONE" > /etc/timezone

else
  echo "$INIT_NAME: error: unknown timezone: \$TIMEZONE" >> "\$ERRORS"
fi

EOF
fi

# Locale

if [ -n "$LOCALE" ]; then
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   locale: $LOCALE"
  fi

  cat >> "$INIT_FILE" <<EOF
#----------------
# Locale

LOCALE='$LOCALE'

if LOCALE_LINE="\$(grep "^\$LOCALE " /usr/share/i18n/SUPPORTED)"; then
  # Set locale

  ENCODING="\$(echo \$LOCALE_LINE | cut -f2 -d " ")"

  echo "\$LOCALE \$ENCODING" > /etc/locale.gen
  sed -i "s/^\s*LANG=\S*/LANG=\$LOCALE/" /etc/default/locale

  dpkg-reconfigure -f noninteractive locales

else
   echo "$INIT_NAME: error: unknown locale: \$LOCALE" >> "\$ERRORS"
fi

EOF
fi

# VNC

if [ -n "$VNC_PASSWORD" ]; then
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   VNC server will be configured (if it is installed)"
  fi

  cat >> "$INIT_FILE" <<EOF
#----------------
# VNC

# Note: the VNC password must be 6-8 characters and VNC is not really secure.
# That is why it will be locked down to access from localhost only,
# and only accessed via a secure SSH tunnel.

VNC_PASSWORD='$VNC_PASSWORD'

VNC_COMMON_CUSTOM=/etc/vnc/config.d/common.custom
VNC_ROOT_X11_CONFIG=/root/.vnc/config.d/vncserver-x11

if which vncpasswd >/dev/null \\
   && [ -d "\$(dirname "\$VNC_COMMON_CUSTOM")" ] \\
   && [ -d "\$(dirname "\$VNC_ROOT_X11_CONFIG")" ]; then
  # RealVNC server is installed: configure and enable it

  #--------
  # Configure vncserver to use a VNC password

  cat > \$VNC_COMMON_CUSTOM <<VNC_EOF
# RealVNC common custom config
# \$VNC_COMMON_CUSTOM
# Created by $INIT_NAME (\$(date +%FT%T%z))

# Use standard VNC password for authentication

Authentication=VncAuth
\$(echo "\$VNC_PASSWORD" | vncpasswd -print)
VNC_EOF

  #--------
  # Secure the VNC server by only allowing connections from localhost

  # Note: editing the file under /root.vnc since that is the one the
  # graphical options will change. While the statement could be added
  # to /etc/vnc/config.d/vncserver-x11, conflicts will occur if the
  # user then attempts to use the graphical options.

  if [ ! -e "\$VNC_ROOT_X11_CONFIG" ]; then
    # Create file
    touch "\$VNC_ROOT_X11_CONFIG"
  fi

  if ! grep -q '^IpClientAddresses=' "\$VNC_ROOT_X11_CONFIG"; then
    # File does not contain the statement

    # Add the statement so sed can then set it to the desired value
    # Deny all to fail securely, if for some reason sed fails.
    echo 'IpClientAddresses=-' >> "\$VNC_ROOT_X11_CONFIG"
  fi

  sed -i s/^IpClientAddresses=.*/IpClientAddresses=+127.0.0.1,+::1,-/ \\
      "\$VNC_ROOT_X11_CONFIG"

  #--------
  # Enable the VNC server

  VNCSERVER_SERVICE=vncserver-x11-serviced.service
  if ! systemctl is-enabled \$VNCSERVER_SERVICE >/dev/null ; then
    systemctl enable \$VNCSERVER_SERVICE
  fi

  ## Not needed, since will Pi will be rebooted
  ##
  ## if ! systemctl is-active \$VNCSERVER_SERVICE >/dev/null ; then
  ##   systemctl start \$VNCSERVER_SERVICE
  ## else
  ##   systemctl restart \$VNCSERVER_SERVICE
  ## fi
fi

EOF

else
  if [ -n "$VERBOSE" ]; then
    echo "$EXE:   VNC server will NOT be configured"
  fi

  if [ -n "$ALREADY_BOOTED" ]; then
    # The Raspberry Pi has already been booted, so if the VNC server might
    # already have been set up
    echo "$EXE: warning: already booted: VNC server may have been configured" >&2
  fi
fi

cat >> "$INIT_FILE" <<EOF
#----------------
# Clean up

# IMPORTANT: REMOVE THIS SCRIPT, SINCE IT CONTAINS PASSWORDS AND PASSPHRASES

rm -f /boot/$INIT_NAME

# Remove the commands from cmdline.txt that runs this script on boot

sed -i 's| systemd\.run=[^ ]*||' /boot/cmdline.txt
sed -i 's| systemd\.run_success_action=[^ ]*||' /boot/cmdline.txt
sed -i 's| systemd\.unit=[^ ]*||' /boot/cmdline.txt

#EOF
EOF

#----------------------------------------------------------------
# Edit the cmdline.txt file so the init script will run on boot

# BAK="$(dirname "$CMD_FILE")/$(basename "$CMD_FILE" .txt).bak"
# if [ ! -f "$BAK" ]; then
#   # Backup copy of the original file
#   cp -a "$CMD_FILE" "$BAK"
# fi

C1=systemd.run=/boot/"$INIT_NAME"
C2=systemd.run_success_action=reboot
C3=systemd.unit=kernel-command-line.target
EXTRA_CMD="$C1 $C2 $C3"

if [ -z "$QUIET" ]; then
  echo "$EXE: $CMD_FILE"
fi

NEW="$(dirname "$CMD_FILE")/$(basename "$CMD_FILE" .txt).new"

if ! grep -q 'systemd\.run=' "$CMD_FILE" ; then
  # Append to first line and retain any other lines
  awk "NR==1 {print \$0, \"$EXTRA_CMD\"; next} {print}" "$CMD_FILE" > "$NEW"
else
  # Replace previous systemd.run=...
  sed "s|systemd\.run=.*|$EXTRA_CMD|" "$CMD_FILE" > "$NEW"
fi

# Replace the cmdline.txt file with the modified version
mv "$NEW" "$CMD_FILE"
  
#----------------------------------------------------------------
#EOF
