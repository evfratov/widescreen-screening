# Start only with HTS.R !!!

# для точности прочитать файл вывода ещё раз
# selected <- read.table('HTS.tab', header = T, stringsAsFactors = F)

### реверсная оценка возраста
subselected <- selected[selected$age == 0,] # выделить поднабор с неопределённым возрастом
print(paste(nrow(subselected), 'from', nrow(selected), 'didn`t set the age'))

# перебор всех пользователей по имени и фамилии в целевом диапазоне возраста
count <- 0
for (n in seq(1, nrow(subselected))) {
  f_name <- subselected[n, 'first_name']
  l_name <- subselected[n, 'last_name']
  uid <- subselected[n,'uid']
  # проверка возраста на валидность
  valid <- 0
  file.create(paste0('/tmp/', uid, '.txt'))
  while (file.info(paste0('/tmp/', uid, '.txt'))$size == 0) {
    try(download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=14&age_to=80', '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget', quiet = T))
    Sys.sleep(0.4)
  }
  tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
  tmp <- xmlToDataFrame(tmp)
  print(uid)
  if (tmp[1,1] != 0) {
    if (sum(tmp$uid %in% uid) > 0) {
      valid <- 1
      print('    valid age')
    }
  } else {
    print('    fail validation')
  }
  system(paste0('rm /tmp/', uid, '.txt'))
  
  # проверка возраста на принадлежность диапазона возраста
  if (valid == 1) {
    file.create(paste0('/tmp/', uid, '.txt'))
    while (file.info(paste0('/tmp/', uid, '.txt'))$size == 0) {
      try(download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=', minAge,'&age_to=', maxAge, '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget', quiet = T))
      Sys.sleep(0.4)
    }
    tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
    tmp <- xmlToDataFrame(tmp)
    if (tmp[1,1] != 0) {
      if (sum(tmp$uid %in% uid) > 0) {
        print('    in range')
        # for detected age in range set age as minAge - 1
        selected[selected$uid == uid, 'age'] <- minAge - 1
      } else {
        print('    excluded')
        selected[selected$uid != uid,]
        count <-  count + 1
      }
    } else {
      print('    excluded')
      selected[selected$uid != uid,]
      count <-  count + 1
    }
    system(paste0('rm /tmp/', uid, '.txt'))
  }
}
# подсчёт исключённых
print(paste(count, ' Excluded'))

### ### вывод конечных результатов в табличный файл
write.table(file='HTS.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)

