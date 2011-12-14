#!/bin/sh -eu

OUT_DIR=${OUT_DIR:-out}
GEOM=$1

if [ -z "$GEOM" ]; then
  echo "use: $0 <geom>"
  exit 1
fi
olddir="$(pwd)"
cd "$OUT_DIR"

for i in *.png; do

  [ -n "${i%%*_*}" ] || continue

  name=${i%.png}


  [ "$i" -ot "$name.jpg" ] || ../bin/image_resize.sh 1 5 "$i" "$name.jpg"

  imgref=
  [ ! -s "$name.img" ] ||
    imgref="<a href="$name.img">[IMG]</a>"

  [ -f "$name.htm" ] || \
cat > "$name.htm" <<EOF
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
 <a href="$name.ocd.zip">[OCD9 - incomplete!]</a>
</div>
</body></html>
EOF


done
mapsoft_convert *.map  *.plt --rescale_maps=0.2 -o maps.xml
sed -i 's/.png/.jpg/g' maps.xml

sed -i -e '/<\/\?maps>/d' maps.xml

mapsoft_convert maps.xml -g "$GEOM" -o index.jpg\
  --draw_borders=1 --dpi=3 --scale=2e-5 --htm=index.htm

sed -i -e '
  /^<area/{
    s/"\([^\."]*\)\.jpg" alt="" title=""/"\1.htm" alt="\1" title="\1"/;
    s/"\([^\."]*\)\.jpg"/"\1.htm"/;
    s/ href="..\/skl_map\/[^"]*"//;
  }' index.htm

cd "$olddir"
