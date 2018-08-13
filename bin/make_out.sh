#!/bin/sh -e

# updating OUT_DIR

STYLE="${STYLE:-default}"
SCALE="${SCALE:-50000}"
OUT_DIR=${OUT_DIR:-OUT}
VMAP_DIR=${VMAP_DIR:-vmap}

#OLD_PNG_DIR=${OLD_PNG_DIR:-png.bak}
LAST_PNG_DIR=${LAST_PNG_DIR:-png.last}

rm -f -- $LAST_PNG_DIR/*.png

for i in $VMAP_DIR/*.vmap; do
  name=${i%.vmap}
  name=${name##*/}

  mp="$OUT_DIR/$name.mp"
  png="$OUT_DIR/$name.png"
  map="$OUT_DIR/$name.map"
  img="$OUT_DIR/$name.img"
  jpg="$OUT_DIR/$name.jpg"
  htm="$OUT_DIR/$name.htm"

  mphead="$MP_DIR/$name.mp"
  fighead="$FIG_DIR/$name.fig"


  if [ "$png" -ot "$i" ]; then
    echo "Updating png: $name"

    mkdir -p -- "$LAST_PNG_DIR"
    [ -s "$png" ] &&
      convert "$png" -scale 50% "$LAST_PNG_DIR/${name}_o.png" ||:

    # create png & map
    vmap_render --nom "$name" --rscale=${SCALE} -d200 -ND -g4 -m "$map" "$i" "$png"
    map_rescale -s "$STYLE" "$map"

#    # backup png in $OLD_PNG_DIR
#    backup -d "$OLD_PNG_DIR" "$png"

    convert "$png" -scale 50% "$LAST_PNG_DIR/${name}_n.png"

    compare -matte "$LAST_PNG_DIR/${name}_o.png"\
            "$LAST_PNG_DIR/${name}_n.png"\
            PNG8:"$LAST_PNG_DIR/${name}_d.png" ||:
  fi

  # create MP and IMG
  if [ "$mp.zip" -ot "$i" -o "$img" -ot "$i" ]; then
    echo "Updating mp and img: $name"
    mapsoft_vmap $i -o "$mp" --skip_labels
    update_mpid.sh "$mp"
    cgpsmapper-static "$mp" -o "$img"
    zip -j "$mp.zip" "$mp"
#    rm -f "$mp"
     mv -f -- $mp mp/$name.mp
  fi

  # create OCAD
  if [ -n "$WRITE_OCAD" ]; then
    ocd="$OUT_DIR/$name.ocd"
    if [ "$ocd.zip" -ot "$i" ]; then
      echo "Updating ocad: $name"
      mapsoft_vmap $i -o "$ocd"
      zip -j "$ocd.zip" "$ocd"
      rm -f "$ocd"
    fi
  fi

  # create 1:5 JPEG
  if [ "$jpg" -ot "$png" ]; then
    echo "Updating jpg: $name"
    pngtopnm "$png" | pnmscale 0.2 | cjpeg > "$jpg"
  fi

  # create HTML
  if [ "$htm" -ot "$png" ]; then
    echo "Updating htm: $name"
    [ -f "$ocd" ] &&
      ocdref="<a href="$name.ocd.zip">[OCD9 - incomplete!]</a>" ||
      ocdref=""
    [ -f "$img" ] &&
      imgref="<a href="$name.img">[IMG]</a>" ||
      imgref=""

    cat > "$htm" <<-EOF
	<html>
	<head>
	  <title>$name</title>
	  <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=koi8-r">
	</head>
	<body>
	<div align=center>
	  <h2>$name</h2>
	  <p><a href="$name.png"><img src="$name.jpg" align=center></a>
	<p>
	 <a href="$name.png">[PNG]</a>
	 <a href="$name.map">[MAP]</a>
	 <a href="$name.mp.zip">[MP]</a>
	 $imgref
	 $ocdref
	</div>
	</body></html>
	EOF
  fi

done
