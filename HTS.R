library(XML)
library(tm)
setwd("~/Dropbox/evfr/HTS/")
load(".RData")
loadhistory(file = ".Rhistory")

savehistory(file = ".Rhistory") ### Don't forget save history! ###
save.image('.RData')

# https://oauth.vk.com/authorize?client_id=4315528&scope=1326214&redirect_uri=https://oauth.vk.com/blank.html&display=page&v=5.21&response_type=token
# 24 часа

# набор целевых групп
#target <- c('dreamtheater', 'bbcdoctorwho')
target <- c('transhumanism_russia', 'transhumanist', 'transcyber', 'immortalism', 'thuman', 'kriorus2006')
targets <- paste0(target, collapse = ' ')
token <- '28e5db3dacd2bd6cccb6fcfc33708c70a634c8e54d70c82d7ddad21187712979fd18451156d9a00a6868c5649703a'

# Запуск!
system(paste0('bash vkAutoSearch.bash \'', targets, '\' ', token))

## выбор режима - "все группы вместе" или "любая группа"
#mode <- 'OR' # может быть 'AND' или 'OR'

# парсинг сырых XML-данных
usersdata <- list()
for (group in target) {
  usersdata[[group]] <- data.frame()
  print(paste('parsing group:', group))
  for (filename in list.files(pattern = paste0('*-', group, '.txt'))) {
    xmldata <- xmlParse(filename)
    print(paste("  parsing", filename))
    tmp <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)[['users']]))
    if (nrow(usersdata[[group]]) == 0) {
      usersdata[[group]] <- tmp
    } else {
      usersdata[[group]] <- merge(usersdata[[group]], tmp, all=T)
    }
  }
}
# сколько из какой группы получилось?
sapply(usersdata, nrow)

# слияние данных по группам и классификация
vkdata <- data.frame()
for (group in names(usersdata)) {
  category <- as.vector(rep(group, nrow(usersdata[[group]])))
  if (nrow(vkdata) == 0) {
    vkdata <- cbind(usersdata[[group]], category)
  } else {
    vkdata <- rbind(vkdata, cbind(usersdata[[group]], category))
  }
}
nrow(vkdata)

# вычисление Tcoeff
tmp <- as.vector(table(vkdata$uid)[vkdata$uid])
vkdata$Tcoeff <- tmp

# удаление дубликатов по UID
vkdata <- vkdata[!duplicated(vkdata$uid),]

# удалить бесполезные колонки: type, university, faculty, education_form, education_status, graduation
vkdata <- vkdata[,!(colnames(vkdata) %in% c('type', 'university', 'faculty', 'education_form', 'education_status', 'graduation'))]

# первичная фильтрация
selected <- vkdata[vkdata$sex == 1,] # оставить только женский пол
selected <- selected[,!colnames(selected) == 'sex'] # убрать ненужную уже колонку про пол
selected <- selected[is.na(selected$deactivated),] # выбрать не забаненных и не заблокированных
selected <- selected[,!colnames(selected) == 'deactivated'] # удалить колонку 'deactivated'

# выбрать "single", "actively searching" и "it's complicated"* по статусу отношений
# 1 – single
# 2 – in a relationship
# 3 – engaged
# 4 – married
# 5 – it's complicated
# 6 – actively searching
# 7 – in love

# удалить типы 2, 3, 4 и 7
selected <- selected[!selected$relation %in% c(2,3,4,7),]
selected <- selected[is.na(selected$relation_partner),] # удалить тех, у кого есть тот, с кем сложно
selected <- selected[,!colnames(selected) == 'relation_partner'] # удалить колонку 'relation_partner'
selected[is.na(selected$relation), 'relation'] <- 0 # заменить статус NA на 0 для простоты работы

