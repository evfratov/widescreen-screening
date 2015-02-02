# -*- coding: utf-8 -*-
#!/usr/env/python

import sys # парсинг коммандной строки
import time # задержка
import vk_api # https://github.com/python273/vk_api/
import pandas # pandas для работы с данными
import datetime # для работы с датами

# Задержка между запросами в секундах
SLEEP = 0.4

# целевые группы, выведем в один из файлов входных данных
GROUPS = [25438516, 10672563] # https://vk.com/androiddevelopers https://vk.com/appledev
# целевой пол
SEX = 'F'
# минимальный и максимальный возраст
MIN_AGE = 22
MAX_AGE = 28
# срок последней активности в днях
LAST_SEEN = 50
## значения отношений
# 1 – single
# 2 – in a relationship
# 3 – engaged
# 4 – married
# 5 – it's complicated* может быть с кем-то
# 6 – actively searching
# 7 – in love


# получение количества участников в группе
def getMembersCount(vk, group):
	values = {
		'group_id': group,
		'fields': 'members_count'
	}
	response = vk.method('groups.getById', values)
	membersCount = response[0]['members_count']
	return membersCount

# получение блока списка участников группы с определённым оффсетом		
def getMembersInGroup(vk, group, offset):
	values = {
		'group_id': group,
		'offset': offset,
		'fields': 'sex, bdate, city, country, last_seen, relation'
	}
	response = vk.method('groups.getMembers', values)
	return response['items']

# получение сырого списка участников всех групп
def work(vk):
	allMembers = []	
	for group in GROUPS:
		# пауза перед запросом чтобы не блочили метод
		time.sleep(SLEEP)
		
		# запрос на получение количество членов в группе
		membersCount = getMembersCount(vk, group)
		
		# получаем всех членов групп по блокам в 1000 за раз
		stepSize = int(membersCount / 1000)
		for s in range(0, stepSize+1):
			time.sleep(SLEEP)
			offset = s * 1000
			members = getMembersInGroup(vk, group, offset)
			allMembers += members
			
	# контрольный вывод количества
	print len(allMembers)
	return allMembers

# конверсия сырого списка пользователей в датафрейм
# вместе с первичным процессингом списка
def primaryFiltering(allMembers):
	tempData = []
	# конверсия в датафрейм
	tempData = pandas.DataFrame.from_dict(allMembers)
	
	## удаление ненужного пола
	# создание словаря с полами
	genderList = {'NaN': 0, 'F': 1, 'M': 2}
	# отбор строк только по подходящему полу
	tempData = tempData[tempData.sex == genderList[SEX]]
	# удаление уже не нужного столбца с полом
	del tempData['sex']
	
	## удаление заблокированных
	# удалить всех с не-NaN значением deactivated
	tempData = tempData[pandas.isnull(tempData.deactivated)]
	# удалить не нужную больше колонку deactivated
	del tempData['deactivated']
	
	## удаление людей в отношениях - китайский говнокод, но лень
	# удаление in a relationship
	tempData = tempData[tempData.relation != 2]
	# удаление engaged
	tempData = tempData[tempData.relation != 3]
	# удаление married
	tempData = tempData[tempData.relation != 4]
	# удаление in love
	tempData = tempData[tempData.relation != 7]
	# удаление тех, у кого есть кто-то в relation_partner - редкость
	tempData = tempData[pandas.isnull(tempData.relation_partner)]
	# удаление не нужной больше колонки про relation_partner
	del tempData['relation_partner']
	# заполнение значений NaN в поле relation нулями для удобства
	tempData.relation = tempData.relation.fillna(0)
	
	## нормализация полей city и country
	# извлечение названия городов и стран, срока последнего посещения
	tempData.city.loc[:][pandas.notnull(tempData.city.loc[:])] = tempData.city.loc[:][pandas.notnull(tempData.city.loc[:])].apply(lambda x: x['title'])
	tempData.country.loc[:][pandas.notnull(tempData.country.loc[:])] = tempData.country.loc[:][pandas.notnull(tempData.country.loc[:])].apply(lambda x: x['title'])
	# замещение NaN нулями городов и стран
	tempData.city = tempData.city.fillna(0)
	tempData.country = tempData.country.fillna(0)
	
	## фильтрация по last_seen и удаление более не нужной колонки
	# извлечение из суб-словаря времени последнего посещения
	tempData.last_seen = tempData.last_seen.apply(lambda x: x['time'])
	# конвертация времени в формат даты
	tempData.last_seen = pandas.to_datetime(tempData['last_seen'], unit = 's')
	# вычисление последнего срока и фильтрация
	tempData = tempData[tempData.last_seen.apply(lambda x: (datetime.datetime.today() - x).days) <= LAST_SEEN]
	del tempData['last_seen']
	
	## пересчёт полных дат рождения в возраст и фильтрация	
	# заполнение нулями NaN значений
	tempData.bdate = tempData.bdate.fillna(0)
	# инициализация поля возраста
	tempData['age'] = 0
	# отбор полных возрастов в суб-датафреймы
	tempDataFullbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 7]
	tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
	# конверсия в формат дат
	tempDataFullbdate.bdate = tempDataFullbdate.bdate.convert_objects(convert_dates = 'coerce')
	# вычисление возраста и фильтрация
	tempDataFullbdate['age'] = tempDataFullbdate.bdate.apply(lambda x: round((datetime.datetime.today() - x).days/365, 1))
	tempDataFullbdate = tempDataFullbdate[tempDataFullbdate.age >= MIN_AGE]
	tempDataFullbdate = tempDataFullbdate[tempDataFullbdate.age <= MAX_AGE]
	# слияние в обратно в целый датафрейм
	tempData = tempDataStrictbdate.append(tempDataFullbdate)
	
	## вычисление Т-коэффициента и удаление дубликатов
	# чистый от дубликатов датафрейм
	finalData = tempData.drop_duplicates()	
	# вычисление Tcoeff
	TcoeffData = tempData.id.value_counts()
	TcoeffData = TcoeffData.to_frame(name = 'Tcoeff')
	# сортировка и объединение в конечный датафрейм
	finalData = finalData.sort('id')	
	TcoeffData = TcoeffData.sort_index()
	finalData['Tcoeff'] = TcoeffData.values
	
	return finalData

