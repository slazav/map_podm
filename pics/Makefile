PICS := avt kladb cross cerkov pam ohotn bash shaht razv dom trig trig_hr kan\
        per per1a per1b per2a per2b per3a per3b pernk\
        v2_per v2_per1a v2_per1b v2_per2a v2_per2b v2_per3a v2_per3b v2_pernk\
        ldp  kladb pupyr yama skala\
        bol_l bol_h zd ur_vod por vdp pesch\
        rossip1 rossip2 sand_ov camp camp2 camp3 gate at at2\
        ledn redk vyr_n vyr_o sand


PNG := $(patsubst %,%.png,$(PICS))
SVG := $(patsubst %,%.svg,$(PICS))


all: $(PNG)
clean:
	rm -f *.png *.svg *.gif

SC=7.5
ledn.png redk.png vyr_n.png vyr_o.png sand.png: SC=10.4
#ledn.png redk.png vyr_n.png vyr_o.png sand.png: SC=5.2

OPT=
## -2,+10
bol_h.png: OPT=-background transparent -extent 286x60
## -2,+7
bol_l.png: OPT=-background transparent -extent 192x83

# fig2dev -t option only allowed for GIF transparent color
%.gif: %.fig
	fig2dev -m$(SC) -Lgif -t#ffffff "$<" > "$@"

%.png: %.gif
	convert -trim "$<" -repage +0+0 $(OPT) PNG32:"$@"

%.svg: %.fig
	fig2dev -m7.5 -Lsvg "$<" > "$@"
