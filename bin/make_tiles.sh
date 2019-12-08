#!/bin/bash
#
# Aleksey Kazantsev, 2019
#

set -e

# Настройки

export OUT=${OUT:-tiles}				# Рабочая папка с результатами
export VMAP_DIR=${VMAP_DIR:-vmap}		# Папка с исходными картами
SQLITEDB=slazav.sqlitedb 				# Имя файла с картами для OSM
MBTILES=slazav.mbtiles   				# Имя файла с картами в формате MBTiles
# При необходимости в настройках RENDOPTS и PNGQOPTS можно существенно
#  уменьшить размер файлов за счёт качества
export RENDOPTS="--patt_filter best"	# Дополнительные опции vmap_render
export PNGQOPTS="-s 1"					# Дополнительные опции pngquant
export USEADVPNG=1						# Ещё чуть уменьшить размер без потерь
export ADVPNGOPTS="-3"					# Опции advpng, можно попробовать -4
# Приближения создаваемых плиток; фактически, это последовательности масштабов
# Новое большее приближение увеличивает общий размер файлов примерно в 3 раза
TILESZ="5 6 7 8 9 10 11 12 13 14"
# Группировать плитки по (2^ZZ)^2 штук для ускорения отрисовки
# Разумные значения 0..3, оптимальное зависит от аппаратной конфигурации
export ZZ=2
# Условная базовая плотность точек для приближения номер 14
# Для повышения качества отрисовки и уменьшения размера файлов рекомендуется
#  пересобрать и переустановить mapsoft, заменив в файле make_pics
#  параметр -m7.5 на -m7.88 , что даст более регулярное наложение шаблонов
export DPI="${DPI:-200}"
# Автоопределение количества задействованных процессоров
CPUNUM=`grep "^processor" /proc/cpuinfo  | wc -l`

################################################################################

# Функция отрисовки одной плитки
renderfunc() 
{
	source $OUT/globalvars

	tile=$*
	needed=
	num=0

	read usemask x y z <<< "$tile"

	# Поищем файлы относящиеся к нашей плитке
	for mname in $mapnames; do
		if [[ "${maptiles[${mname}_x]}" =~ " $x " ]]; then
			if [[ "${maptiles[${mname}_y]}" =~ " $y " ]]; then
				needed+="$VMAP_DIR/$mname.vmap "
				((num++))
			fi
		fi
	done

	if [ -z "$needed" ]; then
		# Тут мы не должны оказаться, но на всякий случай проверим
		return
	fi

	echo Рисуем $x,$y,$z с увеличением $((2**ZZ)) по $needed
	# Придумаем временное имя для плитки в папке /tmp
	tname=`mktemp /tmp/tmp.XXXXXXXXXX`

	# Проверяем сколько карт относится к нашей плитке
	if [ $num -eq 1 ]; then
		# Сразу отрисуем нужную плитку
		vmap_render $RENDOPTS --nobrd 1 --mag $((2**ZZ)) --google $x,$y,$z \
				--dpi $DPI $needed $tname.png
	else
		# Объединим нужные карты во временный файл и потом отрисуем плитку
		trange=`convs_gtiles -n $x $y $z`
		tmap=`mktemp /tmp/tmp.XXXXXXXXXX.vmap`
		vmap_copy $needed -o $tmap --range $trange --set_brd_from_range
		vmap_render $RENDOPTS --nobrd 1 --mag $((2**ZZ)) --google $x,$y,$z \
				--dpi $DPI $tmap $tname.png
		rm $tmap
	fi

	# Если надо, отрисуем и применим маску
	if [ $usemask -eq 1 ]; then
		echo Применим маску к плитке $x,$y,$z
		mname=`mktemp /tmp/tmp.XXXXXXXXXX`
		vmap_render $RENDOPTS --nobrd 1 --mag $((2**ZZ)) --google $x,$y,$z \
				--dpi $DPI $OUT/mask.vmap $mname.png
		# Извлечём маску
		convert $mname.png -fuzz 9% -transparent white -alpha extract $mname.bmp
		# Очистим всё помимо обратной маски
		composite -compose Plus \( -negate $mname.bmp \) $tname.png $tname.bmp
		# Создадим прозрачность по маске
		convert $tname.bmp $mname.bmp -alpha Off -compose CopyOpacity \
				-composite $tname.bmp
		rm $mname $mname.png $mname.bmp
	fi

	# Поделим большую плитку на маленькие и пересчитаем индексы
	if [ -f $tname.bmp ]; then
		convert $tname.bmp +gravity -crop 256x256 "${tname}_%d.png"
	else
		convert $tname.png +gravity -crop 256x256 "${tname}_%d.png"
	fi
	littlez=$((z + ZZ))
	for xi in `seq 0 $((2**ZZ - 1))`; do
		for yi in `seq 0 $((2**ZZ - 1))`; do
			fname="${tname}_$((yi * 2**ZZ + xi)).png"
			littlex=$((x * 2**ZZ + xi))
			littley=$((y * 2**ZZ + yi))
			littletile=" $littlex $littley $littlez "
			if [[ "$littletiles" =~ "$littletile" ]]; then
				# Уменьшим размер файла
				# pngquant ужимает файл в 3..4 раза
				pngquant $PNGQOPTS --skip-if-larger -f --ext .png $fname
				# advpng может сжать ещё процентов на 5, но [очень] долго
				if [ x$USEADVPNG == x1 ]; then
					advpng -z $ADVPNGOPTS $fname
				fi
				echo "Сохраняем плитку " $littlex,$littley,$littlez
				mv $fname $OUT/Z$littlez/${littlex}_${littley}.png
			else
				echo "Удаляем плитку   " $littlex,$littley,$littlez
				rm $fname
			fi
		done
	done
	rm -f $tname $tname.png $tname.bmp
}
export -f renderfunc

