#!/usr/bin/env bash

BAK_DIR=''
USE_ZENITY=0
BAK_GPG=0
BAK_GK=0
BAK_CFG=0
LIMIT_SIZE=768 # 768MB
SILENT=0




function usage
{
  MSG="usage: $0 options\n
\n
This script make backup of .config and all exported GPG keys.\n
GPG export for private keys and trusts asks your passphrase.\n
\n
/!\ \tWarning\t /!\ \n
Backups have no permissions in order to use FAT32 filesystem.\n
Everyone can reads thems, including _private keys_!\n
Use external data storage like USB flash drive, and remove it after backup.\n
\n
OPTIONS:\n
   -a     all\n
          Active all backup options\n
   -c     config\n
          Backup ~/.config\n
   -d     directory\n
          Choose directory where write backup ; required\n
   -g     gpg\n
          Backup all GPG keys\n
   -h     help\n
          Show this message\n
   -k     keyring\n
          Backup gnome keyring\n
   -m     max size\n
          Ignore directories greater; default 768 (0,75 GB)\n
   -s     silent\n
          No output except errors\n
   -z     zenity\n
          Use zenity instead echo on terminal\n"

  say $MSG
  exit
}

function fs_type
{
  echo `df --output=fstype $@ | tail -n1`
}

function say
{
  if [ ! "$SILENT" == 1 ] ; then
    if [ $USE_ZENITY == 1 ] ; then
      zenity --info --text "`echo $@ | sed 's/^\n//'`"
    else
     #MSG = "`echo $@ | sed 's/^\n//'`"
      echo -e $@  # | fold -s
    fi
  fi
}

function bak_gpg
{
  mkdir --parents "$BAK_DIR/GPG.key/"
  gpg2 --export-ownertrust > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.trust"
  gpg2 --export --armor > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.pub"
  gpg2 --export-secret-keys --armor > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.priv"
}

function bak_gk
{
  $RSYNC_CMD "/home/$USER/.local/share/keyrings/" "$BAK_DIR/keyrings"
}

function bak_cfg
{
  DIR="/home/$USER/.config"
  pushd $DIR > /dev/null
  LIMIT_SIZE=$((1024*1024*$LIMIT_SIZE))

  # Get file too big
  EXCLUDES='--exclude=cache* '
  PRINTABLE_EXCLUDES=''
  for f in `du --threshold $LIMIT_SIZE -s * | cut -f2` ; do
    EXCLUDES="$EXCLUDES--exclude=$f "
    PRINTABLE_EXCLUDES="$PRINTABLE_EXCLUDES$f "
  done

  $RSYNC_CMD $EXCLUDES "$DIR"  "$BAK_DIR"

  MSG="Backups finished to\n$BAK_DIR."
  if [ ! "$PRINTABLE_EXCLUDES" == '' ] ; then
    LIMIT_SIZE=$(($LIMIT_SIZE / 1024 / 1024))
    MSG="$MSG\n\nDirectories excluded (over $LIMIT_SIZE Mio) :\n$PRINTABLE_EXCLUDES"
  fi
  say $MSG
  popd > /dev/null
}


while getopts “cad:ghknm:z” OPTION ; do
case $OPTION in
  z)
    USE_ZENITY=1
    ;;
  a)
    BAK_CFG=1
    BAK_GK=1
    BAK_GPG=1
    ;;
  c)
    BAK_CFG=1
    ;;
  d)
    BAK_DIR=`dirname $OPTARG/coincoin`
    ;;
  g)
    BAK_GPG=1
    ;;
  h)
    usage
    ;;
  k)
    BAK_GK=1
    ;;
  m)
    LIMIT_SIZE=$OPTARG
    ;;
  s)
    SILENT=1
    ;;
  ?)
    usage
    ;;
esac
done

if [ -z "$BAK_DIR" ] ; then
  say "Where have I to write backups?\n"
  usage
fi

if [ ! -d "$BAK_DIR" ] ; then
  say "Unable to read $BAK_DIR\n"
  exit 1
fi


# FAT fs doesn't support links and permissions
RSYNC_OPTIONS='-a --safe-links --del --ignore-errors'
if [ -n "`fs_type $BAK_DIR | sed -n '/fat/ {p}'`" ] ; then
  RSYNC_OPTIONS="$RSYNC_OPTIONS --no-o --no-p --no-g --modify-window 1 "
fi


RSYNC_CMD="rsync $RSYNC_OPTIONS "
BAK_DIR="$BAK_DIR/backup"
NOW=`date +%F`


say "Dont't forget: use external data storage like USB flash drive, and remove it after backup.\n"
if [ "$DO_NOTHING" == 1 ] ; then exit ; fi

if [ "$BAK_GPG" == 0 ] && [ "$BAK_GK" == 0 ] && [ "$BAK_CFG" == 0 ] ; then
  say "Nothing to backup.\n"
  usage
fi


# Backup gpg
if [ "$BAK_GPG" == 1 ] ; then
  bak_gpg
fi

# Backup gnome-keyring
if [ "$BAK_GK" == 1 ] ; then
  bak_gk
fi

# Backup gnome-keyring
if [ "$BAK_CFG" == 1 ] ; then
  bak_cfg
fi


exit # comment if .gnupg, .mozilla and .icedove are not in your .config/

rsync -a --no-o --no-p --no-g --safe-links --modify-window 1 --del --stats --ignore-errors \
  /home/$USER/.gnupg/ \
  "$BAK_DIR/.config/gnupg"

rsync -a --no-o --no-p --no-g --safe-links --modify-window 1 --del --stats --ignore-errors \
  /home/$USER/.mozilla/ \
  "$BAK_DIR/.config/mozilla"

rsync -a --no-o --no-p --no-g --safe-links --modify-window 1 --del --stats --ignore-errors \
  /home/$USER/.icedove/ \
  "$BAK_DIR/.config/icedove"
