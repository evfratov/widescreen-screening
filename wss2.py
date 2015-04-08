# -*- coding: utf-8 -*-
#!/usr/env/python

import sys # парсинг коммандной строки
import time # задержка
import vk_api # https://github.com/python273/vk_api/
import numpy # для вычислений
import pandas # pandas для работы с данными
import datetime # для работы с датами
import pickle # для сохранения данных
import scipy
#import matplotlib.pyplot as plt # для графики

# Задержка между запросами в секундах
SLEEP = 0.4

# парсинг аргументов командной строки
token_value = sys.argv[1]

# целевые группы
#GROUPS = [25438516, 10672563] # https://vk.com/androiddevelopers https://vk.com/appledev
WORK_DIR = 'Dropbox/evfr/LSS/branch_two/'
#WORK_DIR = 'Dropbox/evfr/MAIN/LSS/branch_one/'
#GROUPS_LIST = 'Dropbox/evfr/MAIN/LSS/branch_two/groupsDB_B2.txt'
GROUPS_LIST = WORK_DIR + 'groupsDB_B2.txt'
TFREND_LIST = WORK_DIR + 'Tfriends_list-Vk.tab'
BLACK_LIST = WORK_DIR + 'BlackList.tab'
DATA_FOLDER = 'dataLSS/'
# целевой пол
SEX = 'F'
# минимальный и максимальный возраст
MIN_AGE = 22
MAX_AGE = 28
# срок последней активности в днях
LAST_SEEN = 50
# максимальное число групп, друзей и подписчиков
MAX_FRIENDS = 1000
MAX_GROUPS = 1000
MAX_FOLLOWERS = 1000
## значения отношений
# 1 – single
# 2 – in a relationship
# 3 – engaged
# 4 – married
# 5 – it's complicated* может быть с кем-то
# 6 – actively searching
# 7 – in love

# чтение файла с группами
def readGroups(GROUPS_LIST):
	with open(GROUPS_LIST) as fl:
		groups = fl.read().splitlines()
	return groups

# получение количества участников в группе
def getMembersCount(vk, group):
	values = {
		'group_id': group,
		'fields': 'members_count'
	}
	response = vk.method('groups.getById', values)
	membersCount = response[0]['members_count']
	print ' Group ' + str(group) + ' has ' + str(membersCount) + ' members.'
	return membersCount

# получение блока списка участников группы с определённым оффсетом		
def getMembersInGroup(vk, group, offset):
	values = {
		'group_id': group,
		'offset': offset,
		'fields': 'sex, bdate, city, country, last_seen, relation, photo_200_orig'
	}
	response = vk.method('groups.getMembers', values)
	return response['items']

# получение сырого списка участников всех групп
def work(vk):
	allMembers = []
	groups = readGroups(GROUPS_LIST)
	for group in groups:
		# пауза перед запросом чтобы не блочили метод
		time.sleep(SLEEP)
		
		# запрос на получение количество членов в группе
		membersCount = getMembersCount(vk, group)
		
		# получаем всех членов групп по блокам в 1000 за раз
		stepSize = int(membersCount / 1000)
		for s in range(0, stepSize+1):
			time.sleep(SLEEP)
			offset = s * 1000
			print ' Get users for grpoup ' + str(group) + ' with offset ' + str(offset)
			members = getMembersInGroup(vk, group, offset)
			allMembers += members
			
	# контрольный вывод количества
	print ' Totally captured ' + str(len(allMembers)) + ' members.'
	return allMembers

## создание словаря с полами
genderList = {'NaN': 0, 'F': 1, 'M': 2}

# применение фильтра с чёрным списком
def blackListFilter(tempData, BLACK_LIST):
	# чтение файла чёрного списка
	blackListData = pandas.read_csv(BLACK_LIST, sep = '\t')
	# вычитание ID чёрного листа из первичной таблицы
	tempData = tempData[tempData.id.isin(set(tempData.id.values) - set(blackListData.uid.values))]
	return tempData

