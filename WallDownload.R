# Start only with HTS.R !!!

# для точности прочитать файл вывода ещё раз
# selected <- read.table('HTS.tab', header = T, stringsAsFactors = F)


### ### стена
selected$wallsize <- rep(0, nrow(selected))
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

### сохранение образа
save.image('.WallDownload')

### ### вывод конечных результатов в табличный файл
write.table(file='HTS-full.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)
