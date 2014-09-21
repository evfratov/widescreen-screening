# Start only with HTS.R !!!

# для точности прочитать файл вывода ещё раз
# selected <- read.table('data/HTS.tab', header = T, stringsAsFactors = F)


### Получение метаданных стены
selected$wallsize <- rep(0, nrow(selected))
selected$comkchars <- rep(0, nrow(selected))

for (uid in selected$uid) {
  # загрузка информации о стене - посчёт числа коментов
  filename <- paste0('/tmp/wall-', uid, '.txt')
  # скачивание за N попыток
  attempts <- 5
  att <- 0
  Sys.sleep(0.4)
  download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = F)
  while (file.info(filename)$size == 0) {
    Sys.sleep(0.4)
    download.file(url = paste0('https://api.vk.com/method/wall.get?owner_id=', uid, '&count=1', '&filter=owner', '&access_token=', token), destfile = filename, method='wget', quiet = F)
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
  print(paste(uid, ncomments))
  selected[selected$uid == uid, 'wallsize'] <- ncomments
}

# загрузка данных только для стен, больше чем 5
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
  print(paste(uid, comkchar))
}

# --------------------------------------------------------------------- #
for (id in selected$uid) {
  # загрузка информации о стене - посчёт числа коментов
  Sys.sleep(0.4)
  file.create(paste0('/tmp/vkDB-wall', id))
  while (file.info(paste0('/tmp/vkDB-wall', id))$size == 0) {
    try(download.file(url = paste0('https://api.vk.com/method/wall.get.xml?owner_id=', id, '&count=1', '&filter=owner', '&access_token=', token), destfile = paste0('/tmp/vkDB-wall', id), method='curl', quiet = T))
  } 
  # парсинг пробного XML
  xmldata <- xmlParse(file = paste0('/tmp/vkDB-wall', id))
  # подсчёт числа коментов
  ncomments <- as.vector(xmlToDataFrame(getNodeSet(xmldata, '//response/count'))[1,1])
#  
  # получение всех коментов
  if (!is.null(ncomments)) {
    ncomments <- as.numeric(ncomments)
    extend <- data.frame()
    for (k in 1:ceiling(ncomments/100)) {
      Sys.sleep(0.4)
      file.create(paste0('/tmp/vkDB-wall', id, '-', k))
      while (file.info(paste0('/tmp/vkDB-wall', id, '-', k))$size == 0) {
        try(download.file(url = paste0('https://api.vk.com/method/wall.get.xml?owner_id=', id, '&count=100', '&filter=owner', '&offset=', (k-1) * 100, '&access_token=', token), destfile = paste0('/tmp/vkDB-wall', id, '-', k), method='curl', quiet = T))
      }
      # парсинг основного XML
      xmldata <- xmlParse(paste0('/tmp/vkDB-wall', id, '-', k))
      tmp <- sapply(getNodeSet(xmldata, '//response/post/text'), xmlValue)
      # удалить коменты без текста
      tmp <- tmp[tmp != '']
      # проверить что в блоке вообще есть коменты с текстом
      if (length(tmp) != 0) {
        tmp <- as.data.frame(tmp)
        colnames(tmp) <- 'comment'
        # запись в расширенный датафрейм
        if (nrow(extend) == 0) {
          extend <- tmp
        } else {
          extend <- rbind(extend, tmp)
        }
      }
    }
    system(paste0('rm /tmp/vkDB-wall', id, '*'))
    
    # контрольный вывод
    print(paste(id, ncomments, nrow(extend)))
  } else {
    # забив если проблемы с получением коментов
    ncomments <- 0
  }
  
  # вывод в библиотеку файлов
  if (nrow(extend) != 0) {
    selected[selected$uid == uid, 'wallsize'] <- ncomments
    #    file.create(paste0('/tmp/vkDB-walls-', id, '.txt'))
    out <- file(paste0('/tmp/vkDB-walls-', id, '.txt'), open = 'w')
    writeLines(as.vector(extend$comment), out)
    close(out)
  }
}
