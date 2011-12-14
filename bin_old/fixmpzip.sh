#!/bin/sh -efu

is_zip=
if [ -z "${1%%*.mp.zip}" ]; then
  unzip "$1"
  is_zip=1
fi

sed -i -e '
  /\[IMG ID\]/,/\[END/{
    /^Levels=/d
    /^Level0=/iLevels=4\r
  }' "${1%.zip}"

if [ -n "$is_zip" ]; then
  zip "$1" "${1%.zip}"
  rm -f "${1%.zip}"
fi

