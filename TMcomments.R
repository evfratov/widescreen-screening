library(XML)
library(tm)
library(SnowballC)
library(stringr)
library(parallel)
library(Rgraphviz)

setwd("~/Dropbox/evfr/HTS/")

source("http://bioconductor.org/biocLite.R")


### стоп-слова
# пока дефолтные для tm - хреновые
our_stop_words <- c('без', 'более', 'больше', 'будет', 'будто', 'бы', 'был', 'была', 'были', 'было', 'быть', 'вам', 'вас', 'ведь', 'весь', 'вдоль', 'вдруг', 'вместо', 'вне', 'вниз', 'внизу', 'внутри', 'во', 'вокруг', 'вот', 'впрочем', 'все', 'всегда', 'всего', 'всех', 'всю', 'вы', 'где', 'да', 'давай', 'давать', 'даже', 'для', 'до', 'достаточно', 'другой', 'его', 'ему', 'ее', 'её', 'ей', 'если', 'есть', 'ещё', 'еще', 'же', 'за', 'за', 'исключением', 'здесь', 'из', 'из-за', 'из', 'или', 'им', 'иметь', 'иногда', 'их', 'как-то', 'кто', 'когда', 'кроме', 'кто', 'куда', 'ли', 'либо', 'между', 'меня', 'мне', 'много', 'может', 'мое', 'моё', 'мои', 'мой', 'мы', 'на', 'навсегда', 'над', 'надо', 'наконец', 'нас', 'наш', 'не', 'него', 'неё', 'нее', 'ней', 'нет', 'ни', 'нибудь', 'никогда', 'ним', 'них', 'ничего', 'но', 'ну', 'об', 'однако', 'он', 'она', 'они', 'оно', 'опять', 'от', 'отчего', 'очень', 'перед', 'по', 'под', 'после', 'потом', 'потому', 'потому', 'что', 'почти', 'при', 'про', 'раз', 'разве', 'свою', 'себя', 'сказать', 'снова', 'со', 'совсем', 'так', 'также', 'такие', 'такой', 'там', 'те', 'тебя', 'тем', 'теперь', 'то', 'тогда', 'того', 'тоже', 'той', 'только', 'том', 'тот', 'тут', 'ты', 'уже', 'хоть', 'хотя', 'чего', 'чего-то', 'чей', 'чем', 'через', 'что', 'что-то', 'чтоб', 'чтобы', 'чуть', 'чьё', 'чья', 'эта', 'эти', 'это', 'эту', 'этого', 'этом', 'этот', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять', 'ноль')
# Т-слова, с учётом сжатия повторяющихся букв
Twords <- c('трансгуман', 'имортали', 'крион', 'бесмерт', 'нанотехн', 'сингулярн', 'геронтол', 'киборг', 'апгрейд')

### парсинг библиотеки и получение списка TDM
# сбор Corpus'а
tcp <- Corpus(DirSource('/media/data/temp/'))
# подготовка для преобразований содержимого
docs <- tm_map(tcp, PlainTextDocument)
# именование
uidnames <- gsub('.txt', '', gsub('\\/.+\\/', '', DirSource('/media/data/temp/')$filelist))
names(docs) <- uidnames
# преобразования текста
docs <- tm_map(docs, content_transformer(tolower)) # в нижний регистр
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "<.+?>", " "))) # убрать всякий XML
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "\t", " "))) # убрать Tab
docs <- tm_map(docs, removePunctuation, preserve_intra_word_dashes = T) # удалить пунктуацию
docs <- tm_map(docs, removeNumbers) # удалить числа
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "[a-zа-я]{18,}", " "))) # убрать слова длиннее 18
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "[^a-zа-я]", " "))) # убрать всякий трэш
docs <- tm_map(docs, removeWords, c(stopwords('ru'), our_stop_words)) # удалить стоп-слова русского
docs <- tm_map(docs, removeWords, stopwords('en')) # удалить стоп-слова английского
docs <- tm_map(docs, content_transformer(function(x) stemDocument(x, language = 'ru'))) # стемминг русского
docs <- tm_map(docs, content_transformer(function(x) stemDocument(x, language = 'en'))) # стемминг английского
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "(.)\\1+", "\\1"))) # сжать всё повторяющееся 2 и больше раз
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, " [a-zа-я]{1,2} ", " "))) # убрать слова в 1-2 буквы
docs <- tm_map(docs, stripWhitespace) # сжать пробелы
# построение TDM
TDM <- DocumentTermMatrix(docs)
# сжатие TDM, удалить термин реже каждого сотого
TDM <-removeSparseTerms(TDM, 0.99)

# взятие хоть сколько-то частых, намер термин в каждом nGrad-ном документе
nGrad <- 20
sTDM <- TDM[,which(colnames(TDM) %in% findFreqTerms(TDM, nDocs(TDM)/nGrad))]
uTDM <- removeSparseTerms(sTDM, 0.5)
#rm(TDM)

nTDM <- removeSparseTerms(uTDM, 0.1)
heatmap(log(t(as.matrix(nTDM))+1), scale = 'col')




inspect(TDM[1, 1:20])
