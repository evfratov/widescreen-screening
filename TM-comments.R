library(XML)
library(tm)
library(stringr)
library(parallel)
library(Rgraphviz)

source("http://bioconductor.org/biocLite.R")

setwd("~/Dropbox/evfr/HTS/")

# стоп-слова
### пока дефолтные для tm

# парсинг библиотеки и получение списка TDM
# сбор Corpus'а
tcp <- Corpus(DirSource('db/walls/'))
docs <- tm_map(tcp, PlainTextDocument)
docs <- tm_map(docs, content_transformer(tolower)) # в нижний регистр
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "<.+?>", " "))) # убрать всякий XML
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "\t", " "))) # убрать Tab
docs <- tm_map(docs, removePunctuation, preserve_intra_word_dashes = T) # удалить пунктуацию
docs <- tm_map(docs, removeNumbers) # удалить числа
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "[a-z]{18,}", " "))) # убрать слова длиннее 20
docs <- tm_map(docs, removeWords, stopwords('ru')) # удалить стоп-слова
docs <- tm_map(docs, stripWhitespace) # сжать пробелы

# построение TDM
docsTDM <- TermDocumentMatrix(docs)

