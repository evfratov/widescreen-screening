# Start only with HTS.R !!!

# время ожидания в c
time.threshold <- 1
# число скачиваемых фото
photos <- 20

# загрузка фотографий с формировкнием альбомов в каталоге
dir.create(path = '~/PhotoCapture')
for (uid in selected$uid) {
  # загрузка ответа
  filename <- paste0('/tmp/photo-', uid, '.txt')
  Sys.sleep(1)
  download.file(url = paste0('https://api.vk.com/method/photos.get?owner_id=', uid, '&album_id=profile', '&count=', photos, '&access_token=', token), destfile = filename, method='curl', quiet = T)
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
      download.file(url = link, destfile = outfile, method = 'curl', quiet = T, extra = '--connect-timeout 10 --retry 3 --retry-delay 4')
      print(file.info(outfile))
    }
  }
}