# конверсия сырого списка пользователей в датафрейм
# вместе с первичным процессингом списка
def primaryFiltering(allMembers):
	# конверсия в датафрейм
	tempData = pandas.DataFrame.from_dict(allMembers)
	
	# применение фильтра чёрного списка
	tempData = blackListFilter(tempData, BLACK_LIST)
	
	## удаление ненужного пола
	# отбор строк только по подходящему полу
	tempData = tempData[tempData.sex == genderList[SEX]]
	print ' Deleted unmatch gender, left ' + str(len(tempData))
	# удаление уже не нужного столбца с полом
	del tempData['sex']
	
	
	## удаление заблокированных
	# удалить всех с не-NaN значением deactivated
	tempData = tempData[pandas.isnull(tempData.deactivated)]
	# удалить всех с http://vk.com/images/deactivated_200.gif фото для компенсации задержек обновления состояния
	tempData = tempData[tempData.photo_200_orig != 'http://vk.com/images/deactivated_200.gif']
	print ' Deleted deactivated users, left ' + str(len(tempData))
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
	print ' Deleted users in a relationship, left ' + str(len(tempData))
	del tempData['relation_partner']
	# заполнение значений NaN в поле relation нулями для удобства
	tempData.relation = tempData.relation.fillna(0)
	
	## нормализация полей city и country
	# извлечение названия городов и стран, срока последнего посещения
	tempData.loc[pandas.notnull(tempData.city.loc[:]), 'city'] = tempData.loc[pandas.notnull(tempData.city.loc[:]), 'city'].apply(lambda x: x['title'])
	tempData.loc[pandas.notnull(tempData.country.loc[:]), 'country'] = tempData.loc[pandas.notnull(tempData.country.loc[:]), 'country'].apply(lambda x: x['title'])
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
	print ' Deleted inactive users, left ' + str(len(tempData))
	del tempData['last_seen']
	
	## пересчёт полных дат рождения в возраст и фильтрация	
	# заполнение нулями NaN значений
	tempData.bdate = tempData.bdate.fillna(0)
	# инициализация поля возраста
	tempData.loc[:, 'age'] = 0
	# отбор полных возрастов в суб-датафреймы
	tempDataFullbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 7]
	tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
	# конверсия в формат дат
	tempDataFullbdate.bdate = tempDataFullbdate.bdate.convert_objects(convert_dates = 'coerce')
	# вычисление возраста и фильтрация
	tempDataFullbdate.loc[:, 'age'] = tempDataFullbdate.bdate.apply(lambda x: round((datetime.datetime.today() - x).days/365, 1))
	tempDataFullbdate = tempDataFullbdate[tempDataFullbdate.age >= MIN_AGE]
	tempDataFullbdate = tempDataFullbdate[tempDataFullbdate.age <= MAX_AGE]
	# слияние в обратно в целый датафрейм
	tempData = tempDataStrictbdate.append(tempDataFullbdate)
	print ' Deleted unmatch aged users, left ' + str(len(tempData))
	
	## вычисление Т-коэффициента и удаление дубликатов
	# чистый от дубликатов датафрейм
	finalData = tempData.drop_duplicates()
	print ' Deleted duplicated users, left ' + str(len(finalData))
	# вычисление Tcoeff
	TcoeffData = tempData.id.value_counts()
	TcoeffData = TcoeffData.to_frame(name = 'Tcoeff')
	# сортировка и объединение в конечный датафрейм
	finalData = finalData.sort('id')	
	TcoeffData = TcoeffData.sort_index()
	finalData.loc[:, 'Tcoeff'] = TcoeffData.values
	print ' Stats for T-coefficient:'
	print finalData.Tcoeff.value_counts()
	
	return finalData


