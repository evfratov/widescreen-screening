# пауза между запросами в с
time.threshold <- 1
# число скачиваемых фото
photos <- 20

## загрузка фотографий с формированием альбомов в каталоге
# создать главную папку
dir.create(path = '~/PhotoCapture')
# пробегание цикла по всем идентификаторам
for (uid in selected$uid) {
	# формирование имени файла ответа на запрос об альбомах
  filename <- paste0('/tmp/photo-', uid, '.txt')
	# пауза перед запросом
  Sys.sleep(1)
	# запрос по методу photos.get к пользователю uid с параметрами album_id = profile для получения списков фоток альбома профиля числом photos и токен
  download.file(url = paste0('https://api.vk.com/method/photos.get?owner_id=', uid, '&album_id=profile', '&count=', photos, '&access_token=', token), destfile = filename, method='curl', quiet = T)
	# парсинг JSON файла
  tmp <- fromJSON(file = filename)$response
	# получение ссылок на фото размера src_big, в новом API заменить надо на photo_604 и pid на id
  tmp <- sapply(tmp, function(x) unlist(x)[c('pid', 'src_big')])
  
	## загрузка фотографий со сброркой альбома
	# создать подкаталог с именем uid
  curDir <- paste0('~/PhotoCapture/', uid)
  dir.create(path = curDir)
	# проверка на ненулёвость ответа
  if (length(tmp) > 0) {
		# при ненулевой длине пробежаться по всем строкам
    for (n in 1:ncol(tmp)) {
			# получить ссылку на фотку
      link <- tmp['src_big', n]
			# получить идентификатор фотки
      pid <- tmp['pid', n]
			# подождать перед запросом
      Sys.sleep(time.threshold)
			# сформировать полное имя фйла для загрузки
      outfile <- paste0(curDir, '/', pid, '.jpg')
			# скачивать файл с кучей доп. параметров для curl ибо работает как говно
      download.file(url = link, destfile = outfile, method = 'curl', quiet = T, extra = '--connect-timeout 10 --retry 3 --retry-delay 4')
			# диагностический вывод информации о файле фотки
      print(file.info(outfile))
    }
  }
}
