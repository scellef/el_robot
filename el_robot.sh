#!/usr/bin/env bash
# Adapted from https://github.com/joshcartwright/bashbot

# Setting timezone to GST
export TZ='GST-0'

# Helper functions for colorized messages
function error { printf >&2 '[1;31mERROR: %s[0m\n' "$*" ;}
function success { printf >&2 '[1;32mSUCCESS: %s[0m\n' "$*" ;}
function warning { printf >&2 '[1;33mWARNING: %s[0m\n' "$*" ;}
function prompt { printf >&2 '[1;36m%s[0m\n' "$*" ;}

# Helper functions for commmunicating with the IRC server
function recv {
  if [[ "$@" =~ "PRIVMSG $nick :" ]] ; then
    echo "[35m← $(date +%FT%TZ$TZ): $@[0m" >&2
  elif [[ "$@" =~ "PRIVMSG #" ]] ; then
    echo "[32m← $(date +%FT%TZ$TZ): $@[0m" >&2
  elif [[ "$@" =~ [Nn]ick[Ss]erv.*NOTICE\ $nick\ :This\ nickname\ is\ registered.* ]] ; then
    echo "[33m← $(date +%FT%TZ$TZ): $@[0m" >&2
    identify_with_nickserv
  else
    echo "[34m← $(date +%FT%TZ$TZ): $@[0m" >&2
  fi
}

function send { 
  echo "[1;34m→ $(date +%FT%TZ$TZ): $@[0m" >&2
  printf '%s\r\n' "$@" >&3
}
export -f send

function identify_with_nickserv {
  send "PRIVMSG nickserv :identify $secret"
}

# Remaining function declarations
function quit { prompt "Exiting..." ; exit 0 ;}

# Load configuration
if [ -f ./el_robot.rc ] ; then
  . ./el_robot.rc
else
  error "Could not load configuration from ./el_robot.rc"
  quit
fi

# IRC Commands
ircNICK="NICK $nick"
ircUSER="USER $nick $hostName 8 :$realName"
ircQUIT='QUIT'

# Open connection to IRC network
exec 3<> /dev/tcp/${server}/${port} || { error "Could not connect to ${server}:${port}" ; quit ;}

# Login to IRC network
send "$ircUSER"
send "$ircNICK"

# Login to initial channels
for channel in $channels ; do
  send "JOIN :$channel"
done

# Continuously listen to server
while read -r response ; do
  response="${response%%$'\r'}" # Strip trailing carriage return

  recv $response

  # This converts the response into positional parameters
  set -- $response

  case "$@" in
  # This keeps the connect to the IRC server alive
    "PING "*)
      send "PONG $2"
      continue ;;

    "PRIVMSG $nick :"*)
       # private message to bot
       channel=$name
       prefix="PRIVMSG $name "
       set -- "${3#:}" "${@:4}"
       ;;
  esac

done <&3
