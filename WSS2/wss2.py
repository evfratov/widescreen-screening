# -*- coding: utf-8 -*-

import vk_api # https://github.com/python273/vk_api/
import argparse # парсинг аргументов командной строки
import time # задержка

# Задержка между запросами в секундах
# у меня все работает с нулевой задержкой.
# Видимо, она есть в SDK.
# Позже можно поменять
SLEEP = 0

# целевые группы
GROUPS = [25438516, 10672563] # https://vk.com/androiddevelopers https://vk.com/appledev

# получение количества участников в группе
def getMembersCount(vk, group):
	values = {
		'group_id': group,
		'fields': 'members_count'
	}
	response = vk.method('groups.getById', values)
	membersCount = response[0]['members_count']
	return membersCount

# получение списка участников группы с определённым оффсетом		
def getMembersInGroup(vk, group, offset):
	values = {
		'group_id': group,
		'offset': offset,
		'fields': 'sex,bdate,city,country,last_seen,relation'
	}
	response = vk.method('groups.getMembers', values)
	return response['items']

def work(vk):
	allMembers = []	
	for group in GROUPS:
		# пауза перед запросом чтобы не забанили на vk
		time.sleep(SLEEP)
		
		# запрос на получение количество членов в группе
		# в принципе, можно получить количество участников
		# одним запросом, но пока
		# пусть всё будет как в оригинальной версии
		membersCount = getMembersCount(vk, group)
		stepSize = membersCount / 1000

		# получаем всех членов групп, по тому же самому принципу,
		# что и в изначальной версии
		for s in range(0, stepSize+1):
			time.sleep(SLEEP)
			offset = s * 1000
			members = getMembersInGroup(vk, group, offset)
			allMembers += members
	
	# тут это нужно всё загдать в датафрейм,
	# пока просто вывожу количество
	# TODO: загнать в датафрейм
	print len(allMembers)
		
		

def main():
	# парсинг аргументов командной строки
    parser = argparse.ArgumentParser()
    parser.add_argument("--login", action="store")
    parser.add_argument("--password", action="store")
    args = parser.parse_args()

    login, password = args.login, args.password

	# логин, судя по всему, с использованием логина и пароля,
	# access_token не нужен
    try:
        vk = vk_api.VkApi(login, password)  # Авторизируемся
    except vk_api.AuthorizationError as error_msg:
        print(error_msg)  # В случае ошибки выведем сообщение
        return  # и выйдем
                
    work(vk)

if __name__ == '__main__':
    main()