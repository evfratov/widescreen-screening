# Start only with HTS.R !!!

# создание приоритетной выборки - ненулевая сетевая или идеологическая активность, или score > 1
subselected <- selected[(selected$RiId > 0) | (selected$ncomm > 0) | (selected$ntopics > 0) | (selected$score > 1),]

# время ожидания в c
time.threshold <- 9

# загрузка фотографий с формировкнием альбомов в каталоге
dir.create(path = '~/PhotoCapture')
for (uid in subselected$uid) {
  # загрузка ответа
  filename <- paste0('/tmp/photo-', uid, '.txt')
  # максимум - 100 фото
  Sys.sleep(time.threshold)
  download.file(url = paste0('https://api.vk.com/method/photos.get?owner_id=', uid, '&album_id=profile', '&count=100', '&access_token=', token), destfile = filename, method='curl', quiet = T)
  # парсинг JSON
  tmp <- fromJSON(file = filename)$response
  # получение фото типа src_big, в новом API заменить надо на photo_604 и pid на id
  tmp <- sapply(tmp, function(x) unlist(x)[c('pid', 'src_big')])
  
  # загрузка фотографий со сброркой альбома
  curDir <- paste0('~/PhotoCapture/', uid)
  dir.create(path = curDir)
  # проверка на ненулёвость
  if (length(tmp) > 0) {
    for (n in 1:ncol(tmp)) {
      link <- tmp['src_big', n]
      pid <- tmp['pid', n]
      Sys.sleep(time.threshold)
      outfile <- paste0(curDir, '/', pid, '.jpg')
      download.file(url = link, destfile = outfile, method = 'curl', quiet = F, extra = '--connect-timeout 30 -m 40 --retry 5 --retry-delay 10')
      print(file.info(outfile))
    }
  }
}
