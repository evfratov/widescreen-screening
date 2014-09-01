library(XML)
library(rjson)
library(plyr)

setwd("~/Dropbox/evfr/HTS/")
load('.RData')

# возраст
minAge <- 21
maxAge <- 25
# пол
sex <- 'F'
# срок активности, дни
activity <- 20

# набор целевых групп
groupsDB <- read.table('db/groupsDB.tab', header = T, stringsAsFactors = F)
targets <- groupsDB$group
# категория 
targetCategory <- 'N'
# идеология
ideology <- 'трансгуманизм'

# bulk data members download
for (target in targets) {
  print(paste('  Group:  ', target))
  Sys.sleep(0.5)
  download.file(paste0('https://api.vk.com/method/groups.getById?group_id=', target, '&fields=members_count'), destfile=paste0('/tmp/', target, '.txt'), method='wget', quiet = T)
  tmp_file <- paste0('/tmp/',target, '.txt')
  tmp <- fromJSON(file = tmp_file)
  member_count <- tmp$response[[1]]$members_count
  print(paste('    members  ', member_count))
  system(paste0('rm /tmp/', target, '.txt'))
  stepSize <- as.integer(member_count / 1000)
  for (s in seq(0, stepSize)) {
    Sys.sleep(0.5)
    download.file(paste0('https://api.vk.com/method/groups.getMembers?group_id=', target, '&offset=', s * 1000,'&fields=sex,bdate,city,country,education,last_seen,relation&access_token=', token), destfile = paste0('/tmp/vkDB-', s, '-', target, '.txt'), method = 'wget', quiet = T)
  }
}

# parsing of JSON
usersdata <- list()
for (target in targets) {
  usersdata[[target]] <- data.frame()
  print(paste('parsing group:', target))
  for (filename in list.files('/tmp/', pattern = paste0('*-', target, '.txt'))) {
    tmp_file <- paste0('/tmp/', filename)
    tmp <- fromJSON(file = tmp_file)
    tmpdata <- do.call("rbind.fill", lapply(tmp$response$users, function(x) as.data.frame(x, stringsAsFactors = F)))
    if (nrow(usersdata[[target]]) == 0) {
      usersdata[[target]] <- tmpdata
    } else {
      usersdata[[target]] <- merge(usersdata[[target]], tmpdata, all = T)
    }
    rm(tmpdata)
  }
}
# сколько из какой группы получилось?
sapply(usersdata, nrow)

# слияние данных по группам
vkdata <- data.frame()
for (target in targets) {
  category <- as.vector(rep(target, nrow(usersdata[[target]])))
  if (nrow(vkdata) == 0) {
    vkdata <- cbind(usersdata[[target]], category)
  } else {
    vkdata <- rbind(vkdata, cbind(usersdata[[target]], category))
  }
  rm(category)
}
rm(usersdata)

nrow(vkdata)

###
#targets <- groupsDB[groupsDB$category == targetCategory, 'group']

sizeTab <- ncol(vkdata)
selected <- data.frame(matrix(0, ncol = sizeTab - 1))
colnames(selected) <- colnames(vkdata[,1:(sizeTab - 1)])
uids <- unique(vkdata$uid)
template <- as.data.frame(matrix(0, ncol = length(unique(groupsDB$category)), nrow = length(unique(vkdata$uid))))
colnames(template) <- unique(groupsDB$category)
for (n in 1:length(uids)) {
  uid <- uids[n]
  tmp <- vkdata[vkdata$uid == uid,]
  selected[n,] <- tmp[1, 1:(sizeTab - 1)]
  
  tmp <- t(as.matrix(table(groupsDB[tmp$category, 'category'])))
  template[n,colnames(tmp)] <- as.vector(tmp)
}
selected <- cbind(selected, template)
rm(uids, template)
# write.table(selected, 'data/HTS.tab', quote = T, sep = '\t', row.names = F, col.names = T)
# selected <- read.table('data/HTS.tab', header = T, sep = '\t', stringsAsFactors = F)


### ### Фильтрация
# удалить бесполезные колонки: type, university, faculty, education_form, education_status, graduation
selected <- selected[,!(colnames(selected) %in% c('university_name', 'faculty_name', 'education_form', 'education_status', 'graduation', 'last_seen.platform'))]
# замена имён <NA> на 0 для упрощения работы
selected[is.na(selected$university), 'university'] <- 0
selected[is.na(selected$faculty), 'faculty'] <- 0

# первичная фильтрация
gender <- c(0, 1)
names(gender) <- c('M', 'F')
selected <- selected[selected$sex == gender[[sex]],] # оставить только женский пол
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
selected <- selected[is.na(selected$relation_partner.id),] # удалить тех, у кого есть тот, с кем сложно
selected <- selected[,!(colnames(selected) %in% grep(x = colnames(selected), pattern = 'relation_partner*', value = T))] # удалить колонки 'relation_partner*'
selected[is.na(selected$relation), 'relation'] <- 0 # заменить статус NA на 0 для простоты работы

# удаление неактивных пользователей
selected <- selected[difftime(Sys.time(), as.POSIXct(selected$last_seen, origin='1970-01-01'), units='d') < activity,] # удалить неактивных в течении 20 дней
selected <- selected[,!colnames(selected) == 'last_seen.time'] # удалить более не нужную колонку "last_seen"

### Учёт чёрного списка
blacklist <- read.table('data/BlackList.tab', header = T, stringsAsFactors = F)
selected <- selected[!(selected$uid %in% blacklist$uid),]

