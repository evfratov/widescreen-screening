## загрузка нужных библиотек
# для парсинга XML и/или JSON - vk возвращает данные в таких форматах
library(XML)
library(rjson)
# и для работы с данными, напр. поддержкой data frames
library(plyr)

# команды для каталогов
setwd("~/Dropbox/evfr/HTS/")
load('.RData')

## поисковые параметры
# ---------------- #
# минимальный и максимальный возраст
minAge <- 21
maxAge <- 25
# пол
sex <- 'F'
# срок последней активности в днях
activity <- 20
# идеология - поле анкеты пользователей religion
ideology <- c('трансгуманизм', 'иммортализм')
# корни Т-слов для grep'анья
Twords <- c('трансгуман', 'иммортали', 'крион', 'бессмерт', 'нанотехн', 'сингулярн', 'геронтол', 'киборг', 'апгрейд')
# ---------------- #

## чтение списка целевых групп - табулированный файл со списком групп и категорий групп
groupsDB <- read.table('db/groupsDB.tab', header = T, stringsAsFactors = F)
## чтение чёрного списка - табулированныцй файл с ID юзеров
blacklist <- read.table('data/BlackList.tab', header = T, stringsAsFactors = F)


## скачивание полных списков участников всех целевых групп
# получить список имён групп для цикла
targets <- groupsDB$group
# обход циклом процедуры скачки для каждой группы
for (target in targets) {
	# диагностический вывод имени
  print(paste('  Group:  ', target))
	# пауза перед запросом чтобы не забанили на vk
  Sys.sleep(0.5)
	# запрос информации о группе к API vk по методу groups.getById с возвращаемым полем members_count с сохранением ответа во временный файл /tmp/<target>.txt
  download.file(paste0('https://api.vk.com/method/groups.getById?group_id=', target, '&fields=members_count'), destfile=paste0('/tmp/', target, '.txt'), method='wget', quiet = T)
	# составление переменной имени файла
  tmp_file <- paste0('/tmp/',target, '.txt')
	# парсинг JSON файла
  tmp <- fromJSON(file = tmp_file)
	# вытаскивание из JSON файла целевого значения числа пользователей из поля members_count
  member_count <- tmp$response[[1]]$members_count
	# вывод числа пользователей
  print(paste('    members  ', member_count))
	# удаление временного файла
  system(paste0('rm /tmp/', target, '.txt'))
	# вычисление числа шагов блочного скачивания всех членов группы (vk возвращает только по 1000 участников группы за возвращение) как округление к меньшему member_count / 1000
  stepSize <- as.integer(member_count / 1000)
	# пробег цикла по последовательности 0 .. <число шагов>
  for (s in seq(0, stepSize)) {
	# пауза чтобы не банили
    Sys.sleep(0.5)
	# запрос информации о группе к API vk по методу groups.getMembers с отступом вывода пользователей <номер_шага> x 1000 при выводе полей информации пользователей sex, bdate, city, country, last_seen, relation с сохранением во временный файл '/tmp/vkDB-<номер_шага>-<target>.txt' и приделанным в запрос токеном для доступа к информации пользователей к отключённым доступом у незареганных в vk
    download.file(paste0('https://api.vk.com/method/groups.getMembers?group_id=', target, '&offset=', s * 1000,'&fields=sex,bdate,city,country,last_seen,relation&access_token=', token), destfile = paste0('/tmp/vkDB-', s, '-', target, '.txt'), method = 'wget', quiet = T)
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

# сколько вообще людей набралось
nrow(vkdata)

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


### ### Фильтрация
# удалить бесполезные колонки
selected <- selected[,!(colnames(selected) %in% c('last_seen.platform'))]

# первичная фильтрация
gender <- c(0, 1)
names(gender) <- c('M', 'F')
selected <- selected[selected$sex == gender[[sex]],] # оставить только нужный пол
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
selected <- selected[!(selected$uid %in% blacklist$uid),]

# Вывод primaty table
write.table(selected, 'data/primary-HTS.tab', quote = T, sep = '\t', row.names = F, col.names = T)


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
source(file = 'WSS/ReversAgeEstimate.R')
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

### контейнер для данных групп, стен и активности
CorrData <- list()


### Получение данных о группах из selected и фильтрация спамерш
# ~~~~~~~~ #
# ~~~~~~~~ #
source(file = 'WSS/CaptureGroupsSubs.R')
# ~~~~~~~~ #
# ~~~~~~~~ #
# удаление 1000ниц (приближение 950) по группам при суммарном T-coeff == 1
selected <- selected[!((selected$ngroups >= 950) & rowSums(selected[,unique(groupsDB$category)]) == 1),]
# удаление удалённых uid из CorrData[['groups']]
CorrData[['groups']] <- CorrData[['groups']][names(CorrData[['groups']]) %in% paste('id', selected$uid, sep = '')]


### Скоринг по T-параметрам и числу групп
# f(ngroups) = lg(ngroups + 1), f(TRNSI) = (T + R + N + S + I) XX (2 0.5 0.5 0.25 0.5)
scoring <- function(x) {
  x <- x[c(unique(groupsDB$category), 'ngroups')]
  x <- as.integer(x)
  names(x) <- c(unique(groupsDB$category), 'ngroups')
  tmp <- 2 * x['T'] + 0.5 * x['R'] + 0.5 * x['N'] + 0.25 * x['S'] + 0.5 * x['I']
  tmp <- round(tmp - log10(x['ngroups'] + 1), 1)
  names(tmp) <- ''
  return(tmp)
}
selected$score <- apply(selected, 1, scoring)


### Захват мета-данных стен и загрузка комментариев
# ~~~~~~~~ #
# ~~~~~~~~ #
source(file = 'WSS/WallDownload.R')
# ~~~~~~~~ #
# ~~~~~~~~ #

### Подсчёт Т-ключевых слов на стенах
# подсчёт T-слов в комментариях для каждого пользователя
tmp <- sapply(CorrData[['wall']], function(x) length(grep(pattern = paste0(Twords, collapse = '|'), x)))
names(tmp) <- gsub('id', '', names(tmp))
# ограничение tmp по набору имён
tmp <- tmp[names(tmp) %in% selected[which(selected$uid %in% names(tmp)), 'uid']]
# запись в основной датафрейм
selected$Twords <- 0
selected[which(selected$uid %in% names(tmp)), 'Twords'] <- tmp
# повышение score за T-слова по закону log2(Twords) - log(wallsize) + 2 как центрование
selected$score <- selected$score + log2(selected$Twords + 1) - log10(selected$wallsize + 1) + 2
### вывод таблицы
# write.table(selected, 'data/HTS.tab', quote = T, sep = '\t', row.names = F, col.names = T)


### Получение дополнительного скоринга для правильно идеологических
selected$RiId <- 0
for (ideo in ideology) {
  # загрузка файла
  download.file(url = paste0('https://api.vk.com/method/users.search?sex=', gender[[sex]], '&religion=', ideo, '&count=1000', '&access_token=', token), destfile = '/tmp/ideo-reward.txt', method='wget', quiet = F)
  # парсинг JSON
  tmp <- fromJSON(file = '/tmp/ideo-reward.txt')$response
  # преобразование в вектор uid
  tmp[[1]] <- NULL
  tmp <- sapply(tmp, function(x) unlist(x))['uid',]
  # увеличение Score, величина награды 5
  selected[selected$uid %in% tmp,]$score <- selected[selected$uid %in% tmp,]$score + 5
  # задание метки правильной идеологии RiId
  selected[selected$uid %in% tmp,]$RiId <- selected[selected$uid %in% tmp,]$RiId + 1
}

### Получение тем и комментариев в Т-группах #
# ~~~~~~~~ #
# ~~~~~~~~ #
source(file = 'WSS/CaptureGroupActivity.R')
# ~~~~~~~~ #
# ~~~~~~~~ #
# увеличение Score: + ntopic и 1 + ln(ncomm + 1)
selected$score <- selected$score + selected$ntopics + round(log(selected$ncomm + 1), 1)


# сохранение результатов
write.table(file='data/HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)

### загрузка фоток
# ~~~~~~~~ #
# ~~~~~~~~ #
source(file = 'WSS/PhotoCapture.R')
# ~~~~~~~~ #
# ~~~~~~~~ #

save.image(file = '.RData')

### функция вывода данных
userdata <- function(cand) {
  v <- selected[selected$uid == cand,]
  print(v)
  print(CorrData[['comments']][[paste0('id', cand)]])
  CorrData[['groups']][[paste0('id', cand)]]
#   CorrData[['wall']][[paste0('id', cand)]]
}

### компактный вывод
head(selected[order(selected$score, decreasing = T), c('uid','first_name','last_name','age','T','R','N','S','I','score','Twords','RiId','ntopics','ncomm')], 20)


