#!/usr/bin/env bash

BAK_DIR=$1
USE_ZENITY=0
LIMIT_SIZE=768
BAK_KEYS=0


function say
{
  if [ $USE_ZENITY == 1 ] ; then
    zenity --info --text "`echo $@ | sed 's/^\n//'`"
  else
   #MSG = "`echo $@ | sed 's/^\n//'`"
    echo -e $@  | fold -s
    echo
  fi
}


function usage
{
  MSG="usage: $0 options\n
\n
This script make backup of .config and all exported GPG keys.\n
\n
OPTIONS:\n
   -h      Show this message\n
   -z      Use zenity instead echo on terminal.\n
   -g      Backup all GPG keys.\n
   -s      Ignore directories greater, in Mio ; default 768 (0,75 Gio)\n
   -d      Choose directory where write backup ; required.\n
\n"

  say $MSG
  exit
}

while getopts “d:ghs:z” OPTION ; do
case $OPTION in
  d)
    BAK_DIR=`dirname $OPTARG/coincoin`
    ;;
  g)
    BAK_KEYS=1
    ;;
  h)
    usage
    ;;
  s)
    LIMIT_SIZE=$OPTARG
    ;;
  z)
    USE_ZENITY=1
    ;;
  ?)
    usage
    ;;
esac
done

if [ -z "$BAK_DIR" ] ; then
  usage
fi

if [ ! -d "$BAK_DIR" ] ; then
  echo "Unable to read $BAK_DIR"
  exit 1
fi


NOW=`date +%F`
BAK_DIR="$BAK_DIR/backup"
DIR="/home/$USER/.config"
LIMIT_SIZE=$((1024*1024*$LIMIT_SIZE)) # 1Gio


if [ "$BAK_KEYS" == 1 ] ; then
  # Backup gpg
  mkdir --parents "$BAK_DIR/GPG.key/"
  gpg2 --export-ownertrust > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.trust"
  gpg2 --export --armor > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.pub"
  gpg2 --export-secret-keys --armor > "$BAK_DIR/GPG.key/$USER@$HOSTNAME_$NOW.pub"
fi


# Get file too big
EXCLUDES=''
PRINTABLE_EXCLUDES=''
for f in `du --threshold $LIMIT_SIZE -hs * | cut -f2` ; do
  EXCLUDES="$EXCLUDES--exclude=$f "
  PRINTABLE_EXCLUDES="$PRINTABLE_EXCLUDES$f "
done


rsync -a --no-o --no-p --no-g --safe-links --modify-window 1 --del \
  --stats --ignore-errors \
  $EXCLUDES "$DIR"  "$BAK_DIR"

MSG="Backups finished to\n$BAK_DIR."
if [ ! "$PRINTABLE_EXCLUDES" == '' ] ; then
  LIMIT_SIZE=$(($LIMIT_SIZE / 1024 / 1024))
  MSG="$MSG\n\nDirectories excluded (over $LIMIT_SIZE Mio) :\n$PRINTABLE_EXCLUDES"
fi
say $MSG


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