# Функция создания массивов с номерами нужных плиток
tilesarrays() 
{
	tz=$1

	# Получим список плиток пересекающих требуемые области
	tiles=`
		(
			(
				convs_gtiles -bi BRD/brd_main.plt $tz;
				convs_gtiles -bi BRD/brd_1.plt $tz;
				convs_gtiles -bi BRD/brd_2.plt $tz;
				convs_gtiles -bi BRD/brd_3.plt $tz;
			) | sort -n | uniq;
			convs_gtiles -bc BRD/brd_in.plt $tz
		) | sort -n | uniq -u | sed 's/^/ /;s/$/ /'`
	# Получим список плиток целиком лежащих в требуемых областях
	ftiles=`
		(
			(
				convs_gtiles -bc BRD/brd_main.plt $tz
				convs_gtiles -bc BRD/brd_1.plt $tz
				convs_gtiles -bc BRD/brd_2.plt $tz
				convs_gtiles -bc BRD/brd_3.plt $tz
				convs_gtiles -bi BRD/brd_in.plt $tz
			) | sort -n | uniq;
			convs_gtiles -bi BRD/brd_in.plt $tz
		) | sort -n | uniq -u | sed 's/^/ /;s/$/ /'`

	# Получим список плиток касающихся границ требуемых областей
	ptiles=`
		(
			echo "$tiles";
			echo "$ftiles";
		) | sort -b -n | uniq -u | sed 's/^/ /;s/$/ /'`
}

################################################################################

err=0

# Проверим отсутствие рабочей папку
if [ ! -d $VMAP_DIR ]; then
	echo Папка $OUT уже существует, удалите её
	err=1
fi
# Проверим наличие vmap_render
which vmap_render 1>/dev/null 2>&1 || {
	echo Поставьте пакет mapsoft
	err=1
}
# Проверим наличие pngquant
which pngquant 1>/dev/null 2>&1 || {
	echo Поставьте программу pngquant
	err=1
}
# Проверим наличие advpng, если он требуется
if [ x$USEADVPNG == x1 ]; then
	which advpng 1>/dev/null 2>&1 || {
		echo Поставьте программу advpng из пакета advancecomp \
				или отключите соответствующую опцию
		err=1
	}
fi
# Проверим наличие папки с картами
if [ ! -d $VMAP_DIR ]; then
	echo Отсутствует папка $VMAP_DIR
	err=1
fi
# Выйдем, если были ошибки
if [ $err -ne 0 ]; then
	echo Завершено с ошибками
	exit 1
fi

mkdir $OUT

# Создадим базы двух типов
sqlite3 $OUT/$SQLITEDB 'CREATE TABLE tiles (x int, y int, z int, image blob,
		PRIMARY KEY (x,y,z));'
sqlite3 $OUT/$MBTILES 'CREATE TABLE tiles (tile_column int, tile_row int,
		zoom_level int, tile_data blob,
		PRIMARY KEY (tile_column, tile_row, zoom_level));'

# Создадим карту с маской по границам
(
	echo VMAP 3.2
	echo -e "NAME\tMask"
	echo -e "RSCALE\t50000"
	echo -e "STYLE\tmmb"
	echo -e "MP_ID\t0"

	for fname in BRD/brd_main.plt BRD/brd_1.plt BRD/brd_2.plt \
			BRD/brd_3.plt BRD/brd_in.plt; do
		if [[ ! "$fname" =~ "brd_in" ]]; then
			# То, что включаем
			echo -e "OBJECT\t0x200016"
		else
			# То, что исключаем
			echo -e "OBJECT\t0x200052"
		fi
		echo -ne "  DATA\t"
		cat $fname | grep "^ " | awk -F, '
			{
				if (first2 == 0) first2 = $2;
				if (first1 == 0) first1 = $1;
				print "\t" $2*1000000 "," $1*1000000
			}
			END {
				print "\t" first2*1000000 "," first1*1000000
			}'
	done
) > $OUT/mask.vmap