# учёт файла-базы для RAE удаление range == False и присвоение возраста MAX-1 для True
def RAEaccounting(tempDataStrictbdate):
	# прочитать файл-базу с +- результатами поиска
	dataFile = pandas.DataFrame.from_csv( (WORK_DIR + 'RAE_database.tab'), sep = ';', index_col = False)
	print ' In RAEbase ' +  str(len(dataFile)) + ' users'
	# получить индекс в главном датафрейме всех из базы
	index = tempDataStrictbdate.id.isin(dataFile.id)
	print ' ' + str(index.sum()) + ' are known'
	# отделить пользователей в базе
	InBase = tempDataStrictbdate[index]
	# и пользователей не в базе
	notInBase = tempDataStrictbdate[index == False]
	print ' ' + str(len(notInBase)) + ' in residue'
	# отбор из базы только подходящих из проверенных
	InBase = InBase[InBase.id.isin(dataFile.id[dataFile.range == True])]
	print ' Matched by age ' + str(len(InBase))
	# присвоение суб-порогового возраста для подходящих
	InBase.loc[:, 'age'] = MIN_AGE - 1
	# сборка финального датафрейма (проверенные + не из базы) для вывода	
	tempDataStrictbdate = InBase.append(notInBase)
	
	return tempDataStrictbdate

# поиск пользователей по имени-фамилии с лимитами возраста для RAE
def RAESearch(vk, candidate):
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
	response = vk.method ('users.search', values)
	# выполнение поиска и парсинг
	result = False
	if response['count'] > 0 :
		result = int(candidate.id) in map(lambda x: x['id'], response['items'])
	else:
		result = False
	# возвращение результата +- и информирующий вывод
	if result:
		print ' For ID ' + str(candidate.id) + ' age in range'
	else:
		print ' For ID ' + str(candidate.id) + ' age unmatch'
	return result	

# реверсивная оценка возраста в случае урезанной даты рождения
def reverseAgeEstimate(primaryCandidatsTable, vk):
	tempData = primaryCandidatsTable
	finalData = pandas.DataFrame()
	# отбор пользователей с урезанными, но указанными датами
	tempData = tempData[tempData.bdate.apply(lambda x: len(str(x))) > 2]
	tempDataStrictbdate = tempData[tempData.bdate.apply(lambda x: len(str(x))) < 7]
	# учёт базы данных RAE для tempDataStrictbdate
	tempDataStrictbdate = RAEaccounting(tempDataStrictbdate)
	# проверка на необходимость RAE-поиска для не из базы
	if (len(tempDataStrictbdate) > 0):
		# цикл проверки присутствия в результатах поиска
		for n in range(len (tempDataStrictbdate)):
			candidate = tempDataStrictbdate.iloc[n]
			# проверка на наличие в базе по суб-пороговому возрасту
			if(candidate.age != (MIN_AGE - 1)):
				# выполнение поиска
				print '	Searching of ' + str(candidate.id) + ' user...'
				result = RAESearch(vk, candidate)
				# интерпретация при положительном результате
				if(result):
					# установить условный возраст как минимум - 1
					candidate.loc['age'] = MIN_AGE - 1
					finalData = finalData.append(candidate)
					print '	Match'
				else:
					print '	Unmatch'
	else: 
		print ' RAEdb up to date! nobody for RAEsearch'
	## сборка полного датафрейма обратно
	# набор пустых возрастов
	tempData = primaryCandidatsTable[primaryCandidatsTable.bdate.apply(lambda x: len(str(x))) == 1]
	# набор полных возрастов
	tempData = tempData.append(primaryCandidatsTable[primaryCandidatsTable.bdate.apply(lambda x: len(str(x))) > 6])
	# сборка и возвращение датафрейма
	finalData = finalData.append(tempData)
	
	return finalData