# удаление неактивных пользователей
removeLast <- function(x) { substr(x, 1, nchar(x)-1) } # создать функциб для отрезания номера платформы от даты last_seen
selected$last_seen <- removeLast(selected$last_seen) # удалить номер платформы от last_seen
selected$last_seen <- as.numeric(selected$last_seen) # преобразовать last_seen UNIX-time в число
selected <- selected[difftime(Sys.time(), as.POSIXct(selected$last_seen, origin='1970-01-01'), units='d') < 20,] # удалить неактивных в течении 20 дней
selected <- selected[,!colnames(selected) == 'last_seen'] # удалить более не нужную колонку "last_seen"

# отсечение по возрасту
selected$bdate <- as.character(as.Date(selected[,'bdate'], format='%d.%m.%Y')) # преобразование содержимого поля в даты
subselected <- selected[!is.na(selected$bdate),] # разбить по определённой величине bdate
selected <- selected[is.na(selected$bdate),] # ...и неопределённой
subselected <- subselected[difftime(Sys.Date(), as.Date(subselected[,'bdate'], format='%Y-%m-%d'), units='d')/365 > 20,] # удалить моложе чем 20 лет если возраст не NA
subselected <- subselected[difftime(Sys.Date(), as.Date(subselected[,'bdate'], format='%Y-%m-%d'), units='d')/365 < 25,] # удалить старше чем 25 лет если возраст не NA
selected <- rbind(subselected, selected) # склеить обратно в целый датафрейм
selected[is.na(selected$bdate), 'bdate'] <- 0 # заменить NA даты рождения на нули

# реверсная оценка возраста
subselected <- selected[selected$bdate == 0,] # выделить поднабор с неопределённым возрастом
# перебор всех пользователей по имени и фамилии в целевом диапазоне возраста
in_normal_range <- c()
for (n in seq(1, 20)) { # nrow(subselected)/10
  f_name <- subselected[n,'first_name']
  l_name <- subselected[n,'last_name']
  uid <- subselected[n,'uid']
  download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=20&age_to=25', '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget')
  tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
  tmp <- xmlToDataFrame(tmp)
  if (tmp[1,1] != 0) {
    print(sum(tmp$uid %in% uid))
    if (sum(tmp$uid %in% uid) > 0) {
      in_normal_range <- c(in_normal_range, uid)
    }
  }
  system(paste0('rm /tmp/', uid, '.txt'))
  Sys.sleep(0.3)
}


nrow(selected)

# получение стран из базы данных Vk
countries <- levels(as.factor(selected$country))
download.file(paste0('https://api.vk.com/method/database.getCountriesById.xml?country_ids=', paste(countries, collapse=',')), destfile='db/countries.txt', method='wget')
xmldata <- xmlParse('db/countries.txt')
countidb <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)))
# замещение индексных номеров стран на нормальные названия
for (country in levels(countidb$cid) ) {
  selected[selected$country == country, 'country'] <- rep(x=as.character(countidb[countidb$cid == country, 'name']), times=length(selected[selected$country == country, 'country']))
}

# получение городов из базы данных Vk
citydb <- data.frame()
cities <- levels(as.factor(selected$city))
for (k in 1:ceiling(length(cities)/500)) {
  tmp <- cities[(1 + (k-1) * 500):(k * 500)]
  download.file(paste0('https://api.vk.com/method/database.getCitiesById.xml?city_ids=', paste(tmp, collapse=',')), destfile=paste0('db/cities-', k, '.txt'), method='wget')
  xmldata <- xmlParse(paste0('db/cities-', k, '-.txt'))
  tmp <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)))
  if (nrow(citydb) == 0) {
    citydb <- tmp
  } else {
    citydb <- rbind(citydb, tmp)
  }
}
# замена идентификаторов городов на нормальные названия
for (city in levels(citydb$cid) ) {
  selected[selected$city == city, 'city'] <- rep(x=as.character(citydb[citydb$cid == city, 'name']), times=length(selected[selected$city == city, 'city']))
}

# удалить символ "\n" из имён университетов и факультетов
selected$university_name <- gsub(pattern='\n', replacement='', selected$university_name, perl=T)
selected$faculty_name <- gsub(pattern='\n', replacement='', selected$faculty_name, perl=T)
# замена имён <NA> на 0 для упрощения работы
selected[is.na(selected$university_name), 'university_name'] <- 0
selected[is.na(selected$faculty_name), 'faculty_name'] <- 0
# замена пустых имён на 0 для упрощения работы
selected[selected$university_name == '', 'university_name'] <- 0
selected[selected$faculty_name == '', 'faculty_name'] <- 0

