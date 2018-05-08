# Setup ----

library(lubridate)
library(tidyverse)

# Create a ggplot theme
theme_min_timeline <- function(){
  theme_minimal() %+replace%
    theme(
      axis.ticks.x = element_line(size = .5),
        axis.line.x = element_line(size = .5)
    )
}

# Data ----

data(economics)

pce <- economics %>% 
  select(PCE = pce,
         DATE = date)

# Check geom_step ----
ggplot(data = pce, aes(x = DATE, y = PCE)) +
  geom_step() +
  theme_min_timeline()


decade_breaks <- seq(as.Date("1960/1/1"),as.Date("2020/1/1"), "10 years")

# Add lagged column ----

pce_lag <- pce %>% 
  arrange() %>% 
  mutate(PCE_ORIG = PCE,
         PCE_LAG = lag(PCE)) %>% 
  gather(SOURCE, PCE_FILL, matches("PCE_")) %>% 
  arrange(DATE, SOURCE)

# Check the plot ----
ggplot(data = pce_lag, aes(x = DATE, y = PCE)) +
  geom_step() +
  geom_ribbon(aes(x = DATE, ymin = 0, ymax = PCE_FILL), alpha = 1/5) +
  theme_min_timeline()


# Advanced: filled step plot at different levels of resolution ---- 

pce_by_date <- economics %>% 
  transmute(PCE = pce,
            DAY = date,
            QUARTER = floor_date(DAY, "quarter"), 
            YEAR = floor_date(DAY, "year"), 
            DECADE = as.Date(cut(DAY, decade_breaks <- seq(as.Date("1960/1/1"),as.Date("2020/1/1"), "10 years")))) %>% 
  gather(DATE_TYPE, DATE, -PCE) %>%  
  group_by(DATE_TYPE, DATE) %>% 
  summarise(PCE = min(PCE)) %>% 
  ungroup

pce_with_lag <-  pce_by_date %>% 
  mutate(DATE_TYPE = fct_infreq(factor(DATE_TYPE))) %>% 
  group_by(DATE_TYPE) %>% 
  arrange(DATE) %>% 
  mutate(PCE_ORIG = PCE,
         PCE_LAG = lag(PCE)) %>% 
  gather(SOURCE, PCE_FILL, matches("PCE_")) %>% 
  arrange(DATE, SOURCE) %>% 
  ungroup


# Plot ----
ggplot(data = pce_with_lag) +
  geom_step(aes(x = DATE, y = PCE)) +
  geom_ribbon(aes(x = DATE, ymin = 0, ymax = PCE_FILL, fill = DATE_TYPE), alpha = 1/5) +
  facet_wrap(~DATE_TYPE) + 
  theme_minimal() +
  theme(axis.ticks.x = element_line(size = .5),
        axis.line.x = element_line(size = .5)) +
  scale_x_date(breaks = decade_breaks, name = "Year", date_breaks="10 years", date_minor_breaks="5 years", expand=c(0,0), date_labels = "%Y") +
  theme_min_timeline()

# Resources ----
#
#   - Stackoverflow - plotting daily rainfall data using geom_step: https://stackoverflow.com/a/42210264/5170276
#   - Stackoverflow - date_minor_breaks in ggplot2: https://stackoverflow.com/a/39258418/5170276