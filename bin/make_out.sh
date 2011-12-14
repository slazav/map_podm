#!/bin/sh -e

# updating OUT_DIR

STYLE="${STYLE:-default}"
OUT_DIR=${OUT_DIR:-OUT}
VMAP_DIR=${VMAP_DIR:-vmap}

OLD_PNG_DIR=${OLD_PNG_DIR:-png.bak}
LAST_PNG_DIR=${LAST_PNG_DIR:-png.last}

rm -f -- $LAST_PNG_DIR/*.png

for i in $VMAP_DIR/*.vmap; do
  name=${i%.vmap}
  name=${name##*/}

  ocd="$OUT_DIR/$name.ocd"
  mp="$OUT_DIR/$name.mp"
  png="$OUT_DIR/$name.png"
  map="$OUT_DIR/$name.map"
  img="$OUT_DIR/$name.img"

  mphead="$MP_DIR/$name.mp"
  fighead="$FIG_DIR/$name.fig"


  if [ "$png" -ot "$i" ]; then
    echo "Updating png: $name"

    [ ! -s "$png" ] || mv -- "$png" "$LAST_PNG_DIR/${name}_o.png"

    # create png & map
    vmap_render --nom "$name" --rscale=50000 -d200 -ND -g4 -m "$map" "$i" "$png"
    map_rescale -s "$STYLE" "$map"

    # backup png in $OLD_PNG_DIR
    backup -d "$OLD_PNG_DIR" "$png"

    ln -s "../$png" "$LAST_PNG_DIR/${name}_n.png"
#    compare "$LAST_PNG_DIR/${name}_o.png"\
#            "$LAST_PNG_DIR/${name}_n.png"\
#            "$LAST_PNG_DIR/${name}_d.png" ||:
  fi

  if [ "$mp.zip" -ot "$i" -o "$img" -ot "$i" ]; then
    echo "Updating mp and img: $name"

    vmap_copy $i -o "$mp" --skip_labels
    update_mpid.sh "$mp"
    cgpsmapper-static "$mp" -o "$img"
    zip -j "$mp.zip" "$mp"
    rm -f "$mp"
  fi

  if [ "$ocd.zip" -ot "$i" ]; then
    echo "Updating ocad: $name"
    vmap_copy $i -o "$ocd"
    zip -j "$ocd.zip" "$ocd"
    rm -f "$ocd"
  fi

done
