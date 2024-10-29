#!/bin/bash

#########################################
#  Script para execucao, controle e     #
#  monitoramento de rotinas.            #
#   - Registro e log em banco de dados  #
#   - Monitoramento via grafana         #
#   Autor: f6036477 - Juno Roesler      #
#########################################

routine="$1"
help=0

if [ "$1" = "-h" -o "$1" = "--help" ]; then
        routine=""
        help=1
fi

function showHelp {
        echo -e "\
######################################### \n\
#  Script para execucao, controle e     # \n\
#  monitoramento de rotinas.            # \n\
#   - Registro e log em banco de dados  # \n\
#   - Monitoramento via grafana         # \n\
#   Autor: f6036477 - Juno Roesler      # \n\
######################################### \n\
  Uso: rx.sh [opcoes] <rotina> [opcoes_rotina] \n\
  Opcoes: \n\
    -n/--nohup: Invoca a rotina com o comando nohup \n\
    -h/--help : Exibe este texto de uso \n"
}

if [ $help -eq 1 ]; then
	showHelp
	exit 0
elif [ -z "$routine" ]; then
	showHelp
	>&2 echo -e "[ERRO] Uso incorreto: caminho da rotina ausente\n"
	exit 2
fi

MYSQL="/usr/bin/mysql"
MYHOST="10.2.97.131"
MYUSER="grafana"
MYPASS="hWBEB4fsNkJI"
PIPEDIR="/tmp"
LOGDIR="/dados/logs"
export JAVA_HOME="/dados/java/jdk1.8.0_121"
export CLASSPATH=".:/dados/java/jdk1.8.0_121/jre/lib"

name=$(basename $routine)
name=${name%.*}
#Get routine id from db
#echo "* sql=select id from grafana.routine where name = '$name'"
routine_id=$($MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "select id from grafana.routine where name = '$name'")
ipaddr=$(ping -c 1 $(hostname) | grep PING | cut -d'(' -f2 | cut -d')' -f1)
if [ -z "$routine_id" ]; then
        #Create routine id
        cron=""
        line="$(crontab -l | grep $name | head -1)"
        i=1
        while [ $i -le 5 ]; do
        	set -o noglob
                fld=$(echo $line | cut -d ' ' -f $i)
                cron="$cron $fld"
        	set +o noglob
                i=$((i+1))
        done
	#echo "* sql=insert into grafana.routine (name, path, host, crontab) values ('$name', '$routine', '$ipaddr', '$cron')"
        $MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "insert into grafana.routine (name, path, host, crontab) values ('$name', '$routine', '$ipaddr', '$cron')"
	#echo "* sql=select max(id) from grafana.routine where name = '$name'"
        routine_id=$($MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "select max(id) from grafana.routine where name = '$name'")
fi

for arg in $@; do
        if [ "$arg" != "$routine" ]; then
                routine="$routine $arg"
        fi
done

errpipe="$PIPEDIR/__xx__"$name"__.err"
logfile="$LOGDIR/"$name"_$(date +%Y-%m-%d).log"
mkfifo $errpipe
$routine 1> $logfile 2> $errpipe &
pid=$!

#Send start and pid to db
#echo "* sql=insert into grafana.exec_log (routine_id, pid) values ($routine_id, $pid)"
$MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "insert into grafana.exec_log (routine_id, pid) values ($routine_id, $pid)"
#echo "* sql=select max(id) from grafana.exec_log where routine_id = $routine_id"
exec_id=$($MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "select max(id) from grafana.exec_log where routine_id = $routine_id")

#Read pipe and send errors to db log
while IFS= read -r ln
do
        #echo "* sql=insert into grafana.error_log (routine_id, exec_id, log_msg) values ($routine_id, $exec_id, '$ln')"
        $MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "insert into grafana.error_log (routine_id, exec_id, log_msg) values ($routine_id, $exec_id, '$ln')"
done < "$errpipe"
wait $pid
qterr=$($MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "select count(*) from grafana.error_log where exec_id = $exec_id")
#echo "* pid=$pid; qterr=$qterr"

#Send stop and exit code to db
#echo "* sql=update grafana.exec_log set ts_stop = now(), error_count = $qterr where id = $exec_id"
$MYSQL -u$MYUSER -p$MYPASS -h$MYHOST -B -N -e "update grafana.exec_log set ts_stop = now(), error_count = $qterr where id = $exec_id"

rm -f $errpipe

