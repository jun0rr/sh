#!/bin/bash
USER='rtin_arh_dipes'
PASS='mA7PEibbX51xP9gJ'
HOST='172.16.12.168'
MYSQL=$(which mysql)

for i in {1..10}; do
	ids=($($MYSQL -u$USER -p$PASS -B -e 'show processlist;' | grep -v 'system user' | grep -v 'event_scheduler' | grep -v 'Id' | sed -r -n 's/(^[0-9]+).*/\1/p'))
	for id in ${ids[@]}; do
		$MYSQL -u$USER -p$PASS -B -e "kill $id;"
	done
	echo "--> $(date +'%Y-%m-%d %H:%M:%S') $i"
	sleep 60
done

