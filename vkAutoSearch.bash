#!/bin/bash


#var='transcyber thuman immortalism kriorus2006 club42502313'
targets=$1
outPrefix='vkDB-'
token=$2 ###

for group in $targets
do
	echo ' Group:	' $group
	wget 'https://api.vk.com/method/groups.getById.xml?group_id='$group'&fields=members_count' -O ~/$group.txt -o /dev/null
	string=`grep -P -o 'members_count>\d+' ~/$group.txt`
	string=${string/members_count>/}
	echo '	members:	' $string
	rm ~/$group.txt
	step=`echo $string' / 1000 ' | bc`
	echo $step
	for count in `seq 0 $step`
	do
		wget 'https://api.vk.com/method/groups.getMembers.xml?group_id='$group'&offset='$count'000&fields=sex,bdate,city,country,education,last_seen,relation&access_token='$token -O $outPrefix$count-$group'.txt'
	done
done
