# SETUP ----

library(tidyverse)


# LOAD DATA ----

csv_url <- "https://data.kingcounty.gov/resource/es38-6nrz.csv"

agencies <- read_csv(csv_url)


# CLEAN DATA ----

# First approach (didn't work)

zwsp_pattern_first <- "<U+200B>"

agencies %>% 
  mutate_all(funs(str_replace_all(.,zwsp_pattern_first,""))) %>% 
  slice(1:5) %>% 
  as.data.frame()

# Second approach: convert all UTF-8 to ASCII (worked)

agencies %>% 
  mutate_all(funs(iconv(.,'utf-8', 'ascii', sub=''))) %>% 
  slice(1:5) %>% 
  as.data.frame()

# Third approach: replace <U+200B> with ""

zwsp_pattern_second <- "\\u200b"

agencies %>% 
  mutate_all(funs(str_replace_all(.,zwsp_pattern_second,""))) %>% 
  slice(1:5) %>% 
  as.data.frame()