# Start only with HTS.R !!!

# прочитать файл
RAE <- read.table('data/data_for_RAE.tab', header = T, stringsAsFactors = F)

# время ожидания в c
time.threshold <- 9
# перебор всех пользователей по имени и фамилии в целевом диапазоне возраста
count <- 0
print(paste('Approx time', round(nrow(RAE) * time.threshold / 3600), 'h'))
for (n in seq(1, nrow(RAE))) {
  f_name <- RAE[n, 'first_name']
  l_name <- RAE[n, 'last_name']
  uid <- RAE[n, 'uid']
  # проверка возраста на принадлежность диапазону
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
      RAE[RAE$uid == uid, 'age'] <- minAge - 1
    } else {
      # метка пользователя как вне диапазона
      print('    excluded')
      count <-  count + 1
    }
  } else {
    # метка пользователя как вне диапазона
    print('    excluded')
    count <-  count + 1
  }
  system(paste0('rm /tmp/', uid, '.txt'))
}
# подсчёт исключённых
print(paste(count, ' Excluded'))
passed <- RAE[RAE$age == (minAge - 1),]
rm(RAE)
file.remove('data/data_for_RAE.tab')

### ### вывод конечных результатов в табличный файл
write.table(file = 'data/data_RAE_pass.tab', x = passed, sep='\t', row.names=F, col.names=T, quote=T)
rm(passed)
