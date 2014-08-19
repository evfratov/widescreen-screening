# Start only with HTS.R !!!

# для точности прочитать файл вывода ещё раз
# selected <- read.table('data/HTS-full.tab', header = T, stringsAsFactors = F)

### реверсная оценка возраста
subselected <- selected[selected$age == 0,] # выделить поднабор с неопределённым возрастом
print(paste(nrow(subselected), 'from', nrow(selected), 'didn`t set the age'))

# время ожидания в c
time.threshold <- 10
# перебор всех пользователей по имени и фамилии в целевом диапазоне возраста
count <- 0
for (n in seq(1, nrow(subselected))) {
  f_name <- subselected[n, 'first_name']
  l_name <- subselected[n, 'last_name']
  uid <- subselected[n,'uid']
  # проверка возраста на валидность
  valid <- 0
  download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=14&age_to=80', '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget')
  Sys.sleep(time.threshold)
  tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
  tmp <- xmlToDataFrame(tmp)
  print(uid)
  # проверка ненулёвости вывода валидации
  if (tmp[1,1] != 0) {
    # проверка наличия пользователя в списке валидации
    if (sum(tmp$uid %in% uid) > 0) {
      # флаг валидного возраста
      valid <- 1
      print('    valid age')
    } else {
      print('    invalid age')
      # for invalid age in range set age as - 1
      selected[selected$uid == uid, 'age'] <- -1
    }
  } else {
    print('    null validation')
    # for invalid age in range set age as - 1
    selected[selected$uid == uid, 'age'] <- -1
  }
  system(paste0('rm /tmp/', uid, '.txt'))
  
  # проверка возраста на принадлежность диапазону
  if (valid == 1) {
    download.file(paste0('https://api.vk.com/method/users.search.xml?q=', f_name, ' ', l_name, '&count=1000', '&age_from=', minAge,'&age_to=', maxAge, '&access_token=', token), destfile=paste0('/tmp/', uid, '.txt'), method='wget')
    Sys.sleep(time.threshold)
    tmp <- xmlParse(paste0('/tmp/', uid, '.txt'))
    tmp <- xmlToDataFrame(tmp)
    # проверка ненулёвости вывода принадлежности
    if (tmp[1,1] != 0) {
      # проверка наличия пользователя в выводе принадлежности
      if (sum(tmp$uid %in% uid) > 0) {
        # подтверждение нормального возраста
        print('    in range')
        # for detected age in range set age as minAge - 1
        selected[selected$uid == uid, 'age'] <- minAge - 1
      } else {
        # исключение пользователя из базы как вне диапазона
        print('    excluded')
        selected <- selected[selected$uid != uid,]
        count <-  count + 1
      }
    } else {
      # исключение пользователя из базы как вне диапазона
      print('    excluded')
      selected <- selected[selected$uid != uid,]
      count <-  count + 1
    }
    system(paste0('rm /tmp/', uid, '.txt'))
  }
}
# подсчёт исключённых
print(paste(count, ' Excluded'))

### ### вывод конечных результатов в табличный файл
write.table(file='data/HTS-full-RAE.tab', x=selected, sep='\t', row.names=F, col.names=T, quote=T)

