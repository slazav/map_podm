###############################
# 2020-10-31, new rendering system

### Directories:
VDIR  := vmap
ODIR  := OUT
TDIR  := TILES
DBDIR := mapdb
CFDIR := conf
DFDIR := diff


### Programs:

# v1.4 should be enough
MS2MAPDB := ms2mapdb

# v1.4+ (e06178d58341b8879188877777c791cecdd814ee)
MS2CONV := ms2conv
GMT     := gmt

# scale for jpeg preview images:
jpeg_scale:=0.2


# Sources, individual maps
#VMAP = $(VDIR)/j42-043.vmap
#VMAP = $(wildcard $(VDIR)/j42-*.vmap)
VMAP = $(wildcard $(VDIR)/*.vmap)

# What do we want to generate, individual maps
PNG = $(patsubst $(VDIR)/%.vmap, $(ODIR)/%.png,     $(VMAP))
JPG = $(patsubst $(VDIR)/%.vmap, $(ODIR)/%.jpg,     $(VMAP))
MPZ = $(patsubst $(VDIR)/%.vmap, $(ODIR)/%.mp.zip,  $(VMAP))
IMG = $(patsubst $(VDIR)/%.vmap, $(ODIR)/%.img,     $(VMAP))
HTM = $(patsubst $(VDIR)/%.vmap, $(ODIR)/%.htm,     $(VMAP))
MDB = $(patsubst $(VDIR)/%.vmap, $(DBDIR)/%,        $(VMAP))

# Map lists
REGIONS := podm

REG_IMG := $(patsubst %, $(ODIR)/all_%.img, $(REGIONS))
REG_HTM := $(patsubst %, $(ODIR)/all_%.htm, $(REGIONS))
REG_JPG := $(patsubst %, $(ODIR)/all_%.jpg, $(REGIONS))

all: htm reg_htm tiles
htm: directories $(HTM)
png: directories $(PNG)
jpg: directories $(JPG)
img: directories $(IMG)

# Note that REG_* files themselves do not have dependencies on
# individual maps yet. Here I put "strong" dependencies.
reg_htm: $(HTM) $(REG_HTM) reg_jpg reg_img
reg_img: $(IMG) $(REG_IMG)
reg_jpg: $(JPG) $(REG_JPG)

##################################################
# Directories
.PHONY: directories
directories: $(ODIR) $(TDIR) $(DFDIR) $(DBDIR)

$(ODIR) $(TDIR) $(DFDIR) $(DBDIR):
	mkdir -p $@

##################################################
# Colormap.
# Below there is a rule for generating colormap from one of
# the maps. The map should contain all colors which can appear.
# I will now use old colormap instead.

## generate colormap from a single map 
#CMAP = $(ODIR)/cmap.png
#CMAP_NAME = n37-002
#$(CMAP): $(DBDIR)/$(CMAP_NAME)
#	$(MS2MAPDB) render $<\
#	  --out tmp_cmap.png --config $(CFDIR)/render.cfg\
#	  --define "{\"nom_name\":\"$(CMAP_NAME)\", \"hr\":\"0\"}"\
#	  --mkref nom --name $(CMAP_NAME) --dpi 400\
#	  --cmap_color 255 --cmap_save $@ --cmap_add 0\
#	  --png_format pal
#	rm -f tmp_cmap.png

CMAP = $(CFDIR)/cmap.png

##################################################
# Rules for making individual maps

# create mapdb from vmap
$(DBDIR)/%: $(VDIR)/%.vmap
	$(MS2MAPDB) delete $@
	$(MS2MAPDB) create $@
	$(MS2MAPDB) import_vmap $@ $< --config $(CFDIR)/import_vmap.cfg

# generate PNG image + map, make diff files
$(ODIR)/%.png: $(DBDIR)/% $(CMAP) $(CFDIR)/render.cfg
	[ -s "$@" ] && convert $@ -scale 50% "$(DFDIR)/$*_o.png" ||:
	$(MS2MAPDB) render $< --out $@ --config $(CFDIR)/render.cfg\
	 --define "{\"nom_name\":\"$*\", \"hr\":\"0\"}"\
	 --mkref nom --name $* --dpi 400 --margins 10 --top_margin 30\
	 --title "$*   /$$(date +"%Y-%m-%d")/" --title_size 20\
	 --cmap_load $(CMAP) --png_format pal --map $(ODIR)/$*.map
	convert $@  -scale 50% "$(DFDIR)/$*_n.png"
	compare -matte "$(DFDIR)/$*_o.png" "$(DFDIR)/$*_n.png"\
	  "PNG8:$(DFDIR)/$*_d.png" ||:

# generate MP. ID should be unique, 8 decimal digits
$(ODIR)/%.mp: $(DBDIR)/% $(CFDIR)/export_mp.cfg
	id=`( echo "ibase=16"; echo $* | md5sum | head -c6 | tr a-z A-Z; echo ) | bc`;\
	ms2mapdb export_mp $< $@ --name "$*" --id "$$id"

# generate IMG
$(ODIR)/%.img: $(ODIR)/%.mp
	cgpsmapper-static "$<" -o "$@"

# generate mp.zip
$(ODIR)/%.mp.zip: $(ODIR)/%.mp
	zip -j "$@" "$<"

# generate JPG (20% size)
$(ODIR)/%.jpg: $(ODIR)/%.png
	pngtopnm "$<" | pnmscale 0.2 | cjpeg -quality 50 > "$@"

# generate HTML
$(ODIR)/%.htm: $(ODIR)/%.png  $(ODIR)/%.img  $(ODIR)/%.mp.zip $(ODIR)/%.jpg
	date=`date +"%Y-%m-%d"`;\
	sed "s|((NAME))|$*|g;s|((DATE))|$$date|g" $(CFDIR)/map.htm > $@

##################################################
# Rules for making tiles.
# - process all mapdb folders newer then tstamp in tiles/
# - render with --add switch: add information to existing tiles
# - render with --tmap_scale 1: rescale larger tiles to 
# - do separately for zoom 9..12 and 0..8

# 1st timestamp depends on configuration files.
# It's updated when configuration changes and tiles should be
# recreated from scratch.
TSTAMP1=$(TDIR)/tstamp1
$(TSTAMP1): $(CFDIR)/render.cfg $(CFDIR)/border.gpx $(CMAP)
	mkdir -p $(TDIR)
	rm -f $(TDIR)/*.png $(TSTAMP2)
	touch $(TSTAMP1)

# 2nd timestamp is updated when tiles are updated.
# In normal situation only maps which are newer then tstamp2
# are rendered.
TSTAMP2=$(TDIR)/tstamp2
.PHONY: tiles
tiles: $(MDB) $(TSTAMP1)
	for n in $(MDB); do \
	[ "$$n/objects.db" -nt  "$(TSTAMP2)" ] || continue;\
	echo "$$n";\
	name=`basename $$n`;\
	$(MS2MAPDB) render $$n --config $(CFDIR)/render.cfg\
	  --define "{\"nom_name\":\"$$name\", \"hr\":\"0\", \"border_style\":\"none\"}"\
	  --tmap --add --out "$(TDIR)/{x}-{y}-{z}.png" --zmin 7 --zmax 14\
	  --bgcolor 0 --png_format pal --cmap_load $(CMAP)\
	  --border_file $(CFDIR)/border.gpx\
	  --tmap_scale 1;\
	$(MS2MAPDB) render $$n --config $(CFDIR)/render.cfg\
	  --define "{\"nom_name\":\"$$name\", \"hr\":\"0\", \"border_style\":\"none\"}"\
	  --tmap --add --out "$(TDIR)/{x}-{y}-{z}.png" --zmin 0 --zmax 6\
	  --bgcolor 0 --png_format pal --cmap_load $(CMAP)\
	  --border_file $(CFDIR)/border.gpx\
	  --tmap_scale 1 --mapdb_minsc 1;\
	done
	touch $(TSTAMP2)

##################################################
# Rules for making map lists.

# calculate map list for each region
$(ODIR)/all_%.img $(ODIR)/all_%.jpg $(ODIR)/all_%.htm:\
   VMAP_LIST=$(shell $(CFDIR)/get_map_list $@ vmap)

# rule for making img files
$(ODIR)/all_%.img:
	img="$(patsubst $(VDIR)/%.vmap, $(ODIR)/%.img, $(VMAP_LIST))";\
	$(GMT) -j -v -m "slazav-$base" -f 779,3 -o $@ $$img conf/slazav.typ

# rule for making index html+image
$(ODIR)/all_%.htm $(ODIR)/all_%.jpg:
	maps="$(patsubst $(VDIR)/%.vmap, $(ODIR)/%.map, $(VMAP_LIST))";\
	tmp="$$(mktemp -u tmp_XXXXXX)";\
	$(MS2CONV) $$maps --rescale_maps=$(jpeg_scale) -o "$$tmp.json";\
	sed -i -e 's/\.png/\.jpg/g' "$$tmp.json";\
	$(MS2CONV) "$$tmp.json" -o "$(ODIR)/all_$*.jpg"\
	    $(CFDIR)/MO.plt $(CFDIR)/MKAD.plt --trk_draw_dots 0\
	    --map_draw_brd 0xFFFF0000 --map_max_sc 100\
	    --border_wgs '[]'\
	    --htm "$$tmp.htm" --mag 0.1;\
	$(CFDIR)/make_html_index "$*" "$$tmp.htm" "$(ODIR)" > "$@";\
	rm -f $$tmp.{htm,json}


##################################################
#IMG_NAME=podm.img
#img:
#	$(GMT) -j -v -m "SLAZAV-HR" -f 779,2 -o ${IMG_NAME} OUT/*.img /usr/share/mapsoft/slazav.typ
#	mv -f ${IMG_NAME} /home/sla/CH/data/maps/
#	sed -e "/${IMG_NAME}/s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/$(date +%F)/"\
#	  -i /home/sla/CH/data/maps/index.m4i
