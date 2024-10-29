#!/bin/bash

###########################################
# Script para backup local das bases  de  #
# dados do servidor.                      #
# Autor: <f6036477> Juno Roesler          #
# Data: 2020-01-28                        #
###########################################

MYUSER=mysql_backup
MYPASS=FudEbwqOuMoB
MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump
BKPDIR=/backup/mysql/local
# Tempo maximo em dias que um arquivo de backup permanece antes 
# de ser removido.
MAX_OLD_FILE=5

# Retorna a data atual formatada (yyyy-MM-dd)
function curdate() {
	echo $(date +'%Y-%m-%d')
}


# Retorna a data e hora atual formatada (yyyy-MM-dd HH:mm:ss)
function curdatetime() {
	echo $(date +'%Y-%m-%d %H:%M:%S')
}


# Faz log da mensagem informada no stdout.
# Formato do log: '* INF [<timestamp>] <message>
# {$1} Mensagem do log
function log() {
	msg=$1
	curdate=$(curdatetime)
	echo "* INF [$curdate] $msg"
}


# Faz log da mensagem de erro informada no stderr.
# Formato do log: '# ERR [<timestamp>] <message>
# {$1} Mensagem do log
function err() {
	msg=$1
	curdate=$(curdatetime)
	>&2 echo "# ERR [$curdate] $msg"
}


