#!/bin/bash

###########################################
# Script para backup e restore das bases  #
# de dados do servidor.                   #
# Autor: <f6036477> Juno Roesler          #
# Data: 2020-06-17                        #
###########################################

MODE=""
USER=""
PASS=""
HOST="localhost"
FORMAT="sql"
SCHEMA=""
TABLE=""
OUTDIR="./"
OPT_STRUCT=0
OPT_DATA=0
OPT_VIEW=0
OPT_ROUTINES=0
OPT_USERS=0
OPT_GZIP=0
OPT_HELP=0
OPT_QUIET=0
OPT_TRUNCATE=0
LAST_OPT=""

MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump

for arg in "$@"
do
	if [[ "$arg" == "backup" || "$arg" == "restore" ]]; then
		MODE="$arg"
	elif [[ "$arg" == "-a" ]]; then
		OPT_TRUNCATE=1
	elif [[ "$arg" == "-d" ]]; then
		OPT_DATA=1
	elif [[ "$arg" == "-c" ]]; then
		OPT_STRUCT=1
	elif [[ "$arg" == "-g" ]]; then
		OPT_GZIP=1
	elif [[ "$arg" == "-v" ]]; then
		OPT_VIEW=1
	elif [[ "$arg" == "-r" ]]; then
		OPT_ROUTINES=1
	elif [[ "$arg" == "-e" ]]; then
		OPT_USERS=1
	elif [[ "$arg" == "-q" ]]; then
		OPT_QUIET=1
	elif [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
		OPT_HELP=1
	elif [[ "$LAST_OPT" == "-u" ]]; then
		USER="$arg"
	elif [[ "$LAST_OPT" == "-o" ]]; then
		OUTDIR="$arg"
	elif [[ "$LAST_OPT" == "-p" ]]; then
		PASS="$arg"
	elif [[ "$LAST_OPT" == "-h" ]]; then
		HOST="$arg"
	elif [[ "$LAST_OPT" == "-f" ]]; then
		FORMAT="$arg"
	elif [[ "$LAST_OPT" == "-s" ]]; then
		SCHEMA="$arg"
	elif [[ "$LAST_OPT" == "-t" ]]; then
		TABLE="$arg"
	fi
	LAST_OPT="$arg"
done


# Retorna a data atual formatada (yyyy-MM-dd)
function curdate() {
	echo $(date +'%Y-%m-%d')
}


# Retorna a data e hora atual formatada (yyyy-MM-dd HH:mm:ss)
function curdatetime() {
	echo $(date +'%Y-%m-%d %H:%M:%S')
}


# Faz log da mensagem informada no stdout.
# Formato do log: '* INF [timestamp] <message>
# {$1} Mensagem do log
function log() {
	msg=$1
	curdate=$(curdatetime)
	if [[ $OPT_QUIET -ne 1 ]]; then
		echo "* INF [$curdate] $msg"
	fi
}


# Faz log da mensagem de erro informada no stderr.
# Formato do log: '# ERR [<timestamp>] <message>
# {$1} Mensagem do log
function err() {
	msg=$1
	curdate=$(curdatetime)
	>&2 echo "# ERR [$curdate] $msg"
}


function printUsage() {
	echo "###########################################"
	echo "# mybak_tool: Script for backup/restore   #"
	echo "# databases (mariadb/mysql).              #"
	echo "# Autor: Juno Roesler                     #"
	echo "#        <juno.roesler@bb.com.br>         #"
	echo "# 2020-06-17                              #"
	echo "###########################################"
	echo " Usage: mybak_tool.sh <mode> [options]"
	echo "   Modes:"
	echo "     * backup : Create backup files of databases structures and data. "
	echo "     * restore: Restore backup files of databases structures and data. "
	echo "   Options:"
	echo "     -a: Truncate tables before restore data"
	echo "     -c: Backup/restore tables/views structures"
	echo "     -d: Backup/restore tables/views data"
	echo "     -e: Backup/restore user privileges"
 	echo "     -f <sql|csv>: Data input/output format (default sql by mysqldump)"
 	echo "     -g: Compress backup files in gzip (default no compression)"
	echo "     -h <host>: Database host (default localhost)"
	echo "     -o <dir>: Output directory"
	echo "     -p <password>: Database password"
	echo "     -q: Quiet!"
	echo "     -r: Backup/restore routines (triggers, procedures, functions and events)"
	echo "     -s <schema>: Select schemas to backup (multiple separated by ',')"
	echo "     -t <table/view>: Select tables/views to backup (multiple separated by ',')"
	echo "     -u <user>: Database username"
	echo "     -v: Create backup of views"
	echo "   Global Options:"
	echo "     -h/--help: Print this usage help"
}



# Exporta a estrutura da view informada no servidor local
# na pasta definida em $BKPDIR.
# {$1} Nome do schema
# {$2} Nome da view
function exportViewStruct() {
	curdate=$(curdate)
	if [ ! -e "$OUTDIR/$1" ]; then
		mkdir "$OUTDIR/$1"
	fi
	bkpfile="$OUTDIR/$1/view_$2_$curdate.struct.sql"
	gzfile="$BKPDIR/$1/view_$2_$curdate.struct.sql.gz"
        log "Exporting view structure: $bkpfile"
        if [ -e "$bkpfile" ]; then
                rm "$bkpfile"
        fi
	sql="select CONCAT('CREATE OR REPLACE VIEW ', TABLE_SCHEMA, '.', TABLE_NAME, ' AS ', VIEW_DEFINITION, '; ') from information_schema.views where table_schema = '$1' and table_name = '$2'"
        $MYSQL --default-character-set=utf8 --skip-column-names -u$USER -p$PASS -h$HOST --batch -e "$sql" > $bkpfile
	if [[ $OPT_GZIP -eq 1 ]]; then
		gzip $bkpfile
	fi
}


# Exporta a estrutura de rotinas (triggers, procedures, functions and events) de um schema no servidor local
# na pasta definida em $BKPDIR.
# {$1} Nome do schema
function exportRoutines() {
	curdate=$(curdate)
	bkpfile="$OUTDIR/$1/routines_$curdate.struct.sql"
	gzfile="$BKPDIR/$1/routines_$curdate.struct.sql.gz"
	if [[ $OPT_QUIET -ne 1 ]]; then
        	log "Exporting routines: $bkpfile"
	fi
        dir="$BKPDIR/$1"
        if [ -e "$bkpfile" ]; then
                rm "$bkpfile"
        fi
        $MYSQLDUMP --default-character-set=utf8 -u$USER -p$PASS -h$HOST --routines --events --no-create-info --no-data --no-create-db --compact $1 > $bkpfile
	if [[ $OPT_GZIP -eq 1 ]]; then
		gzip $bkpfile
	fi
}


# Exporta a estrutura do schema/tabela informados no servidor local.
# {$1} Nome do schema
# {$2} Nome da tabela
function exportTableStruct() {
	curdate=$(curdate)
	bkpfile="$OUTDIR/$1/$2_$curdate.struct.sql"
	gzfile="$BKPDIR/$1/$2_$curdate.struct.gz"
       	log "Exporting table structure: $bkpfile"
        if [ -e "$bkpfile" ]; then
                rm "$bkpfile"
        fi
        $MYSQLDUMP --default-character-set=utf8 -u$USER -p$PASS -h$HOST -d --skip-lock-tables --skip-triggers $1 $2 > $bkpfile
	if [[ $OPT_GZIP -eq 1 ]]; then
		gzip $bkpfile
	fi
}


# Exporta os dados da tabela/view para arquivo de acordo com o formato especificado (-f).
# {$1} Nome do schema
# {$2} Nome da tabela
function exportTableData() {
	curdate=$(curdate)
	bkpfile="$OUTDIR/$1/$2_$curdate.$FORMAT"
	gzfile="$BKPDIR/$1/$2_$curdate.$FORMAT.gz"
       	log "Exporting table data: $bkpfile"
        if [ -e "$bkpfile" ]; then
                rm "$bkpfile"
        fi
	if [[ "$FORMAT" == "csv" ]]; then
		$MYSQL --default-character-set=utf8 -u$USER -p$PASS -h$HOST -B -e "select * from $1.$2;" | sed "s/'/\'/;s/\t/\"\;\"/g;s/^/\"/;s/$/\"/;s/\n//g" > $bkpfile
	else
		$MYSQLDUMP -u$USER -p$PASS -h$HOST --default-character-set=utf8 --single-transaction --skip-lock-tables --no-create-info --skip-triggers --no-create-db $1 $2 > $bkpfile
	fi
	if [[ $OPT_GZIP -eq 1 ]]; then
		gzip $bkpfile
	fi
}


# Encontra o arquivo de backup mais recente com o nome do schema e tabela informados.
# {$1} Nome da pasta/schema com os arquivos de backup.
# {$2} Nome da tabela/prefixo do arquivo de backup.
# {$3} <struct|data> Informe <struct> para buscar arquivos de estruturas, ou <data> para arquivos de dados.
# RETURN Caminho do arquivo mais recente.
function findLastestFile() {
	fname="$2_[0-9]{4}-[0-9]{2}-[0-9]{2}\.$FORMAT(\.gz)?"
	if [[ "$3" == "struct" ]]; then
		fname="$2_[0-9]{4}-[0-9]{2}-[0-9]{2}\.struct\.$FORMAT(\.gz)?"
	fi
	files=$(find "$OUTDIR/$1/" -regextype posix-extended -regex "$OUTDIR/$1/$fname")
        lasttime=10800
        for f in $files
        do
                fdate=$(echo $f | grep -E -o "[0-9]{4}-[0-9]{2}-[0-9]{2}")
                ftime=$(date -d "$fdate" +'%s')
                if [ $ftime -gt $lasttime ]; then
                        lasttime=$ftime
			fname="$f"
                fi
        done
        echo "$fname"
}


# Recupera a estrutura da tabela de um arquivo sql, recriando no banco de dados.
# {$1} Nome do schema
# {$2} Nome da tabela
function restoreTableStruct() {
	bkpfile=$(findLastestFile $1 $2 struct)
	if [ ! -e "$bkpfile" ]; then
		err "Bad backup file: $bkpfile do not exists"
		return 2	
	fi
	rmfile=""
	if [[ $bkpfile =~ .*\.gz$ ]]; then
		rmfile=$(echo $bkpfile | sed "s;.gz;;g")
		cat $bkpfile | gzip -d > $rmfile
		bkpfile="$rmfile"
	fi
	log "Restoring structure to database: $bkpfile"
	if [[ $(cat $bkpfile | head -1) != "use $1;" ]]; then
		sed -i "1s|^|use $1;\n|" $bkpfile
	fi
	$MYSQL -u$USER -p$PASS -h$HOST < $bkpfile
	if [[ ! -z "$rmfile" && -e "$rmfile" ]]; then
		rm "$rmfile"
	fi
}


# Recupera os dados da tabela de um arquivo para o banco de dados.
# {$1} Nome do schema
# {$2} Nome da tabela
function restoreTableData() {
	bkpfile=$(findLastestFile $1 $2 data)
	if [ ! -e "$bkpfile" ]; then
		err "Bad backup file: $bkpfile do not exists"
		return 2
	fi
	if [[ ! $2 =~ ^view_.+ ]]; then
		log "Restoring backup file to database: $bkpfile"
		rmfile=""
		if [[ $bkpfile =~ .*\.gz$ ]]; then
			rmfile=$(echo $bkpfile | sed "s;.gz;;g")
			cat $bkpfile | gzip -d > $rmfile
			bkpfile="$rmfile"
		fi
		if [[ $OPT_TRUNCATE -eq 1 ]]; then
			$MYSQL -u$USER -p$PASS -h$HOST -e "truncate table $1.$2;"
		fi
		if [[ $(cat $bkpfile | head -1) != "use $1;" ]]; then
			sed -i "1s|^|use $1;\n|" $bkpfile
		fi
		$MYSQL -u$USER -p$PASS -h$HOST < $bkpfile
		if [[ ! -z "$rmfile" && -e "$rmfile" ]]; then
			rm "$rmfile"
		fi
	fi
}


# Determina se a tabela/view informada éuma view
# ($1} Nome do schema
# {$2} Nome da tabela/view
# {return 1|0}
function isView() {
	sql="select TABLE_TYPE = 'VIEW' from information_schema.tables where TABLE_NAME = '$2' and table_schema = '$1';"
	isv=$(mysql -u$USER -p$PASS -h$HOST -s --default-character-set=utf8 --batch -e "$sql" | cut -d \n -f 2)
	echo $isv
}


ERRMSG=""
if [[ "$MODE" != "backup" && "$MODE" != "restore" ]]; then
	if [ $OPT_HELP -eq 1 ]; then
		printUsage
		exit 0
	fi
	ERRMSG="Bad <mode> ($MODE)"
fi
if [ -z "$USER" ]; then 
	ERRSMG="Bad database username"
fi
if [ -z "$PASS" ]; then 
	ERRMSG="Bad database password"
fi
if [[ -z "$SCHEMA" && ! -z "$TABLE" ]]; then 
	ERRMSG="Bad arguments: Missing schema option (-s)"
fi
if [ ! -e "$OUTDIR" ]; then 
	ERRMSG="Bad output directory: '$OUTDIR' don't exists"
fi
if [[ $OPT_STRUCT -eq 0 && $OPT_DATA -eq 0 && $OPT_ROUTINES -eq 0 && $OPT_USERS -eq 0 ]]; then
	ERRMSG="Bad arguments: Missing backup option (-c, -d, -r, -e)"
fi
if [[ $FORMAT != "sql" && $FORMAT != "csv" ]]; then
	ERRMSG="Bad format: $FORMAT (sql|csv)"
fi
if [ ! -z "$ERRMSG" ]; then
	if [[ $OPT_QUIET -ne 1 ]]; then
		printUsage
		echo " "
	fi
	err "$ERRMSG"
	exit 2
fi


if [[ "$MODE" == "backup" ]]; then
	log "Starting database $MODE..."

	if [[ $OPT_USERS -eq 1 ]]; then
		$MYSQL -u$USER -p$PASS -h$HOST -e"select concat('show grants for ','\'',user,'\'@\'',host,'\'') from mysql.user" > "$OUTDIR/user_list_with_header.txt"
		sed '1d' user_list_with_header.txt > "$OUTDIR/user.txt"
		while read user; do  $MYSQL -u$USER -p$PASS -h$HOST -e"$user" > "$OUTDIR/user_grant.txt"; sed '1d' "$OUTDIR/user_grant.txt" >> "$OUTDIR/user_privileges.txt"; echo "flush privileges" >> "$OUTDIR/user_privileges.txt"; done < "$OUTDIR/user.txt"
		awk '{print $0";"}'  "$OUTDIR/user_privileges.txt" > "$OUTDIR/user_privileges.sql"
		rm "$OUTDIR/user.txt" "$OUTDIR/user_list_with_header.txt" "$OUTDIR/user_grant.txt" "$OUTDIR/user_privileges.txt"
	fi

	if [ -z "$SCHEMA" ]; then
		if [[ $OPT_DATA -eq 1 || $OPT_STRUCT -eq 1 || $OPT_ROUTINES -eq 1 ]]; then
			SCHEMA=$($MYSQL --default-character-set=utf8 -u$USER -p$PASS -h$HOST --skip-column-names --batch -e "show databases;")
		fi
	else
		SCHEMA=$(echo $SCHEMA | sed "s/,/ /g")
	fi

	for s in $(echo $SCHEMA | sed "s/,/ /g")
	do
		if [[ $s == information_schema || $s == performance_schema || $s == mysql || $s == Database || $s == temp || $s == TEMP ]]; then
			continue;
		fi
		VIEW=""
		if [ -z "$TABLE" ]; then
			sel="select table_name from information_schema.tables where table_type != 'VIEW' and table_schema = '$s'"
			TABLE=$($MYSQL --default-character-set=utf8 -u$USER -p$PASS -h$HOST --skip-column-names --batch -e "$sel")
			if [[ $OPT_VIEW -eq 1 ]]; then
				sel="select table_name from information_schema.tables where table_type = 'VIEW' and table_schema = '$s'"
				TABLE="$TABLE "$($MYSQL --default-character-set=utf8 -u$USER -p$PASS -h$HOST --skip-column-names --batch -e "$sel")
			fi
		else
			TABLE=$(echo $TABLE | sed "s/,/ /g")
		fi

		dir="$OUTDIR/$s"
	        if [ ! -e "$dir" ]; then
			log "Configurando diretorio '$dir'..."
                	mkdir "$dir"
        	        chmod -R 777 $dir
	        fi

		for t in $TABLE
		do
			if [[ $t == Tables_in* ]]; then
				continue;
			fi
		
			isview=$(isView $s $t)
			if [[ $OPT_STRUCT -eq 1 ]]; then
				if [[ $isview -eq 1 && $OPT_VIEW -eq 1 ]]; then
					exportViewStruct $s $t
				else
					exportTableStruct $s $t
				fi
			fi
			if [[ $OPT_DATA -eq 1 && $isview -ne 1 ]]; then
				exportTableData $s $t
			fi
		done

		if [[ $OPT_ROUTINES -eq 1 ]]; then
			exportRoutines $s
		fi
	done

# restore mode
else
	if [[ $OPT_USERS -eq 1 && -e "$OUTDIR/user_privileges.sql" ]]; then 
		$MYSQL -u$USER -p$PASS -h$HOST < "$OUTDIR/user_privileges.sql"
	fi

	for s in $(echo $SCHEMA | sed "s/,/ /g")
	do
		log "Restoring database: $s"
		$MYSQL -u$USER -p$PASS -h$HOST --default-character-set=utf8 -e "create database if not exists $s;"
		fsufix=".*"
		if [[ $OPT_STRUCT -eq 1 ]]; then
			fsufix="_[0-9]{4}-[0-9]{2}-[0-9]{2}\.struct\.sql(\.gz)?"
        else
			fsufix="_[0-9]{4}-[0-9]{2}-[0-9]{2}\.$FORMAT(\.gz)?"
		fi
		if [ -z "$TABLE" ]; then
			TABLE=$(find "$OUTDIR/$s" -regextype posix-extended -regex "$OUTDIR/$s/.+$fsufix" | sed -E "s;$fsufix;;g" | sed "s;$OUTDIR/$s/;;g" | sort | uniq)
		else 
			TABLE=$(echo $TABLE | sed "s/,/ /g")
		fi
		for t in $TABLE
		do
			if [[ "$t" == view_* || "$t" == "routines" ]]; then
				continue;
			fi
			if [[ $OPT_STRUCT -eq 1 ]]; then
				restoreTableStruct $s $t
			fi
			if [[ $OPT_DATA -eq 1 ]]; then
				restoreTableData $s $t
			fi
		done 
		for t in $TABLE
		do
			if [[ "$t" != view_* && "$t" != "routines" ]]; then
				continue;
			fi
			if [[ $OPT_VIEW -eq 1 && "$t" == view_* ]]; then
				restoreTableStruct $s $t
			elif [[ $OPT_ROUTINES -eq 1 && "$t" == "routines" ]]; then
				restoreTableStruct $s $t
			fi
		done 
	done
fi





