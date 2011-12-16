#!/bin/sh -efu

# update ID and Name fields in vmap or mp files

for file in $@; do

  name="${file##*/}"
  name="${name%.*}"

  mp_id="$(echo "$name" |\
    sed -e '
     s/\([a-i]\)/0\1/g
     s/\([j-s]\)/1\1/g
     s/\([tu]\)/2\1/g
     s/-//g; s/\..*//' |\
       tr abcdefjhijklmnopqrstu 1234567890123456789012)"

  err="$(echo "$mp_id" | tr -d '0-9')"
  if [ -n "$err" ]; then
    echo "Can't find ID for $name!" >&2
    continue
  fi

  echo "${0##*/}: file: $file - id: $mp_id name: $name"

  if [ "${file##*.}" = "vmap" ]; then
    sed -i -e "s/^MP_ID.*$/MP_ID\t$mp_id/" $file
    grep -q '^NAME' $file &&
      sed -i -e "s/^NAME.*$/NAME\t$name/" $file ||
      sed -i -e "1aNAME\t$name" $file
  elif [ "${file##*.}" = "mp" ]; then
    sed -i -e "s/^ID=.*$/ID=$mp_id/"\
           -e "s/^Name=.*$/Name=$name/" $file
    if [ "$(head -c1 "$file")" != ";" ]; then
      sed -i '1i; updated by slazav' "$file"
    fi
  else
    echo "unknown format"
  fi

done