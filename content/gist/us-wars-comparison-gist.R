# Setup ----

library(Ecdat)
library(janitor)
library(ggrepel)
library(rvest)
library(scales)
library(patchwork)
library(tidyverse)

# Load Data: USGDPpresidents ----

data("USGDPpresidents")


# Transform Data: USGDPpresidents ----

wars_ecdat <- USGDPpresidents %>% 
  as_tibble %>% 
  clean_names(case = "screaming_snake") %>% 
  transmute(YEAR, 
            WAR = as.character(na_if(WAR, ""))) %>% 
  drop_na %>% 
  arrange(YEAR) %>% 
  group_by(WAR) %>% 
  summarise(START = as.integer(first(YEAR)),
            END = as.integer(last(YEAR)))

# Load Data: Wikipedia ----

url <- "https://en.wikipedia.org/wiki/List_of_wars_involving_the_United_States"

tbl_names <- c("CONFLICT", "COMBATANT_1", "COMBATANT_2", "RESULT")

not_all_na <- function(x) {!all(is.na(x))} 

start_year <- "(?<=\\()\\d{4}"

end_year <- "\\d{4}(?=\\)|\\[)"

wars_wiki_raw <- read_html(url) %>%  
  html_nodes("table.wikitable") %>% 
  map_df(html_table, header = TRUE) %>%  
  as_tibble %>% 
  set_names(tbl_names)
   
# Transform Data: Wikipedia ----

wars_wiki <- wars_wiki_raw %>%  
  separate(CONFLICT, LETTERS, "\n") %>% 
  select_if(not_all_na) %>% 
  transmute(CONFLICT = A, 
            B = str_replace_all(B,"present","2018"),
            START = str_extract(B, start_year) %>% as.integer(),
            END = str_extract(B, end_year) %>% as.integer()
            ) %>% 
  select(WAR = CONFLICT,
         START, 
         END)
  
# Join Data ----

wars_join <- bind_rows("ECDAT" = wars_ecdat, "WIKIPEDIA" = wars_wiki, .id = "SOURCE") 

# Prepare Data for Plotting ----

wars_ready <- wars_join %>% 
  mutate(WAR_LABEL = str_replace_all(WAR," ","\n"),
         WAR_LABEL = str_replace_all(WAR_LABEL, "-", "-\n"),
         WAR_LABEL = if_else(SOURCE %in% "WIKIPEDIA", "", WAR_LABEL),
         MID = map2_dbl(START, END, ~ mean(c(.x,.y), trim = 0.5,na.rm = TRUE)))

gdp <- USGDPpresidents %>% 
  as_tibble %>% 
  clean_names(case = "screaming_snake") %>% 
  transmute(YEAR = as.integer(YEAR),
            ECDAT = REAL_GD_PPER_CAPITA,
            WIKIPEDIA = REAL_GD_PPER_CAPITA) %>% 
  gather(SOURCE, GDP, -YEAR) %>% 
  filter(YEAR >= min(wars_ready$START)) 

# Create plots ----

gg_labels <- ggplot(data = wars_ready, aes(x = MID, y = 0, label = WAR_LABEL)) +
  geom_text_repel(size = 3, point.padding = NA, segment.colour = NA, nudge_x = 0, nudge_y = 0) +
  theme_void() 


gg_plots <- ggplot(data = wars_ready ) +
  geom_rect(mapping = aes(xmin = START, xmax = END, ymin = 0, ymax = Inf), 
            fill = "black", alpha = .15) + 
  scale_y_continuous(limits = c(0, max(gdp$GDP, na.rm = TRUE))) +
  facet_wrap(~ SOURCE, ncol = 1, strip.position = "left") +
  geom_step(data = gdp, aes(x = YEAR, y = GDP), inherit.aes = FALSE) + 
  labs(y = "GDP per capita", x = NULL) +
  scale_y_continuous(labels = scales::dollar) +
  theme_minimal() +
  theme(axis.ticks.x = element_line(size = .5),
        axis.line.x = element_line(size = .5))

# Combine plots ----

gg_complete <- gg_labels + gg_plots + plot_layout(ncol = 1, heights = c(1,5))

gg_complete
