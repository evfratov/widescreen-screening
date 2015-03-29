# -*- coding: utf-8 -*-
#!/usr/env/python
"""
Created on Sun Feb  1 23:15:57 2015

@author: evfr
"""

import sys # парсинг коммандной строки
import time # задержка
import vk_api # https://github.com/python273/vk_api/
import pandas # pandas для работы с данными

# минимальный и максимальный возраст
MIN_AGE = 22
MAX_AGE = 28

# рабочая папка
WORK_DIR = 'Dropbox/evfr/LSS/branch_two/'
#WORK_DIR = 'Dropbox/evfr/LSS/branch_one/'


# получение доступа к методам
token_value = sys.argv[1]
vk = vk_api.VkApi(token = token_value, app_id = 4315528)

# поиск пользователей по имени-фамилии с лимитами возраста для RAE
def RAESearch(candidate):
	# формирование запроса и функции для поиска
	query = str(candidate.first_name) + ' ' + str(candidate.last_name)
	values = {
		'q': query,
		'count': 1000,
		'age_from': MIN_AGE,
		'age_to': MAX_AGE
	}
	# большой тайм-аут потому что метод блочат легко
	time.sleep(8)
	print "\t" + query
	response = vk.method('users.search', values)
	# выполнение поиска и парсинг
	result = False
	if response['count'] > 0 :
		result = int(candidate.id) in map(lambda x: x['id'], response['items'])
	else:
		result = False
	# возвращение результата +- и информирующий вывод
	if result:
		print 'For ID ' + str(candidate.id) + ' age in range.'
	else:
		print 'For ID ' + str(candidate.id) + ' age unmatch.'
	return result	

# чтение первичного списка кандидаток
primaryData = pandas.DataFrame.from_csv((WORK_DIR + 'primaryCandidats.csv'), sep = ';', index_col = False)
tempData = primaryData
print ' Read primary data: ' + str(len(tempData)) + ' users'
finalData = pandas.DataFrame()
# отбор пользователей с урезанными, но указанными датами
tempData = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 2]
tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
print ' For searching: ' + str(len(tempDataStrictbdate)) + ' users'
# цикл проверки присутствия в результатах поиска и вывод в файл
fl = open((WORK_DIR + 'RAE_database.tab'), 'w')
fl.write("id;range\n")
for n in range(len (tempDataStrictbdate)):
	candidate = tempDataStrictbdate.iloc[n]
	res = RAESearch(candidate)
#	print str(candidate.id) + ";" + str(res)
	fl.write(str(candidate.id) + ";" + str(res) + "\n")

fl.close()
