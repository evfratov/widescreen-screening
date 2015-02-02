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

# получение доступа к методам
vk = vk_api.VkApi(token = '5d6cf6357e32b7293aa5bda5e9f6923659f1ba506fd4f7c2029fc4cddc4a9f8d188c02f7ed530f280b566')

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
primaryData = pandas.DataFrame.from_csv('Dropbox/evfr/MAIN/LSS/branch_two/primaryCandidats.csv', sep = ';', index_col = False)
tempData = primaryData
finalData = pandas.DataFrame()
# отбор пользователей с урезанными, но указанными датами
tempData = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 2]
tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
# цикл проверки присутствия в результатах поиска и вывод в файл
fl = open('Dropbox/evfr/MAIN/LSS/branch_two/RAE_database.tab', 'w')
fl.write("id;range\n")
for n in range(len (tempDataStrictbdate)):
	candidate = tempDataStrictbdate.iloc[n]
	res = RAESearch(candidate)
	print str(candidate.id) + ";" + str(res)
	fl.write(str(candidate.id) + ";" + str(res) + "\n")

fl.close()