# удалить тех, кто без фото
selected <- selected[!(selected$photo_max_orig == 'http://vk.com/images/camera_a.gif'),]

### ### вывод конечных результатов в табличный файл
write.table(file='HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=F)


### ### Статистический анализ
nrow(selected) # сколько всего
sum(selected$country == 0) # 10% не указали страну, - очень низкоприротетно, бинарный есть - нет
sum(selected$university_name == 0) # 80% не указали - низкоприротетно, бинарный есть - нет
sum(selected$bdate == 0) # 80% без даты рождения - средний критерий приоритета, бинарный нет - есть
sum(selected$city == 0) # 20% не указали город - важный критерий наличия и очень важдый критерий по COI (города интереса), тринарный нет - есть - COI
table(selected$relation) # 90% не указали статус, не single у 1,35% - главный критерий приоритета, бинарный 0|1 - 5|6

### категоризация
# итого: university_name bdate city+city_u_COI relation
# вычисление рейтинга:
# country 1
# university_name 2
# bdate 2
# city 2
# city_u_COI 10
# relation 20
# задание Городов Интереса
coi <- c('Москва', 'Нижний Новгород', 'Ижевск', 'Тольятти', 'Сарапул')
# новая колонка для рейтинга
score <- rep(0, nrow(selected))
selected <- cbind(selected, score)
# оценка
for (i in 1:nrow(selected)) {
  tmp <- selected[i,]
  # учёт country
  if (tmp$city != 0) { selected[i,'score'] <- selected[i,'score'] + 1 }
  # учёт university_name
  if (tmp$university_name != 0) { selected[i,'score'] <- selected[i,'score'] + 2 }
  # учёт bdate
  if (tmp$bdate != 0) { selected[i,'score'] <- selected[i,'score'] + 2 }
  # учёт city
  if (tmp$city != 0) { selected[i,'score'] <- selected[i,'score'] + 2 }
  # учёт city_u_COI
  if (tmp$city %in% coi) { selected[i,'score'] <- selected[i,'score'] + 10 }
  # учёт relation
  if (tmp$relation > 1) { selected[i,'score'] <- selected[i,'score'] + 20 }
}
# exploratory plot
plot(table(selected$score), ylab = 'Count', xlab = 'Score')

# разбивка на 3 приоритета до 8, после 8 и до 20, с 20
minim <- 8
maxim <- 20
abline(v = minim, col = 'blue', lwd = 2)
abline(v = maxim, col = 'red', lwd = 2)
priority <- list()
priority[['low']] <- selected[selected$score < minim,]
priority[['mid']] <- selected[(selected$score >= minim) & (selected$score < maxim),]
priority[['high']] <- selected[selected$score >= maxim,]
# итоговая статистика
sapply(priority, nrow)

# вывод приоритетных данных
for (name in names(priority)) {
 filename <- paste0('PriorityList_', name, '.tab')
 write.table(priority[[name]], filename, sep = "\t", quote = F, row.names = F, col.names = T)
}

# ### пакетная загрузка фотографий
# # последовательная загрузка фотографии типа 'photo_max_orig'
# for (n in 1:nrow(priority[['high']])) {
#    download.file(url=priority[['high']][n,'photo_max_orig'], destfile=paste0('photos_high/', priority[['high']][n,'uid'], '_', priority[['high']][n,'first_name'], '-', priority[['high']][n,'last_name'], '.jpg'), method='curl')
# }


### расширенный анализ данных пользователей
# хранилище расширенных данных
extend <- list()
# число групп
selected$ngroups <- rep(0, nrow(selected))

### группы
# список для данных групп
extend[['gropus']] <- list()
for (id in selected$uid) {
  # загрузка информации о группах
  Sys.sleep(0.3)
  download.file(url = paste0('https://api.vk.com/method/groups.get.xml?user_id=', id, '&extended=1', '&access_token=', token), destfile = paste0('/tmp/groups-', id, '.xml'), method='wget')
  # парсинг XML
  xmldata <- xmlParse(paste0('/tmp/groups-', id, '.xml'))
  extend[['gropus']][[id]] <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldata)))
  if (ncol(extend[['gropus']][[id]]) != 1) {
    # убрать первый столбец и строку
    extend[['gropus']][[id]] <- extend[['gropus']][[id]][-1,-1]
    # оставить только первые 3 столбца
    extend[['gropus']][[id]] <- extend[['gropus']][[id]][,1:3]
    # записать число групп в ngroups
    selected[selected$uid == id,]$ngroups <- nrow(extend[['gropus']][[id]])
  }
  # контрольный вывод
  print(paste(id, selected[selected$uid == id,]$ngroups))
  # вывод в db
  write.table(extend[['gropus']][[id]], paste0('db/groups/groups-', id, '.tab'), quote = F, sep = "\t", row.names = F, col.names = T)
}
plot(table(sapply(extend[['gropus']], nrow)))

