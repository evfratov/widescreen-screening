#!/bin/bash

# permissions: 2+4+2048+128+1024+8192+262144+4096+1048576
# https://oauth.vk.com/authorize?client_id=4315528&scope=1326214&redirect_uri=https://oauth.vk.com/blank.html&display=page&v=5.21&response_type=token

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
		wget 'https://api.vk.com/method/groups.getMembers.xml?group_id='$group'&offset='$count'000&fields=sex,bdate,city,country,education,last_seen,relation,photo_max_orig&access_token='$token -O $outPrefix$count-$group'.txt'
	done
done