# Executa um comando, realizando log apropriado em caso de erro
# {$1} Comando a ser executado
function try() {
	myerr=$(sh -c "$1" 2>&1 > /dev/null)
	myerr=$(echo "$myerr" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	myerr=$(echo "$myerr" | tr -d "'" | tr -d '"')
	if [ ! -z "$myerr" ]; then
		err "$myerr"
	fi
}


# Remove arquivos com a extensao 'csv.gz', que tenham mais de 3 dias (MAX_OLD_FILE).
# {$1} Nome do diretorio (dentro de BKPDIR) onde os arquivos serao removidos.
function deleteOldFiles() {
	log "Removendo arquivos antigos: $1..."
	if [ -e "$BKPFILE/$1" ]; then
		#find $BKPDIR/$1/*.csv.gz -mtime +$MAX_OLD_FILE -exec rm -f {} \;
		find $BKPDIR/$1/ -regex '.*\.csv\.gz' -mtime +$MAX_OLD_FILE -exec rm -f {} \;
	fi
}


# Exporta a estrutura da view informada no servidor local
# na pasta definida em $BKPDIR.
# {$1} Nome do schema
# {$2} Nome da view
function exportViewStruct() {
        log "Exportando view '$1.$2'..."
        dir="$BKPDIR/$1"
        oldfile="$dir/view_$2_old.sql"
        if [ -e "$oldfile" ]; then
                rm "$oldfile"
        fi
        bkpfile="$dir/view_$2.sql"
        if [ -e "$bkpfile" ]; then
                mv "$bkpfile" "$oldfile"
        fi
	sql="select CONCAT('CREATE OR REPLACE VIEW ', TABLE_SCHEMA, '.', TABLE_NAME, ' AS ', VIEW_DEFINITION, '; ') from information_schema.views where table_schema = '$1' and table_name = '$2'"
        dump="$MYSQL -u$MYUSER -p$MYPASS --batch -e \"$sql\" > $bkpfile"
        try "$dump"
        chmod 775 $bkpfile 1> /dev/null 2> /dev/null
}


# Exporta a estrutura do schema/tabela informados no servidor local
# na pasta definida em $BKPDIR.
# {$1} Nome do schema
# {$2} Nome da tabela
function exportTableStruct() {
        log "Exportando estrutura '$1.$2'..."
        dir="$BKPDIR/$1"
        if [ ! -e "$dir" ]; then
                mkdir "$dir"
		chown -R mysql.mysql "$dir" > /dev/null
		chmod -R 775 "$dir" > /dev/null
        fi
        oldfile="$dir/$2_struct_old.sql"
        if [ -e "$oldfile" ]; then
                rm "$oldfile"
        fi
        bkpfile="$dir/$2_struct.sql"
        if [ -e "$bkpfile" ]; then
                mv "$bkpfile" "$oldfile"
        fi
        dump="$MYSQLDUMP -u$MYUSER -p$MYPASS -d --skip-lock-tables --skip-triggers $1 $2 > $bkpfile"
        try "$dump"
        chmod 775 $bkpfile 1> /dev/null 2> /dev/null
}



# Exporta os dados da tabela informada no servidor local para 
# o arquivo 'csv' na pasta definida em $BKPDIR.
# {$1} Nome do schema
# {$2} Nome da tabela
function exportTableData() {
	log "Exportando dados '$1.$2'..."
	curdate=$(curdate)
	bkpfile="$BKPDIR/$1/$2_$curdate.csv"
	gzfile="$BKPDIR/$1/$2_$curdate.csv.gz"
	if [ -e "$bkpfile" ]; then
		rm "$bkpfile"
	fi
	dump="$MYSQL -u$MYUSER -p$MYPASS -e \"select * into outfile '$bkpfile' fields terminated by ';' optionally enclosed by '\\\"' lines terminated by '\n' from $1.$2\""
	try "$dump"
	if [ ! -e "$bkpfile" ]; then
		err "FILE NOT CREATED: $bkpfile"
		if [ -z "$msg" ]; then
			msg="Error creating data file: $bkpfile"
		fi
		return 1
	fi
	cat "$bkpfile" | gzip > "$gzfile"
	rm "$bkpfile"
	try "chmod 775 $gzfile"
}


# Exporta a estrutura de rotinas (triggers, procedures, functions and events) de um schema no servidor local
# na pasta definida em $BKPDIR.
# {$1} Nome do schema
function exportRoutines() {
	log "Exportando procedures/events '$1'..."
        curdate=$(curdate)
        bkpfile="$BKPDIR/$1/routines_$curdate.struct.sql"
        gzfile="$BKPDIR/$1/routines_$curdate.struct.sql.gz"
	if [ -e "$bkpfile" ]; then
		rm "$bkpfile"
	fi
        dump="$MYSQLDUMP --default-character-set=utf8 -u$MYUSER -p$MYPASS --routines --events --no-create-info --no-data --no-create-db --compact $1 > $bkpfile"
	try "$dump"
	if [ ! -e "$bkpfile" ]; then
		err "FILE NOT CREATED: $bkpfile"
		if [ -z "$msg" ]; then
			msg="Error creating routines file: $bkpfile"
		fi
		return 1
	fi
	cat "$bkpfile" | gzip > "$gzfile"
	rm "$bkpfile"
	try "chmod 775 $gzfile"
}


log "Efetuando Backup de todos os schemas para '$BKPDIR'..."

schemas=$($MYSQL -u$MYUSER -p$MYPASS -e "show databases")
for s in $schemas
do
	if [[ $s == information_schema || $s == performance_schema || $s == mysql || $s == Database || $s == temp || $s == TEMP ]]; then
		continue;
	fi
	dir="$BKPDIR/$s"
        if [ ! -e "$dir" ]; then
		log "Configurando diretorio '$dir'..."
                mkdir "$dir"
                try "chown -R mysql.mysql $dir"
                try "chmod -R 777 $dir"
        fi

	deleteOldFiles $s

        views=$($MYSQL -u$MYUSER -p$MYPASS --skip-column-names --batch -e "select table_name from information_schema.tables where table_type = 'VIEW' and table_schema = '$s'")
        for v in $views
        do
                exportViewStruct $s $v
        done

	tables=$($MYSQL -u$MYUSER -p$MYPASS --skip-column-names --batch -e "select table_name from information_schema.tables where table_type != 'VIEW' and table_schema = '$s'")
	for t in $tables
	do
		if [[ $t == Tables_in* ]]; then
			continue;
		fi
		exportTableStruct $s $t
		exportTableData $s $t
	done
	exportRoutines $s
done

log "Backup Concluido!"