# подписки
# список для данных подписок
extend[['subs']] <- list()
# число подписок
selected$nsubs <- rep(0, nrow(selected))
# число T-подписок
selected$Tsubs <- rep(0, nrow(selected))

for (id in selected$uid) {
  # загрузка информации о подписках
  Sys.sleep(0.4)
  file.create(paste0('/tmp/subs', id))
  while (file.info(paste0('/tmp/subs', id))$size == 0) {
    try(download.file(url = paste0('https://api.vk.com/method/users.getSubscriptions.xml?user_id=', id, '&access_token=', token), destfile = paste0('/tmp/subs', id), method='curl'))
  }
  # парсинг XML
  xmldata <- xmlParse(paste0('/tmp/subs', id))
  
  if (xmlToDataFrame(getNodeSet(xmldata, '//groups/count'))[1,] != 0) {
    # продолжение парсинга XML
    extend[['subs']][[id]] <- xmlToDataFrame(xmlRoot(xmldata)[['groups']][['items']])
    colnames(extend[['subs']][[id]]) <- 'subid'
    # посчитать число подписок
    selected[selected$uid == id,]$nsubs <- nrow(extend[['subs']][[id]])
    # сохранить список групп
    groups <- as.vector(extend[['subs']][[id]]$subid)
    # затереть датафрейм
    extend[['subs']][[id]] <- data.frame()
    # получение имён групп
    for (k in 1:ceiling(length(groups)/200)) {
      tmp <- groups[(1 + (k-1) * 200):(k * 200)]
      tmp <- na.omit(tmp)
      Sys.sleep(0.4)
      file.create(paste0('/tmp/subsi', id, '-', k))
      while (file.info(paste0('/tmp/subsi', id, '-', k))$size == 0) {
        try(download.file(url = paste0('https://api.vk.com/method/groups.getById.xml?group_ids=', paste0(tmp, collapse = ','), '&access_token=', token), destfile = paste0('/tmp/subsi', id, '-', k), method='wget'))
      }
      # парсинг XML
      xmldatasub <- xmlParse(paste0('/tmp/subsi', id, '-', k))
      tmp <- xmlToDataFrame(nodes = xmlChildren(xmlRoot(xmldatasub)))
      # отбор только ключевой информации
      tmp <- tmp[,1:3]
      if (nrow(extend[['subs']][[id]]) == 0) {
        # сохранение в расширенный датафрейм
        extend[['subs']][[id]] <- tmp
      } else {
        extend[['subs']][[id]] <- rbind(extend[['subs']][[id]], tmp)
      }
    }
    
    # посчитать число Т-подписок
    selected[selected$uid == id,]$Tsubs <- sum(extend[['subs']][[id]]$screen_name %in% target)
  }
  system(paste0('rm /tmp/subsi', id, '*'))
  
  # вывод данных
  write.table(extend[['subs']][[id]], paste0('db/subs/subs-', id, '.tab'), quote = F, sep = "\t", row.names = F, col.names = T)
  # контрольный вывод
  print(paste(id, selected[selected$uid == id,]$nsubs, selected[selected$uid == id,]$Tsubs, round(which(selected$uid == id)/nrow(selected)*100, 1)))
  
}