# учёт файла-базы для RAE
def RAEaccounting(primaryCandidatsTable):
	dataFile = pandas.DataFrame.from_csv('Dropbox/evfr/MAIN/LSS/branch_two/RAE_database.tab', sep = ';', index_col = False)
	
	
	return

# поиск пользователей по имени-фамилии с лимитами возраста для RAE
def RAESearch(vk, candidate):
	# формирование запроса и функции для поиска
	query = candidate.first_name + ' ' + candidate.last_name
	values = {
		'q': query,
		'count': 1000,
		'age_from': MIN_AGE,
		'age_to': MAX_AGE
	}
	# большой тайм-аут потому что метод блочат легко
	time.sleep(8)
	response = vk.method ('users.search', values)
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

# реверсивная оценка возраста в случае урезанной даты рождения
def reverseAgeEstimate(primaryCandidatsTable):
	tempData = primaryCandidatsTable
	finalData = pandas.DataFrame()
	# отбор пользователей с урезанными, но указанными датами
	tempData = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 2]
	tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
	# цикл проверки присутствия в результатах поиска
	for n in range(len (tempDataStrictbdate)):
		candidate = tempDataStrictbdate.iloc[n]
		if(RAESearch(candidate)):
			# установить условный возраст как минимум - 1
			candidate['age'] = MIN_AGE - 1
			finalData = finalData.append(candidate)
	## сборка полного датафрейма обратно
	# набор пустых возрастов
	tempData = primaryCandidatsTable[primaryCandidatsTable.bdate.apply(lambda x: len(str(x))) == 1]
	# набор полных возрастов
	tempData = tempData.append(primaryCandidatsTable[primaryCandidatsTable.bdate.apply(lambda x: len(str(x))) > 6])
	# сборка и возвращение датафрейма
	finalData = finalData.append(tempData)
	return finalData

### мастер-функция
def main():
	# парсинг аргументов командной строки
	login, password = sys.argv[0], sys.argv[1]
	
	# TODO: нормально получать токен и не передавать логин с паролем
	try:
		vk = vk_api().VkApi(login, password)  # Авторизируемся
	except vk_api.AuthorizationError as error_msg:
		print(error_msg)  # В случае ошибки выведем сообщение
	return  # и выйдем
	
	# получение списка пользователей
	allMembers = work(vk)
	# пред-обработка и конверсия списка в первичную таблицу кандидаток
	primaryCandidatsTable = primaryFiltering(allMembers)
	# вывод первичной таблицы в файл
	fl = open ('/tmp/primaryCandidats.csv', 'w')
	primaryCandidatsTable.to_csv(fl, index = False, sep = ';')
	fl.close()
	# реверсивная оценка возраста
#	RAEcandidatsList = reverseAgeEstimate(primaryCandidatsTable)
	

# исполнение мастер-функции
if __name__ == '__main__':
	main()
