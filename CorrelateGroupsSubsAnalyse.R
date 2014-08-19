# Start only with HTS.R !!!

# для точности прочитать файлы вывода ещё раз
# selected <- read.table('data/HTS-full-RAE.tab', header = T, stringsAsFactors = F)

#load('.CorrDat')

# create list of all group names with repeats
groups <- unlist(sapply(CorrData[['groups']], function(x) x$screen_name))
# remove repeats and very rare membership - less than 10
groups <- names(table(groups)[table(groups) > 10])


# prepare storage for occurece matrix
GroupOccurMtx <- matrix(0, nrow = length(groups), ncol = length(names(CorrData[['groups']])))
rownames(GroupOccurMtx) <- groups
colnames(GroupOccurMtx) <- names(CorrData[['groups']])
# count occurece of users in groups
for (uid in names(CorrData[['groups']])) {
  # get all user groups
  user_groups <- CorrData[['groups']][[uid]]$screen_name
  # keep non-rare groups only
  user_groups <- user_groups[user_groups %in% groups]
  GroupOccurMtx[user_groups,uid] <- 1
}

GOMRAE <- GroupOccurMtx[,gsub('id', '', colnames(GroupOccurMtx)) %in% selected$uid]
GOMRAE <- GOMRAE[rowSums(GOMRAE) > 0,]

write.table(GroupOccurMtx, 'data/GroupOccurenceMtx.tab', quote = T, sep = "\t", row.names = T, col.names = T)
write.table(GOMRAE, 'data/GroupOccurenceMtx-RAE.tab', quote = T, sep = "\t", row.names = T, col.names = T)
