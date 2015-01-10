# Start only with HTS.R !!!

### Получение метаданных стены
selected$wallsize <- rep(0, nrow(selected))
selected$comkchars <- rep(0, nrow(selected))

count <- 1
for (uid in selected$uid) {
  # загрузка информации о стене - посчёт числа коментов
  filename <- paste0('/tmp/wall-', uid, '.txt')
  # скачивание за N попыток
  attempts <- 5
  att <- 0
  Sys.sleep(0.4)
  download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = T)
  while (file.info(filename)$size == 0) {
    Sys.sleep(0.4)
    download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = T)
    att <- att + 1
    if (att == attempts) { break }
  }
  # парсинг
  tmp <- fromJSON(file = filename)
  tmpdata <- do.call("rbind.fill", lapply(tmp$response[[1]], function(x) as.data.frame(x, stringsAsFactors = F)))
  ncomments <- as.numeric(tmpdata)
  # проверка на адекватность
  if (length(ncomments) == 0) {
    ncomments <- 0
  }
  # запись числа постов
  print(paste('N', count, uid, 'size', ncomments, 'posts'))
  selected[selected$uid == uid, 'wallsize'] <- ncomments
  count <- count + 1
}

# загрузка данных только для стен, больше чем 5
count <- 1
for (uid in selected[selected$wallsize > 5, 'uid']) {
  ncomments <- selected[selected$uid == uid, 'wallsize']
  tmpdata <- c()
  for (k in 1:ceiling(ncomments/80)) {
    attempts <- 5
    att <- 0
    filename <- paste0('/tmp/wall-block-', uid, '-', k, '.txt')
    print(filename)
    Sys.sleep(0.4)
    download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=80', '&filter=owner', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
    while (file.info(filename)$size == 0) {
      Sys.sleep(0.4)
      download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=80', '&filter=owner', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = F)
      att <- att + 1
      if (att == attempts) { break }
    }
    # парсинг блочного файла
    tmp <- fromJSON(file = filename)
    # конвертация в листы векторов
    tmp <- sapply(tmp$response, function(x) unlist(x))
    # выбор только тех элементов листа, где есть поле text
    tmp <- tmp[sapply(sapply(sapply(tmp, names), function(x) x == 'text'), sum) == 1]
    # извлечение текста
    tmp <- sapply(tmp, function(x) x[['text']])
    
    # удаление NA
    tmp <- tmp[!is.na(tmp)]
    # удаление ""
    tmp <- tmp[!tmp == '']
    # запись во временный вектор
    tmpdata <- c(tmpdata, tmp)
  }
  # сохранение текста пользователя в лист
  CorrData[['wall']][[paste0('id', uid)]] <- tmpdata
  # сохранение размера в kChars
  comkchar <- round(sum(nchar(tmpdata))/1000, 1)
  selected[selected$uid == uid, 'comkchars'] <- comkchar
  print(paste('N', uid, count, 'size', comkchar, 'kchars'))
  count <- count + 1
}