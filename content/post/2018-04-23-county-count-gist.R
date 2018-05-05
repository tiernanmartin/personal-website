# Setup ----

library(extrafont)
library(grDevices)
library(ggrepel)
library(patchwork)
library(placement)
library(rvest)
library(janitor) 
library(sf)
library(tidyverse) 

loadfonts(device = "postscript", quiet = TRUE)
loadfonts(device = "win", quiet = TRUE) 

# Custom ggplot2 themes ----

theme_min_blogdown <- function(){
  theme_minimal(base_size=14, base_family="Work Sans") %+replace% 
    theme(
      plot.title = element_text(family = "Work Sans Medium", size = 18, face = "bold", hjust = 0),
      plot.caption = element_text(family = "Work Sans Light", size = 10, hjust = 1, vjust = 0)
    )
}

theme_void_blogdown <- function(){
  theme_void(base_size=14, base_family="Work Sans") %+replace% 
    theme(
      plot.title = element_text(family = "Work Sans Medium", size = 18, face = "bold", hjust = 0),
      plot.caption = element_text(family = "Work Sans Light", size = 10, hjust = 1, vjust = 0)
    )
}

# Load data ----
nc <- read_sf(system.file("gpkg/nc.gpkg",package = "sf")) 

url <- "https://en.wikipedia.org/wiki/List_of_counties_in_North_Carolina"

nc_county_table <- read_html(url) %>% 
  html_node("table.wikitable") %>% 
  html_table(header = TRUE) %>% 
  as_tibble %>% 
  clean_names(case = "screaming_snake") %>% # remove unwanted characters from names and applies a specific case
  rename_all(~ str_remove_all(.x, "_\\d+")) %>% 
  mutate(NAME = str_remove(COUNTY," County")) %>% # transform COUNTY to match nc$NAME
  select(NAME, FIPS_CODE:MAP) 

# Join data ----

nc_ready <- nc %>% 
  select(NAME) %>% 
  full_join(nc_county_table, by = "NAME") %>% 
  rename(YEAR = CREATED) %>% # YEAR is a clearer column name
  st_sf


# Simple histogram ----

nc_ready %>% 
  st_set_geometry(NULL) %>% 
  ggplot(data = ., aes(x = YEAR)) +
  geom_histogram() + 
  theme_min_blogdown() + # a theme customized to match the aesthetics of this blog
  theme(axis.title = element_blank())


# Detailed histogram ----

years <- max(nc_ready$YEAR) - min(nc_ready$YEAR) + 1

nc_ready %>% 
  st_set_geometry(NULL) %>% 
  ggplot(data = ., aes(x = YEAR)) +
  geom_histogram(bins = years) + 
  scale_y_continuous(breaks = 0:10, minor_breaks = NULL) +
  theme_min_blogdown() + 
  theme(axis.title = element_blank()) 

# Bar chart ----

nc_ready %>% 
  st_set_geometry(NULL) %>% 
  group_by(YEAR) %>% 
  summarise(NAME = list(NAME) %>% map_chr(str_c, collapse = ", "),
            COUNT = sum(n())
            ) %>% 
  mutate(COUNT_CUMULATIVE = cumsum(COUNT)) %>% 
  ggplot(data = ., aes(x = YEAR, y = COUNT_CUMULATIVE)) +
  geom_col() +
  theme_min_blogdown() +
  theme(axis.title = element_blank())

# Final graphic ----

max_year <- nc_ready %>% 
  count(YEAR, sort = TRUE) %>% 
  slice(1) %>% 
  pluck("YEAR") 

max_year_header <- str_c(max_year,":", sep = "")

nc_year <- nc_ready %>% 
  group_by(YEAR) %>% 
  summarise(COUNTY_SEAT = list(COUNTY_SEAT),
            NAME = list(NAME),
            COUNT = sum(n()),
            COUNT_RUG = as.integer(COUNT > 0) * 4
            ) %>% 
  mutate(MAX_LGL = COUNT == as.integer(max(COUNT)),
         CUMULATIVE = cumsum(COUNT), 
         LABEL = map_chr(NAME, str_c, collapse = "\n"),
         LABEL = if_else(MAX_LGL, str_c(max_year_header, LABEL, sep = "\n"), ""),
         SHAPE = if_else(MAX_LGL, 1, 32 ) %>% as.integer()
         )   

county_lag <- nc_year %>% 
  mutate(CUMULATIVE_LAG = lag(CUMULATIVE)) %>% 
  gather(SOURCE, CUMULATIVE, CUMULATIVE, CUMULATIVE_LAG) %>% 
  arrange(YEAR, desc(SOURCE))

# Setup

title <- "1779: The Year of Many Counties"

subtitle <- "In the middle of the American Revolutionary War, North Carolina created nine new counties\nin a single year - more than any other year in the state's history."

caption <- "Source: Wikipedia <https://en.wikipedia.org/wiki/List_of_counties_in_North_Carolina>"

black_30pct <- adjustcolor( "black", alpha.f = 0.3)

black_30pct_no_opacity <- rgb(178,178,178, max = 255)

highlight_red <- "#f03838"
 
labels <- c("First 4 Counties", "All 100 Counties")

x_intercepts_major <- seq(1700,1900, by = 50)

x_intercepts_minor <- seq(1675,1875, by = 50)

y_intercepts_major <- seq(50,100, by = 50)

y_intercepts_minor <- seq(25,75, by = 50)
 
# Step plot
gg_step <- ggplot(data = nc_year, aes(x = YEAR, y = CUMULATIVE, label = LABEL)) + 
  geom_vline(xintercept = x_intercepts_major, alpha = .25, size = .25) +
  geom_vline(xintercept = x_intercepts_minor, alpha = .15, size = .15) +
  geom_hline(yintercept = y_intercepts_major, alpha = .25, size = .25) +
  geom_hline(yintercept = y_intercepts_minor, alpha = .15, size = .15) + 
  geom_col(mapping = aes(x = YEAR, y = COUNT_RUG, alpha = COUNT)) + 
  scale_alpha(range = c(0.2, 0.8)) +
  geom_step(size = 1) +  
  geom_ribbon(data = county_lag, aes(ymin = 0, ymax = CUMULATIVE), fill = black_30pct) +
  scale_shape_identity() +   
  geom_point(data = nc_year, aes(x = YEAR, y = CUMULATIVE, shape = SHAPE), fill = "white", size = 3, color = highlight_red) +
  geom_label_repel(min.segment.length = .1, segment.colour = "black",point.padding = 1.5,nudge_x = -1, nudge_y = 1, fill = "white", color = "black", size = 2.5,label.size = NA, box.padding = 0.5) +
  theme_min_blogdown() + 
  scale_y_continuous(breaks = c(4,100), labels = labels) + 
  theme(legend.position = "none",
        panel.grid = element_blank(), 
        axis.title = element_blank(), 
        axis.ticks = element_line(size = .5),
        axis.line = element_line(size = .5)) 

# Map plot
gg_map <- ggplot() + 
  geom_sf(data = filter(nc_ready, YEAR != max_year), fill = black_30pct_no_opacity, color = "black", size = .1) + 
  geom_sf(data = filter(nc_ready, YEAR == max_year), fill = "black", color = black_30pct_no_opacity, size = .25) +
  coord_sf(datum = NA) + 
  theme_void_blogdown() 

# Combined plot
gg_plot <-  gg_map + 
  gg_step + 
  plot_layout(ncol = 1, heights = c(1,1.15)) + # composing plots like this is made possible by the patchwork pacakge 
  plot_annotation(title, subtitle, caption,
                  theme = theme_min_blogdown()
        )  

gg_plot
