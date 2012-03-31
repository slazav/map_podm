#!/bin/sh -eu

OUT_DIR=${OUT_DIR:-out}
GEOM=$1

if [ -z "$GEOM" ]; then
  echo "use: $0 <geom>"
  exit 1
fi

cd "$OUT_DIR"

mapsoft_convert *.map  *.plt --rescale_maps=0.2 -o maps.xml
sed -i 's/.png/.jpg/g' maps.xml

sed -i -e '/<\/\?maps>/d' maps.xml

mapsoft_convert maps.xml --geom "$GEOM" -o index.jpg\
  --draw_borders --dpi=3 --rscale=100000 --htm=index.htm

sed -i -e '
  /^<area/{
    s/"\([^\."]*\)\.jpg" alt="" title=""/"\1.htm" alt="\1" title="\1"/;
    s/"\([^\."]*\)\.jpg"/"\1.htm"/;
    s/ href="..\/skl_map\/[^"]*"//;
  }' index.htm

cd -
