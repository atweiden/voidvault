#!/bin/bash
TMOUT="$((60 * 10))";
[[ -z "$DISPLAY" ]] && export TMOUT;
case "$(/usr/bin/tty)" in
  /dev/tty[0-9]*) export TMOUT;;
esac