# получение числа групп и подписчиков
def countGroupsFollowers(RAEcandidatsList, vk, DATA_FOLDER):
	# инициализация новых колонок
	RAEcandidatsList['groups'] = 0
	RAEcandidatsList['followers'] = 0
	# инициализация хранилища данных групп
	tempData = {}
	# перебор по всем пользователям
	for n in range(len(RAEcandidatsList)):
		candidate = RAEcandidatsList.iloc[n]
		# формирование запроса
		values = {
			'user_id': int(candidate.id),
			'count': 1000
		}
		# пауза
		time.sleep(SLEEP)
		# запрос количества групп
		try:
			response = vk.method('groups.get', values)
		except:
			response = {'count': 0}
		# запись результата количества групп
		RAEcandidatsList.groups.iloc[n] = response['count']
		# проверка на превышение максимального значения числа групп
		if (RAEcandidatsList.groups.iloc[n] < MAX_GROUPS):
			# запись списка групп для пользователя с преобразованием ответа в датафрейм
			tempData[int(candidate.id)] = pandas.DataFrame.from_dict(response['items'])
			# запрос числа подписчиков, только если число групп не превышено
			values = {
				'user_id': int(candidate.id),
				'count': 1
				}
			time.sleep(SLEEP)
			# запись во временные данные
			try:
				response = vk.method('users.getFollowers', values)
			except:
				response = {'count': 0}
			RAEcandidatsList.followers.iloc[n] = response['count']
			if (RAEcandidatsList.groups.iloc[n] >= MAX_GROUPS):
				# удаление из базы данных списки групп пользователей со слишком большим числом подписчиков
				del tempData[int(candidate.id)]
		# диагностический вывод
		print ' For ' + str(int(candidate.id)) + ' groups: ' + str(RAEcandidatsList.iloc[n]['groups']) + ' followers: ' + str(RAEcandidatsList.iloc[n]['followers'])
	
	# удаление пользователей со слишком большим числом групп и подписчиков
	print ' Removed ' + str(sum(RAEcandidatsList.groups > MAX_GROUPS)) + ' users with too many groups'
	RAEcandidatsList = RAEcandidatsList[RAEcandidatsList.groups <= MAX_GROUPS]
	print ' Removed ' + str(sum(RAEcandidatsList.followers > MAX_FOLLOWERS)) + ' users with too many followers'
	RAEcandidatsList = RAEcandidatsList[RAEcandidatsList.followers <= MAX_FOLLOWERS]
	
	# вывод данных о группах в txt-pkl файл 
	with open ((DATA_FOLDER + 'dataGroups.pkl'), 'w') as datafl:
		pickle.dump(tempData, datafl)
	
	return (RAEcandidatsList, tempData)

# получение списка друзей с подсчётом числа в главной таблице и выводом хранилища данных с данными френдов
def captureFrinds(candidatsList, vk, DATA_FOLDER):
	# инициализация новых колонок
	candidatsList['friends'] = 0
	candidatsList['Svalue'] = 0
	candidatsList['MedianAge'] = 0
	candidatsList['ModeAge'] = 0
	candidatsList['MeanAge'] = 0
	candidatsList['SDAge'] = 0
	# инициализация хранилища данных друзей
	tempData = {}
	# перебор по всем пользователям
	for n in range(len(candidatsList)):
		candidate = candidatsList.iloc[n]
		# формирование запроса для получения списка с инфой друзей
		values = {
			'user_id': int(candidate.id),
			'count': 1000,
			'fields': 'sex,bdate'
			}
		# пауза
		time.sleep(SLEEP)
		# запрос списка друзей
		try:
			response = vk.method('friends.get', values)
		except:
			response = {'count': 0}
		# запись результата числа друзей
		candidatsList.friends.iloc[n] = response['count']
		if (response['count'] > 0 ) & (response['count'] <= MAX_FRIENDS):
			# преобразование в датафрейм
			temp = pandas.DataFrame.from_dict(response['items'])
			del temp['online']
			# сохранение списка друзей в хранилище
			tempData[int(candidate.id)] = temp
			# подсчёт доли целевого пола в друзьях
			candidatsList.Svalue.iloc[n] = sum(temp.sex == genderList[SEX]) / len(temp)
			# проверка на наличие даты рождения
			if ('bdate' in list(temp.columns)):
				# отбор друзей с полным возрастом	
				tempFullbdate = temp[temp.bdate.apply(lambda x: len(str(x))) > 7]
				if len(tempFullbdate) > 3:
					# силовая конверсия в возраст
					tempFullbdate.loc[:, 'bdate'] = pandas.to_datetime(tempFullbdate.bdate, coerce = True)
					# удаление некорректных дат
					tempFullbdate = tempFullbdate[tempFullbdate.bdate.notnull()]
					# повторная проверка
					if len(tempFullbdate) > 3:
						friendsAges = tempFullbdate.bdate.apply(lambda x: round((datetime.datetime.today() - x).days/365, 1))
						# вычисление медианного возраста
						candidatsList.MedianAge.iloc[n] = numpy.median(friendsAges)
						# вычисление среднего возраста
						candidatsList.MeanAge.iloc[n] = numpy.mean(friendsAges)
						# вычисление моды возраста
						candidatsList.ModeAge.iloc[n] = scipy.stats.mode(friendsAges)[0][0]
						# вычисление SD
						candidatsList.SDAge.iloc[n] = numpy.std(friendsAges)
		# диагностический вывод
		print ' For ' + str(int(candidate.id)) + ' ' + str(candidatsList.friends.iloc[n]) + ' friends ' + 'Svalue ' + str(round(candidatsList.Svalue.iloc[n], 2)) + ' ModeAge ' + str(round(candidatsList.ModeAge.iloc[n], 2))
	# удаление пользователей со слишком большим числом друзей
	print ' Deleted ' + str(sum(candidatsList.friends > MAX_FRIENDS)) + ' users who have too many frinds'
	candidatsList = candidatsList[candidatsList.friends <= MAX_FRIENDS]
	# вывод данных о группах в pkl файл 
	with open ((DATA_FOLDER + 'dataFriends.pkl'), 'w') as datafl:
		pickle.dump(tempData, datafl)
	
	return (candidatsList, tempData)

