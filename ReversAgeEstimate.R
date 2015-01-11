# прочитать текстовый файл со списком информации о пользователях для реверсивной оценки возраста
RAE <- read.table('data/data_for_RAE.tab', header = T, stringsAsFactors = F)

# время ожидания в c между запросами
time.threshold <- 9
# инициализация счётчика удалённых пользователей
count <- 0
# вывод оценки времени исполнения
print(paste('Approx time', round(nrow(RAE) * time.threshold / 3600), 'h'))
# пробегание цикла по всем пользователям
for (n in seq(1, nrow(RAE))) {
	# получение имени пользователя номер n
  f_name <- RAE[n, 'first_name']
	# получения фамилии
  l_name <- RAE[n, 'last_name']
	# получение идентификатора пользователя
  uid <- RAE[n, 'uid']
	# запрос по методу users.search с заполненными полями q <имя> <фамилия>, age_from <minAge>, age_to <maxAge>, числом вывода пользователей count = 1000 и токеном,
	# сохранение результата в текстовый файл, в данном случае XML, /tmp/<uid>.txt
  download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=', minAge,'&age_to=', maxAge, '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget')
	# ожидание после веб-запроса
  Sys.sleep(time.threshold)
	# парсинг XML файла
  tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
	# конвертация в data frame
  tmp <- xmlToDataFrame(tmp)
	# проверка ненулёвости вывода принадлежности
  if (tmp[1,1] != 0) {
		# проверка наличия идентификатора пользователя в результате
    if (sum(tmp$uid %in% uid) > 0) {
		# вывод уведомления о подтверждении возраста в диапазоне
      print('    in range')
		# присвоение возраста такому пользователю как minAge - 1 для маркировки возраста как оценочного
      RAE[RAE$uid == uid, 'age'] <- minAge - 1
    } else {
		# вывод возраста пользователя как вне диапазона
      print('    excluded')
		# увеличение счётчика удалённых пользователей
      count <-  count + 1
    }
  } else {
		# вывод возраста пользователя как вне диапазона
    print('    excluded')
		# увеличение счётчика удалённых пользователей
    count <-  count + 1
  }
	# удаление временного файла с результатом поиска
  system(paste0('rm /tmp/', uid, '.txt'))
}
# вывод числа удалённых пользователей
print(paste(count, ' Excluded'))
# сохранение во временную таблицу passed пользоваталей с оценённым возрастом в нужном диапазоне
passed <- RAE[RAE$age == (minAge - 1),]
# удаление таблицы с исходными данными из памяти
rm(RAE)
# ... и с диска
file.remove('data/data_for_RAE.tab')

# вывод конечных результатов в табличный файл data/data_RAE_pass.tab
write.table(file = 'data/data_RAE_pass.tab', x = passed, sep='\t', row.names=F, col.names=T, quote=T)
# удаление временной таблицы из памяти
rm(passed)
