#!/bin/sh -e

IN_DIR="${IN_DIR:-IN}"
VMAP_DIR="${VMAP_DIR:-vmap}"
SCALE="${SCALE:-50000}"
FILTER="${FILTER:-}"

for i in $IN_DIR/*.fig $IN_DIR/*.mp; do
  [ -f $i ] || continue
  name=${i%.*}
  name=${name##*/}
  ext=${i##*.}

  vmap=$VMAP_DIR/$name.vmap

  if [ ! -f "$vmap" ]; then
    echo " . skipping unknown file: $i"
    continue;
  fi

  if [ "$i" -ot "$vmap" ]; then
    echo " . skipping old file: $i"
    continue;
  fi

  echo " * updating from: $i"
  echo " $(date +"%x %X") updating from $i" >> in.log

  # save old file mtime
  ot="$(stat "$i" -c %y)"

  cp -f "$i" "$i.bak"
  backup -D -d bak -z -- "$vmap"

  # mmb-filter
  [ "$FILTER" = mmb ] && vmap_mmb_filter "$i" "$i" ||:

  sources="$i"

  old="$(mktemp inXXXXXX.vmap)"

  if [ -f "$vmap" ]; then
    mv "$vmap" "$old"

    # mp has no labels
    if [ "${i##*.}" = "mp" ]; then
      sources="$i --skip_labels $old --split_labels --skip_all"
    fi
  fi

  # crop and put to vmap!
  vmap_copy --range_nom "$name" --range_action crop_spl\
            --name "$name" --rscale "$SCALE" --set_brd_from_range\
            $sources -o "$vmap"

  if [ -s "$old" ]; then
    vmap_fix_diff "$old" "$vmap" "$vmap"
  fi

  rm -f "$old"

#  vmap_copy --name "$name" --rscale "$SCALE"\
#            $sources -o "$vmap"

  # save fig
  if [ "$ext" = fig ]; then
    cp -f -- "$i" "fig/$name.fig"
    vmap_copy "fig/$name.fig" -o "fig/$name.fig" --skip_all
  fi

  # create fig
  vmap_copy "$vmap" -o "$i"
  touch -d "$ot" "$i"
done
