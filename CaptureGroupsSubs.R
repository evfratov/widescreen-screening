# Start only with HTS.R !!!

### корреляционный анализ групп и подписок
# число групп
selected$ngroups <- rep(0, nrow(selected))

### ### группы
for (uid in selected$uid) {
  # загрузка информации о группах
  filename <- paste0('/tmp/groups-', uid, '.xml')
  # скачивание за N попыток
  attempts <- 5
  att <- 0
  Sys.sleep(0.4)
  download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', uid, '&extended=1', '&access_token=', token), destfile = filename, method='wget', quiet = T)
  while (file.info(filename)$size == 0) {
    Sys.sleep(0.4)
    download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', uid, '&extended=1', '&access_token=', token), destfile = filename, method='wget', quiet = T)
    att <- att + 1
    if (att == attempts) { break }
  }
  # парсинг XML
  xmldata <- xmlParse(filename)
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
  # удаление XML
  file.remove(filename)
  # сохранение
  CorrData[['groups']][[paste0('id', uid)]] <- extend
}