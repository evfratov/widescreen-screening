library(XML)

setwd("~/Dropbox/evfr/HTS/")
# токен
token <- ''
# набор целевых групп
targets <- c('transhumanism_russia', 'transhumanist', 'transcyber', 'immortalism', 'thuman', 'kriorus2006')
# возраст
minAge <- 21
maxAge <- 25
# пол
sex <- 'F'
# срок активности, дни
activity <- 20


# Запуск!
for (target in targets) {
  print(paste('  Group:  ', target))
  Sys.sleep(0.4)
  download.file(paste0('https://api.vk.com/method/groups.getById.xml?group_id=', target, '&fields=members_count'), destfile=paste0('/tmp/',target, '.txt'), method='wget', quiet = T)
  tmp <- readLines(paste0('/tmp/',target, '.txt'))
  tmp <- grep('members_count>', tmp, value = T)
  member_count <- as.integer(gsub('(( )+)?<.+?>', '', tmp))
  print(paste('    members  ', member_count))
  system(paste0('rm /tmp/',target, '.txt'))
  stepSize <- as.integer(member_count / 1000)
  for (s in seq(0, stepSize)) {
    Sys.sleep(0.4)
    download.file(paste0('https://api.vk.com/method/groups.getMembers.xml?group_id=', target, '&offset=', s * 1000,'&fields=sex,bdate,city,country,education,last_seen,relation&access_token=', token), destfile = paste0('/tmp/vkDB-', s, '-',target, '.xml'), method = 'wget', quiet = T)
  }
}

# парсинг сырых XML-данных
usersdata <- list()
for (group in targets) {
  usersdata[[group]] <- data.frame()
  print(paste('parsing group:', group))
  for (filename in list.files('/tmp/', pattern = paste0('*-', group, '.xml'))) {
    xmldata <- xmlParse(paste0('/tmp/', filename))
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
rm(usersdata)

# вычисление Tcoeff
tmp <- as.vector(table(vkdata$uid)[vkdata$uid])
vkdata$Tcoeff <- tmp

# удаление дубликатов по UID
vkdata <- vkdata[!duplicated(vkdata$uid),]

# удалить бесполезные колонки: type, university, faculty, education_form, education_status, graduation
vkdata <- vkdata[,!(colnames(vkdata) %in% c('type', 'university', 'faculty', 'education_form', 'education_status', 'graduation'))]

# первичная фильтрация
gender <- c(0, 1)
names(gender) <- c('M', 'F')
selected <- vkdata[vkdata$sex == gender[[sex]],] # оставить только женский пол
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
selected <- selected[difftime(Sys.time(), as.POSIXct(selected$last_seen, origin='1970-01-01'), units='d') < activity,] # удалить неактивных в течении 20 дней
selected <- selected[,!colnames(selected) == 'last_seen'] # удалить более не нужную колонку "last_seen"

# конвертация bdate в возраст age
selected$bdate <- as.character(as.Date(selected[,'bdate'], format='%d.%m.%Y')) # преобразование содержимого поля в даты
selected$age <- as.numeric(round(difftime(Sys.Date(), as.Date(selected[,'bdate'], format='%Y-%m-%d'), units='d')/365, 1)) # пересчёт в года
selected <- selected[,!colnames(selected) == 'bdate'] # удаление более не нужной колонки bdate

# отсечение по возрасту
subselected <- selected[!is.na(selected$age),] # разбить по определённой величине bdate
selected <- selected[is.na(selected$age),] # ...и неопределённой
subselected <- subselected[subselected$age >= minAge,] # удалить моложе чем minAge лет если возраст не NA
subselected <- subselected[subselected$age <= maxAge,] # удалить старше чем maxAge лет если возраст не NA
selected <- rbind(subselected, selected) # склеить обратно в целый датафрейм
selected[is.na(selected$age), 'age'] <- 0 # заменить NA даты рождения на нули

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

# удалить символ "\n" из имён университетов и факультетов
selected$university_name <- gsub(pattern='\n', replacement='', selected$university_name, perl=T)
selected$faculty_name <- gsub(pattern='\n', replacement='', selected$faculty_name, perl=T)
# замена имён <NA> на 0 для упрощения работы
selected[is.na(selected$university_name), 'university_name'] <- 0
selected[is.na(selected$faculty_name), 'faculty_name'] <- 0
# замена пустых имён на 0 для упрощения работы
selected[selected$university_name == '', 'university_name'] <- 0
selected[selected$faculty_name == '', 'faculty_name'] <- 0

### ### вывод конечных результатов в табличный файл
write.table(file='data/HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)

