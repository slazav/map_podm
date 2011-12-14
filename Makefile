out:
	. ./settings.sh; make_out.sh
in:
	. ./settings.sh; make_in.sh
sync:
	./sync_sv
img:
	gmt -j -v -m "SLAZAV-1" -o podm.img OUT/?36*.img OUT/?37*.img /usr/share/mapsoft/slazav.typ
	mv -f podm.img /home/sla/CH/data/maps/
	sed -e "/podm.img/s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/$(date +%F)/"\
	  -i /home/sla/CH/data/maps/index.m4i

index:
	. ./settings.sh; map_update_index.sh 600000x400000+7085000+5970000