### отбор полных дат и неполных дат для экспериментов с RAE, NA даты обнуляются
# подготовить колонку возраста
selected$age <- 0
# разделить на группы с
tempList <- list()
# ... неопределённой датой
tempList[['NA']] <- selected[is.na(selected$bdate),]
tmp <- selected[!is.na(selected$bdate),] # определённой bdate
# ... полной датой
tempList[['Full']] <- tmp[grep('\\d{4}', tmp$bdate),]
# ... неполной датой для RAE
tempList[['Trimm']] <- tmp[grep('\\d{4}', tmp$bdate, invert = T),]

### вывод для RAE
write.table(x = tempList[['Trimm']], file = 'data/data_for_RAE.tab', sep='\t', row.names=F, col.names=T, quote=T)
# ~~~~~~~~ #
# ~~~~~~~~ #
'ReversAgeEstimate.R'
# ~~~~~~~~ #
# ~~~~~~~~ #
### чтение после RAE
tempList[['RAEd']] <- read.table('data/data_RAE_pass.tab', sep = '\t', header = T, stringsAsFactors = F)

### конвертация bdate в возраст age для определённых полных дат
tempList[['Full']]$bdate <- as.character(as.Date(tempList[['Full']][,'bdate'], format='%d.%m.%Y')) # преобразование содержимого поля в даты
tempList[['Full']]$age <- as.numeric(round(difftime(Sys.Date(), as.Date(tempList[['Full']][,'bdate'], format='%Y-%m-%d'), units='d')/365, 1)) # пересчёт в года

tempList[['Full']] <- tempList[['Full']][tempList[['Full']]$age >= minAge,] # удалить моложе чем minAge лет если возраст не NA
tempList[['Full']] <- tempList[['Full']][tempList[['Full']]$age <= maxAge,] # удалить старше чем maxAge лет если возраст не NA
selected <- rbind(tempList[['Full']], tempList[['RAEd']]) # склеить обратно в целый датафрейм полные отфильтрованные и неполные после RAE
selected <- rbind(tempList[['NA']], selected) # склеить обратно суммарно отфильтрованные и с неопределёнными датами
selected[is.na(selected$bdate), 'bdate'] <- 0 # заменить NA даты рождения на нули
rm(tempList)

### Получение данных о группах из selected и фильтрация спамерш
# ~~~~~~~~ #
# ~~~~~~~~ #
'CaptureGroupsSubs.R'
# ~~~~~~~~ #
# ~~~~~~~~ #
### Скоринг по T-параметрам и числу групп
# f(age) не нужен, f(ngroups) = lg(ngroups), f(TRNSI) = (T + R + N + S + I) XX (2 0.5 0.5 0.25 0.5)
scoring <- function(x) {
  x <- x[c('T', 'R', 'N', 'S', 'I', 'ngroups')]
  x <- as.integer(x)
  names(x) <- c('T', 'R', 'N', 'S', 'I', 'ngroups')
  tmp <- 2 * x['T'] + 0.5 * x['R'] + 0.5 * x['N'] + 0.25 * x['S'] + 0.5 * x['I']
  tmp <- round(tmp - log10(x['ngroups']), 1)
  names(tmp) <- ''
  return(tmp)
}

selected$score <- apply(selected, 1, scoring)
selected[is.infinite(selected$score), 'score'] <- 0

plot(sort(selected$score))
head(selected[order(selected$score, decreasing = T),], 25)


### Захват мета-данных стен и загрузка комментариев
# ~~~~~~~~ #
# ~~~~~~~~ #
'WallDownload.R'
# ~~~~~~~~ #
# ~~~~~~~~ #
# selected <- read.table('data/HTS.tab', header = T, sep = '\t', stringsAsFactors = F)


### Получение дополнительного скоринга для правильно идеологических
# загрузка файла
download.file(url = paste0('https://api.vk.com/method/users.search?sex=', gender[[sex]], '&religion=', ideology, '&count=1000', '&access_token=', token), destfile = '/tmp/ideo-reward.txt', method='wget', quiet = F)
# парсинг JSON
tmp <- fromJSON(file = '/tmp/ideo-reward.txt')$response
# преобразование в вектор uid
tmp[[1]] <- NULL
tmp <- sapply(tmp, function(x) unlist(x))['uid',]
# увеличение Score, величина награды 5
selected[selected$uid %in% tmp,]$score <- selected[selected$uid %in% tmp,]$score + 5
# задание метки правильной идеологии RiId
selected$RiId <- 0
selected[selected$uid %in% tmp,]$RiId <- 1


### Получение тем и комментариев в Т-группах
# ~~~~~~~~ #
# ~~~~~~~~ #
'CaptureGroupActivity.R'
# ~~~~~~~~ #
# ~~~~~~~~ #
# увеличение Score: + ntopic и 1 + ln(ncomm + 1)
selected$score <- selected$score + selected$ntopics + round(log(selected$ncomm + 1), 1)


# сохранение результатов
write.table(file='data/HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)






# --------------------------------------------------------------------- #
# получение стран из базы данных Vk
countries <- levels(as.factor(selected$country))
download.file(paste0('https://api.vk.com/method/database.getCountriesById.xml?country_ids=', paste(countries, collapse=',')), destfile='/tmp/countries.txt', method='wget')
xmldata <- xmlParse('/tmp/countries.txt')
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
  Sys.sleep(0.4)
  download.file(paste0('https://api.vk.com/method/database.getCitiesById.xml?city_ids=', paste(tmp, collapse=',')), destfile=paste0('/tmp/cities-', k, '.txt'), method='wget')
  xmldata <- xmlParse(paste0('/tmp/cities-', k, '.txt'))
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




### ### вывод конечных результатов в табличный файл
write.table(file='data/HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)

