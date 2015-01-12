## инициализация переменных для метаданных стен
# число постов
selected$wallsize <- rep(0, nrow(selected))
# суммарный размер в тыс. символов
selected$comkchars <- rep(0, nrow(selected))

# инициализация счётчика
count <- 1
# пробегание цикла по всем пользователям
for (uid in selected$uid) {
	# загрузка информации о стене - посчёт числа коментов
  filename <- paste0('/tmp/wall-', uid, '.txt')
	# скачивание за 5 попыток
  attempts <- 5
	# инициализация счётчика попыток
  att <- 0
	# пауза перед веб-запросом
  Sys.sleep(0.4)
	# веб-запрос по методу wall.get к пользователю uid в количестве count 1 коммент (нужна инфа о стене, а не сами коменты), с полем filter = owner (посты и перепосты только от пользователя) и токен,
	# скачивание в конечный файл /tmp/wall-<uid>.txt
  download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = T)
	# цикл while с проверкой на ненулёвость размера файла
  while (file.info(filename)$size == 0) {
		# пауза перед веб-запросом
    Sys.sleep(0.4)
		# повторный аналогичный веб-запрос
    download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = T)
		# увеличение счётчика попыток
    att <- att + 1
		# проверка на достижение максимального числа попыток скачивания
    if (att == attempts) {
			# достижение максимального числа попыток скачивания - прерывание программы, ибо всё хреново
		break
	}
  }
	# парсинг JSON
  tmp <- fromJSON(file = filename)
	# конвертация JSON файла в data frame с извлечением нужной переменной (числа постов) "на месте"
  tmpdata <- do.call("rbind.fill", lapply(tmp$response[[1]], function(x) as.data.frame(x, stringsAsFactors = F)))
	# преобразование текстовой величины в числовую
  ncomments <- as.numeric(tmpdata)
  # проверка на адекватность (если длина 0 - то постов нет)
  if (length(ncomments) == 0) {
		# обнуление числа постов
    ncomments <- 0
  }
	# вывод числа постов
  print(paste('N', count, uid, 'size', ncomments, 'posts'))
	# сохранение числа постов в главную таблицу selected
  selected[selected$uid == uid, 'wallsize'] <- ncomments
	# увеличение счётчика проанализированных пользователей
  count <- count + 1
}

## загрузка постов только для стен, больше чем 5
# инициализация счётчика
count <- 1
# цикл по всем пользователям с размером стен > 5
for (uid in selected[selected$wallsize > 5, 'uid']) {
	# вызов значения числа комментов
  ncomments <- selected[selected$uid == uid, 'wallsize']
	# инициализация временной переменной
  tmpdata <- c()
	# цикл по числу блоков стены по 80 постов для блочной загрузки (максимум 100 постов можно вызвать)
  for (k in 1:ceiling(ncomments/80)) {
		# инициализация лимита попыток скачки
    attempts <- 5
		# инициализация счётчика числа попыток
    att <- 0
		# сборка имени файла для скачанного блока постов как /tmp/wall-block-<uid>-<k>.txt
    filename <- paste0('/tmp/wall-block-', uid, '-', k, '.txt')
		# вывод имени файла
    print(filename)
		# задержка перед веб-запросом
    Sys.sleep(0.4)
		# веб-запрос по методу wall.get к пользователю uid с count = 80, полем filter = owner и offset = 80 * (k - 1)
		# с токеном. Соохранение в файл filename
    download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=80', '&filter=owner', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
		# цикл с проверкой ненулёвости размера файла filename
    while (file.info(filename)$size == 0) {
			# пауза перед веб-запросом
      Sys.sleep(0.4)
			# повторение веб-запроса
      download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=80', '&filter=owner', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = F)
			# увеличение счётчика повторов веб-запросов
      att <- att + 1
			# проверка на критичность числа веб-запросов
		if (att == attempts) {
				# прерывание исполнения программы если слишком много безответных запросов
			break
		}
    }
		# парсинг блочного файла
    tmp <- fromJSON(file = filename)
		# конвертация в списки векторов
    tmp <- sapply(tmp$response, function(x) unlist(x))
		# выбор только тех элементов листа, где есть поле text
    tmp <- tmp[sapply(sapply(sapply(tmp, names), function(x) x == 'text'), sum) == 1]
		# извлечение собственно текста поста
    tmp <- sapply(tmp, function(x) x[['text']])
		# удаление NA
    tmp <- tmp[!is.na(tmp)]
		# удаление пустых текстов
    tmp <- tmp[!tmp == '']
		# добавка данных во временный вектор
    tmpdata <- c(tmpdata, tmp)
  }
	# сохранение массива текстов пользователя в раздел словаря-хранилища 'wall' под названием id<uid>
  CorrData[['wall']][[paste0('id', uid)]] <- tmpdata
	# сохранение значения размера в тыс. символов
  comkchar <- round(sum(nchar(tmpdata))/1000, 1)
  selected[selected$uid == uid, 'comkchars'] <- comkchar
	# диагностический вывод
  print(paste('N', uid, count, 'size', comkchar, 'kchars'))
	# увеличение счётчика обработанных
  count <- count + 1
}
