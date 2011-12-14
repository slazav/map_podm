#!/bin/sh -efu

sed -i -e '
  /\[IMG ID\]/,/\[END/{
    /^Levels=/d
    /^Level0=/iLevels=4\r
  }' "$@"