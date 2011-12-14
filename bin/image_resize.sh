#!/bin/sh

if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
  echo "usage: $0 <nom> <denom>  <in_image> <out_image>"
  exit 1
fi

if [ ! -f "$3" ]; then
  echo "can't find file $3"
  exit 1
fi

size=$(identify $3 | cut -f 3 -d ' ')
  [ "$?" = 0 ] || exit 1

x=$(( ${size%x*} * $1 / $2 ))
y=$(( ${size#*x} * $1 / $2 ))

echo "$3 $size -> $4 ${x}x${y}"

convert -geometry "${x}x${y}" $3 $4

