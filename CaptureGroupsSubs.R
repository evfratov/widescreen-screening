# Start only with HTS.R !!!

# для точности прочитать файл вывода ещё раз
# selected <- read.table('HTS.tab', header = T, stringsAsFactors = F)

### корреляционный анализ групп и подписок
# число групп
selected$ngroups <- rep(0, nrow(selected))

# контейнер
CorrData <- list()

### ### группы
for (uid in selected$uid) {
  # загрузка информации о группах
  Sys.sleep(0.35)
  download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', uid, '&extended=1', '&access_token=', token), destfile = paste0('/tmp/groups-', uid, '.xml'), method='wget', quiet = T)
  # парсинг XML
  xmldata <- xmlParse(paste0('/tmp/groups-', uid, '.xml'))
  extend <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)))
  if (ncol(extend) != 1) {
    # убрать первый столбец и строку
    extend <- extend[-1,-1]
    # оставить только первые3 столбца
    extend <- extend[, 1:3]
    # записать число групп в ngroups
    selected[selected$uid == uid,]$ngroups <- nrow(extend)
  }
  # контрольный вывод
  print(paste(uid, selected[selected$uid == uid,]$ngroups))
  # сохранение
  CorrData[['groups']][[paste0('id', uid)]] <- extend
  # вывод датафрейма
  write.table(extend, paste0('/tmp/vkDB-groups-', uid,'.tab'), quote = F, sep = "\t", row.names = F, col.names = T)
}



### ### подписки
# число подписок
selected$nsubs <- rep(0, nrow(selected))
# число T-подписок
selected$Tsubs <- rep(0, nrow(selected))

for (uid in selected$uid) {
  # загрузка информации о подписках
  Sys.sleep(0.4)
  download.file(url = paste0('https://api.vk.com/method/users.getSubscriptions.xml?user_id=', uid, '&access_token=', token), destfile = paste0('/tmp/subs', uid), method='wget', quiet = T)
  # парсинг XML
  xmldata <- xmlParse(paste0('/tmp/subs', uid))
  if (xmlToDataFrame(getNodeSet(xmldata, '//groups/count'))[1,] != 0) {
    # продолжение парсинга XML
    extend <- xmlToDataFrame(xmlRoot(xmldata)[['groups']][['items']])
    colnames(extend) <- 'subid'
    # посчитать число подписок
    selected[selected$uid == uid,]$nsubs <- nrow(extend)
    # сохранить список групп
    groups <- as.vector(extend$subid)
    # затереть датафрейм
    extend <- data.frame()
    # получение имён групп
    for (k in 1:ceiling(length(groups)/200)) {
      tmp <- groups[(1 + (k-1) * 200):(k * 200)]
      tmp <- na.omit(tmp)
      Sys.sleep(0.4)
      download.file(url = paste0('https://api.vk.com/method/groups.getById.xml?group_ids=', paste0(tmp, collapse = ','), '&access_token=', token), destfile = paste0('/tmp/subsi', uid, '-', k), method='wget', quiet = T)
      # парсинг XML
      xmldatasub <- xmlParse(paste0('/tmp/subsi', uid, '-', k))
      tmp <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldatasub)))
      # отбор только ключевой информации
      tmp <- tmp[,1:3]
      if (nrow(extend) == 0) {
        # сохранение в расширенный датафрейм
        extend <- tmp
      } else {
        extend <- rbind(extend, tmp)
      }
    }
    
    # посчитать число Т-подписок
    selected[selected$uid == uid,]$Tsubs <- sum(extend$screen_name %in% targets)
  }
  system(paste0('rm /tmp/subsi', uid, '*'))
  
  # сохранение
  CorrData[['subs']][[paste0('id', uid)]] <- extend
  # вывод данных
  write.table(extend, paste0('/tmp/vkDB-subs-', uid, '.tab'), quote = F, sep = "\t", row.names = F, col.names = T)
  # контрольный вывод
  print(paste(uid, selected[selected$uid == uid,]$nsubs, selected[selected$uid == uid,]$Tsubs))
}

### вычисление нормированного Т-коэффициента
selected$NTC <- log((selected$Tcoeff + selected$Tsubs)/(selected$ngroups + selected$nsubs)) + 5
# слишком большие отклонения от положительных контролей, метод пока не применим

### удаление 1000ниц (приближение 950) по группам c Т-коэффициентом 1
selected <- selected[!((selected$ngroups >= 950) & (selected$Tcoeff == 1)),]


### корреляционный анализ групп



### сохранение образа
save.image('.CorrDat')
### ### вывод конечных результатов в табличный файл
write.table(file='HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)
