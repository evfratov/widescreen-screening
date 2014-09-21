# Start only with HTS.R !!!

# Получить список идентификаторов групп
download.file(url = paste0('https://api.vk.com/method/groups.getById?group_ids=', paste(groupsDB$group, collapse = ','), '&access_token=', token), destfile = '/tmp/tmp.txt', method='wget', quiet = F)
# парсинг JSON
tmp <- fromJSON(file = '/tmp/tmp.txt')$response
# преобразование в вектор uid
tmp <- sapply(tmp, function(x) unlist(x))
groupsTable <- as.data.frame(t(sapply(tmp, function(x) unlist(x)[c('screen_name', 'gid')])), stringsAsFactors = F)
# заменить глючный '19526' на 'club19526'
groupsTable[groupsTable$screen_name == 'club19526', 'screen_name'] <- '19526'



### получение тем групп по категориям
threads <- list()
for (category in unique(groupsDB$category)) {
  for (group in groupsDB[groupsDB$category == category, 'group']) {
    gid <- groupsTable[groupsTable$screen_name == group,]$gid
    filename <- paste0('/tmp/tmp-', gid,'.txt')
    # получение предварительных данных
    download.file(url = paste0('https://api.vk.com/method/board.getTopics?group_id=', gid, '&count=1', '&access_token=', token), destfile = filename, method='wget', quiet = T)
    # парсинг
    tmp <- fromJSON(file = filename)$response
    # подсчёт числа тем
    topCount <- tmp$topics[[1]]
    # обнуление для NULL
    print(paste(group, topCount))
    
    # работать только если есть треды
    threads[[paste0('gr', gid)]] <- data.frame()
    if (topCount > 0) {
      ### Получение тредов
      for (k in 1:ceiling(topCount/80)) {
        filename <- paste0('/tmp/tmp-', gid, '-', k,'.txt')
        # скачивание за N попыток
        attempts <- 5
        att <- 0
        Sys.sleep(0.4)
        download.file(url = paste0('https://api.vk.com/method/board.getTopics?group_id=', gid, '&count=80', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
        while (file.info(filename)$size == 0) {
          Sys.sleep(0.4)
          download.file(url = paste0('https://api.vk.com/method/board.getTopics?group_id=', gid, '&count=80', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
          att <- att + 1
          if (att == attempts) { break }
        }
        # парсинг блочного файла
        tmp <- fromJSON(file = filename)$response$topics
        tmp[[1]] <- NULL
        tmp <- as.data.frame(t(sapply(tmp, unlist)[rownames(sapply(tmp, unlist)) %in% c('tid', 'created_by', 'comments'),]), stringsAsFactors = F)
        # добавление блока датафрейма в threads группы
        if (nrow(threads[[paste0('gr', gid)]]) == 0) {
          threads[[paste0('gr', gid)]] <- tmp
        } else {
          threads[[paste0('gr', gid)]] <- rbind(threads[[paste0('gr', gid)]], tmp)
        }
      }
    }
  }
}

# учёт создания тем
selected$ntopics <- 0
for (tmp in sapply(threads, function(x) x$created_by)) {
  # отбор uid только из списка
  tmp <- tmp[tmp %in% selected$uid]
  # подсчёт числа топиков в каждом случае
  tmp <- table(tmp)
  # сохранение
  for (name in names(tmp)) {
    selected[selected$uid == name,]$ntopics <- as.numeric(tmp[name])
  }
}  


# Получение коментов
selected$ncomm <- 0
comments <- list()
for (name in names(threads)) {
  # отсечь буквы
  gid <- sub('gr', '', name)
  # взять данные для группы
  tmp <- threads[[name]]
  # убрать пустые треды
  tmp <- tmp[tmp$comments > 0,]
  
  # работать только с ненулевой
  if (nrow(tmp) > 0) {
    for (n in 1:nrow(tmp)) {
      tid <- tmp[n,]$tid
      for (k in 1:ceiling(as.numeric(tmp[n, 'comments'])/80)) {
        print(paste(gid, tid, k))
        filename <- paste0('/tmp/tmp-', tid, '-', k,'.txt')
        # скачивание за N попыток
        attempts <- 5
        att <- 0
        Sys.sleep(0.5)
        # загрузка коментов треда
        download.file(url = paste0('https://api.vk.com/method/board.getComments?group_id=', gid, '&topic_id=', tid, '&count=80', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
        while (file.info(filename)$size == 0) {
          Sys.sleep(0.5)
          download.file(url = paste0('https://api.vk.com/method/board.getComments?group_id=', gid, '&topic_id=', tid, '&count=80', '&offset=', (k-1) * 80, '&access_token=', token), destfile = filename, method='wget', quiet = T)
          att <- att + 1
          if (att == attempts) { break }
        }
        # парсинг
        temp <- fromJSON(file = filename)$response$comments
        temp[[1]] <- NULL
        temp <- as.data.frame(t(sapply(temp, function(x) unlist(x)[c('text', 'from_id')])), stringsAsFactors = F)
        # удаление комментаторов не из списка
        temp <- temp[temp$from_id %in% selected$uid,]
        # работа только если что-то осталось
        if (nrow(temp) > 0 ) {
          for (u in names(table(temp$from_id))) {
            # подсчёт числа коментов для каждого uid
            selected[selected$uid == u, 'ncomm']  <- as.numeric(table(temp$from_id)[u]) + selected[selected$uid == u, 'ncomm']
            print(selected[selected$uid == u,])
            # сохранение текста комента
            if (is.null(comments[[paste0('id', u, collapse = '')]])) {
              comments[[paste0('id', u, collapse = '')]] <- as.vector(temp$text)
            } else {
              comments[[paste0('id', u, collapse = '')]] <- c(comments[[paste0('id', u, collapse = '')]], as.vector(temp$text))
            }
          }
        }
      }
    }
  }
}