# запрос списка ID Т-френдов по именам из фалйа
def getI_ID(vk):
	# чтение списка имён Т-френдов
	rawTFrends = readGroups(TFREND_LIST)
	# запрос выдачи данных пользователей
	values = {
		'user_ids': ','.join(rawTFrends)
	}
	# пауза
	time.sleep(SLEEP)
	response = vk.method('users.get', values)
	# преобразование в датафрейм с извлечением только ID
	TidList = pandas.DataFrame.from_dict(response)['id']
	# конверсия в массив чисел
	TidList = TidList.values
	
	return TidList

# подсчёт числа Т-френдов
def Tfriends_counting(candidatsList, TidList, dataBase):
	# инициализация новой колонки
	candidatsList['Tfriends'] = 0
	# перебор всех пользователей
	for n in range(len(candidatsList)):
		# получение id
		uid = int(candidatsList.iloc[n].id)
		if (candidatsList.iloc[n].friends > 0):
			# получение Т-друзей пользователя
			overlapFreinds = set(TidList) & set(dataBase['friends'][uid].id.values)
			# подсчёт и сохранение
			candidatsList.Tfriends.iloc[n] = len(overlapFreinds)
	print 'Tfriends	Number'
	print candidatsList.Tfriends.value_counts()
	
	return candidatsList

### мастер-функция
def main():
	# получение доступа к методам через токен
	vk = vk_api.VkApi(token = token_value, app_id = 4315528)
	
	### получение сырого списка участников всех групп
	allMembers = work(vk)
	# пред-обработка и конверсия списка в первичную таблицу кандидаток
	primaryCandidatsTable = primaryFiltering(allMembers)
	# вывод первичной таблицы в файл
	fl = open ( (WORK_DIR + 'primaryCandidats.csv'), 'w')
	primaryCandidatsTable.to_csv(fl, index = False, sep = ';')
	fl.close()
	
	### реверсивная оценка возраста, иногда обновлять RAE-DB - RAEUpdate.py
	RAEcandidatsList = reverseAgeEstimate(primaryCandidatsTable, vk)
	
	# инициализация хранилища данных
	dataBase = {}
	# получение числа и числа подписчиков
	candidatsList, dataBase['groups'] = countGroupsFollowers(RAEcandidatsList, vk, DATA_FOLDER)
	# подсчёт, получение и процессинг списка друзей в хранилище данных
	candidatsList, dataBase['friends'] = captureFrinds(candidatsList, vk, DATA_FOLDER)
	
	### определение числа Т-френдов
	# получение списка Т-френдов
	TidList = getI_ID(vk)
	# подсчёт
	candidatsList = Tfriends_counting(candidatsList, TidList, dataBase)
	
	# сохранение результатов - смещать по мере написания
	fl = open ((WORK_DIR + 'candidatsList.csv'), 'w')
	candidatsList.to_csv(fl, index = False, sep = ';')
	fl.close()
	
	return candidatsList

# исполнение мастер-функции
if __name__ == '__main__':
	main()
