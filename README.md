widescreen-screening
====================

The vk-API using accounts data miner for people searching, written in R

Using: open HTS.R in R IDE, add token, target group list, parameters, launch, wait and parse the data with pleasure.

Instructions:

1. You have to register an vk app (at once) here https://vk.com/editapp?act=creat.e
2. You have to compile https link with permissions from here http://vk.com/dev/auth_mobile and obtain the token (at once too).
3. Insert token value at variable 'token' (Token will work 24 h. only) in code of HTS.R file.
4. Set target groups as list into variable 'target'.
5. Change the many filtration parameters into 50 - 100 lines of code.
6. Prepare directories (db/subs, db/groups, db/walls and /tmp/).
7. Launch all code of HTS.R and wait of several hours.
8. Parsing and output automated.

* Data for groups, subscriptions and wall comments now is not analysing (exclude T-coefficient), you can analyse this data by any methods.

Workflow:

HTS -> CaptureGroupsSubs -> CorrelateGroupsSubsAnalyse -> ReversAgeEstimate -> WallDownload -> TMcomments

WORK IN PROGRESS
