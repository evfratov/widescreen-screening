library(XML)
library(tm)
library(stringr)
library(parallel)
library(Rgraphviz)

source("http://bioconductor.org/biocLite.R")

setwd("~/Dropbox/evfr/HTS/")
load(".RData")
loadhistory(file = ".Rhistory")

# стоп-слова


# анализ коментов
fl <- file('db/walls/10086877.txt')
tmp <- readLines(fl)
close(fl)

# сбор Corpus'а
tcp <- Corpus(VectorSource(tmp))
docs <- tm_map(tcp, PlainTextDocument)
docs <- tm_map(docs, content_transformer(tolower)) # в нижний регистр
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "<.+?>", " "))) # убрать всякий XML
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "\t", " "))) # убрать Tab
docs <- tm_map(docs, removePunctuation, preserve_intra_word_dashes = T) # удалить пунктуацию
docs <- tm_map(docs, removeNumbers) # удалить числа
docs <- tm_map(docs, content_transformer(function(x) str_replace_all(x, "[a-z]{18,}", " "))) # убрать слова длиннее 20
docs <- tm_map(docs, removeWords, stopwords('ru')) # удалить стоп-слова
docs <- tm_map(docs, stripWhitespace) # сжать пробелы
docs[[6]]

# построение TDM
docsTDM <- TermDocumentMatrix(docs)
findFreqTerms(docsTDM, 5)


