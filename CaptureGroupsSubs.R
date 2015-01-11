# инициализировать колонку в selected под число групп
selected$ngroups <- rep(0, nrow(selected))

# пробегание цикла по всем идентификаторам пользователей
for (uid in selected$uid) {
	# формирование имени файла для сохранения XML данных списка групп
  filename <- paste0('/tmp/groups-', uid, '.xml')
	# задание 5 попыток на скачивание файла
  attempts <- 5
	# инициализация счётчика попыток
  att <- 0
	# выжидание паузы 0,4 с перед веб-запросом
  Sys.sleep(0.4)
	# запрос по методу groups.get с user_id ID пользователя, флагом extended и токеном,
	# сохранение результата в файл filename
  download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', uid, '&extended=1', '&access_token=', token), destfile = filename, method='wget', quiet = T)
	# цикл while на условие нулевого размера файла filename, т.е. если нет ответа сервера
  while (file.info(filename)$size == 0) {
		# пауза перед запросом
	Sys.sleep(0.4)
		# повторный веб-запрос
	download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', uid, '&extended=1', '&access_token=', token), destfile = filename, method='wget', quiet = T)
		# увеличение счётчика попыток
	att <- att + 1
		# число попыток достигла максимального числа попыток?
	if (att == attempts) {
			# да, достигло - прерываем цикл
			# а дальше срывается парсинг и происходит ошибка исполнения WSS, ибо с сетью проблемы или забанили
		break
	}
  }
	# парсинг XML файла
  xmldata <- xmlParse(filename)
	# конвертация в data frame
  extend <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)))
	# проверка на ненулёвость вывода
  if (ncol(extend) != 1) {
		# убрать первый столбец и строку
	extend <- extend[-1,-1]
		# оставить только первые 3 столбца: в них идентификатор группы, короткое имя группы для ссылки и отображаемое имя группы
	extend <- extend[, 1:3]
		# записать число групп в ngroups для данного пользователя
	selected[selected$uid == uid,]$ngroups <- nrow(extend)
  }
	# контрольный вывод числа групп
  print(paste(uid, selected[selected$uid == uid,]$ngroups))
	# удаление XML - файла
  file.remove(filename)
	# сохранение списка групп данного пользователя в "раздел" контейнера-словаря groups под ключом id<идентификатор пользователя>
  CorrData[['groups']][[paste0('id', uid)]] <- extend
}