# ## Получение объединённого датафрейма всех групп
# tmp <- data.frame()
# for (name in names(extend[['gropus']])) {
#   if (ncol(extend[['gropus']][[name]]) == 3) {
#     if (nrow(tmp) == 0) {
#       tmp <- extend[['gropus']][[name]]
#     } else {
#       tmp <- rbind(extend[['gropus']][[name]], tmp)
#     }
#   }
# }
# tmp <- unique(tmp)
# write.table(tmp, 'db/groupScore.tab', quote = F, sep = "\t", row.names = F, col.names = T)

# стена
# список для данных стены
extend[['wall']] <- list()
for (id in selected$uid) {
  # загрузка информации о стене - посчёт числа коментов
  Sys.sleep(0.4)
  file.create(paste0('/tmp/wall', id))
  while (file.info(paste0('/tmp/wall', id))$size == 0) {
    try(download.file(url = paste0('https://api.vk.com/method/wall.get.xml?owner_id=', id, '&count=1', '&filter=owner', '&access_token=', token), destfile = paste0('/tmp/wall', id), method='curl'))
  } 
  # парсинг пробного XML
  xmldata <- xmlParse(paste0('/tmp/wall', id))
  # подсчёт числа коментов
  ncomments <- as.vector(xmlToDataFrame(getNodeSet(xmldata, '//response/count'))[1,1])
  
  # получение всех коментов
  if (!is.null(ncomments)) {
    ncomments <- as.numeric(ncomments)
    for (k in 1:ceiling(ncomments/100)) {
      Sys.sleep(0.4)
      file.create(paste0('/tmp/wall', id, '-', k))
      while (file.info(paste0('/tmp/wall', id, '-', k))$size == 0) {
        try(download.file(url = paste0('https://api.vk.com/method/wall.get.xml?owner_id=', id, '&count=100', '&filter=owner', '&offset=', (k-1) * 100, '&access_token=', token), destfile = paste0('/tmp/wall', id, '-', k), method='curl'))
      }
      # парсинг основного XML
      xmldata <- xmlParse(paste0('/tmp/wall', id, '-', k))
      tmp <- sapply(getNodeSet(xmldata, '//response/post/text'), xmlValue)
      # удалить коменты без текста
      tmp <- tmp[tmp != '']
      # проверить что в блоке вообще есть коменты с текстом
      if (length(tmp) != 0) {
        tmp <- as.data.frame(tmp)
        colnames(tmp) <- 'comment'
        # запись в расширенный датафрейм
        if (is.null(extend[['wall']][[id]])) {
         extend[['wall']][[id]] <- tmp
        } else {
         extend[['wall']][[id]] <- rbind(extend[['wall']][[id]], tmp)
        }
      }
    }
    system(paste0('rm /tmp/wall', id, '*'))
    
    # забив если коментов 0
    if (ncomments == 0 | is.null(extend[['wall']][[id]])) {
      extend[['wall']][[id]] <- data.frame()
    }
    
    # контрольный вывод
    print(paste(id, ncomments, nrow(extend[['wall']][[id]])))
  } else {
    # забив если проблемы с получением коментов
    extend[['wall']][[id]] <- data.frame()
  }
    
  # вывод в библиотеку файлов
  if (nrow(extend[['wall']][[id]]) != 0) {
#    file.create(paste0('db/walls/', id, '.txt'))
    out <- file(paste0('db/walls/', id, '.txt'), open = 'w')
    writeLines(as.vector(extend[['wall']][[id]]$comment), out)
    close(out)
  }
  # удаление данных стены
  extend[['wall']][[id]] <- ''
}

# коменты к фотографиям


# curl 'http://api.vk.com/method/photos.get.xml?owner_id=9489198&album_id=profile&rev=1&count=1'