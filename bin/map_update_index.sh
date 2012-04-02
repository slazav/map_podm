#!/bin/sh -eu

OUT_DIR=${OUT_DIR:-OUT}
. mapsoft_crd.sh

if [ "$#" != 2 ]; then
  echo "use: $0 <geom> <base>"
  exit 1
fi

geom=$1
base=$2

jpeg_scale=0.2
jpg=all_$base.jpg
htm=all_$base.htm
xml=all_$base.xml
img=all_$base.img
txt=all_$base.txt

cd "$OUT_DIR"

# calculate map list
maps=''
imgs=''
upd=''
for n in $(geom2nom "$geom" 100000); do
  [ "$n.png" -ot "$htm" ] || upd=1;
  [ ! -f "$n.map" ] || maps="$maps $n.map"
  [ ! -f "$n.img" ] || imgs="$imgs $n.img"
done
[ "$txt" -ot "$htm" ] || upd=1;

if [ -z "$upd" ]; then echo "no need to update $base index"; exit 0; fi

# make xml with all small jpeg maps; make index imageand htm
mapsoft_convert $maps *.plt --rescale_maps=$jpeg_scale -o "$xml"
sed -i -e 's/.png/.jpg/g' "$xml"
mapsoft_convert "$xml" --geom "$geom" -o "$jpg"\
  --draw_borders --dpi=4 --rscale=100000 --htm="tmp.htm"

cat > "$htm" <<-EOF
	<html>
        <head>
	  <title>$name</title>
	  <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=koi8-r">
	</head>
        <body>
	EOF
[ ! -f "$txt" ] || cat "$txt" >> $htm
sed -e '
  /^<area/{
    s/"\([^\."]*\)\.jpg" alt="" title=""/"\1.htm" alt="\1" title="\1"/
    s/"\([^\."]*\)\.jpg"/"\1.htm"/
    s/ href="..\/skl_map\/[^"]*"//
    /<\/html>/d
    /<html>/d
  }' tmp.htm >> "$htm"

d="$(date +"%F %T")"

cat >> "$htm" <<-EOF
	<p><a href="$img">Склейка векторных карт в формате IMG (typ-файл включен)</a></p>
	<p><a href="$xml">Привезка всех листов в формате mapsoft</a></p>
        <div align=right><i>/$d/</i></div>
	</body></html>
	EOF

# make more useful xml
mapsoft_convert $maps -o "$xml"

# make img file
gmt -j -v -m "slazav-$base" -o $img $imgs /usr/share/mapsoft/slazav.typ

cd -