for z in $TILESZ; do
	# Получим характерные для каждой карты диапазоны плиток.
	# Возможно, с некоторым запасом, но это не страшно
	unset maptiles
	unset mapnames
	declare -A maptiles
	# Приближение для больших агрегированных плиток
	bigz=$((z - ZZ))

	for mfile in `ls $VMAP_DIR/*vmap`; do
		# Координаты прямогольника, в который вмещается карта
		mrange=`grep "^BRD" $mfile |sed "s/^BRD//g" | xargs -n1 echo | awk -F, '
			BEGIN {xmin=200; ymin=200; xmax=-200; ymax=-200}
			{
				if ($1/1000000.0 > xmax) xmax = $1/1000000.0;
				if ($1/1000000.0 < xmin) xmin = $1/1000000.0;
				if ($2/1000000.0 > ymax) ymax = $2/1000000.0;
				if ($2/1000000.0 < ymin) ymin = $2/1000000.0;
			}
			END {print xmax - xmin "x" ymax - ymin "+" xmin "+" ymin}' | \
				sed "s/ //g;/^$/d"`
		# Координаты X и Y плиток, касающихся данного диапазона
		mtxx=`convs_gtiles -R $mrange $bigz |awk -F, '{ print $1 }' | sort|uniq`
		mtyy=`convs_gtiles -R $mrange $bigz |awk -F, '{ print $2 }' | sort|uniq`

		# Сохраним диапазоны в ассоциативный массив для передачи в функцию
		mname=`echo $mfile | sed -s "s|$VMAP_DIR/||g;s|\.vmap||g"`
		mapnames+="$mname "
		maptiles[${mname}_x]=`echo " "$mtxx" "`
		maptiles[${mname}_y]=`echo " "$mtyy" "`
	done
	declare -p maptiles >  $OUT/globalvars
	declare -p mapnames >> $OUT/globalvars

	tilesarrays $z
	littletiles="$tiles"
	# Через память много не пролезает, приходится писать в файл
	declare -p littletiles >> $OUT/globalvars
	tilesarrays $bigz

	mkdir -p $OUT/Z$z/
	# Отрисуем плитки с использованием увеличенного масштаба и, возможно, масок
	(echo "$ftiles"| xargs -r -n3 echo 0; echo "$ptiles"| xargs -r -n3 echo 1) |
			xargs -P$CPUNUM -n4 bash -c 'renderfunc "$@"' _

	# Запишем плитки в файл sqlitedb
	(
	echo 'PRAGMA journal_mode = OFF; PRAGMA synchronous = 0;'
	while read tile; do
		read x y z <<< $tile
		echo -n "INSERT INTO tiles (x, y, z, image) VALUES "
		echo     "($x, $y, $z, readfile('$OUT/Z$z/${x}_${y}.png'));"
	done ) <<< "$littletiles" | sqlite3 $OUT/$SQLITEDB

	# Запишем плитки в файл mbtiles
	(
	echo 'PRAGMA journal_mode = OFF; PRAGMA synchronous = 0;'
	while read tile; do
		read x y z <<< $tile
		echo -n "INSERT INTO tiles (tile_column, tile_row, "
		echo -n "zoom_level, tile_data) VALUES "
		echo    "($x, $((2**z-1-y)), $z, readfile('$OUT/Z$z/${x}_${y}.png'));"
	done ) <<< "$littletiles" | sqlite3 $OUT/$MBTILES

done

# Создадим ещё по одной нужной таблице в sqlitedb и mbtiles
sqlite3 $OUT/$SQLITEDB "CREATE TABLE info (tilenumbering text, minzoom int,
		maxzoom int);"
sqlite3 $OUT/$SQLITEDB "INSERT INTO info (tilenumbering, minzoom, maxzoom)
		VALUES ('', (SELECT min(z) FROM tiles), (SELECT max(z) FROM tiles))"
sqlite3 $OUT/$MBTILES "CREATE TABLE metadata (format text, minzoom int,
		maxzoom int);"
sqlite3 $OUT/$MBTILES "INSERT INTO metadata (format, minzoom, maxzoom)
		VALUES ('png', (SELECT min(zoom_level) FROM tiles),
		(SELECT max(zoom_level) FROM tiles))"

echo Готово!
