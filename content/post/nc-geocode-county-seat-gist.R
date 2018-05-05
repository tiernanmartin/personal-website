library(placement)
library(rvest)
library(janitor) 
library(sf)
library(tidyverse)   

nc <- read_sf(system.file("shape/nc.shp", package="sf"))

glimpse(nc)

url <- "https://en.wikipedia.org/wiki/List_of_counties_in_North_Carolina"

nc_county_table <- read_html(url) %>% 
   html_node("table.wikitable") %>% 
   html_table(header = TRUE) %>% 
  as_tibble %>% 
  clean_names(case = "screaming_snake") %>% 
  rename_all(~ str_remove_all(.x, "_\\d"))

geocode_fun <- function(address){
    geocode_url(address, 
                auth="standard_api", 
                privkey="AIzaSyAC19c3TtQwrSiQYKYDaf-9nDIqahirnD8",
                clean=TRUE, 
                add_date='today', 
                verbose=TRUE) 
  }

nc_county_seat_sf <- nc_county_table %>% 
  transmute(NAME = str_remove(COUNTY," County"),
            YEAR_CREATED = CREATED,
            COUNTY_SEAT,
            COUNT_SEAT_FULL = str_c(COUNTY_SEAT, ", NC"),
            geom_county_seat = map(COUNT_SEAT_FULL, geocode_fun)
            ) %>% 
  unnest %>% 
  clean_names(case = "screaming_snake") %>%   
  st_as_sf(coords = c("LNG", "LAT")) %>% 
  select(NAME, YEAR_CREATED, COUNTY_SEAT) %>% 
  st_set_crs(4326)  
nc_nest <- nc %>%   
  group_by(NAME) %>% 
  nest(.key = "county") 

print(nc_nest, n= 3)
nc_join <- nc_county_seat_sf %>% 
  group_by(NAME) %>% 
  nest(.key = "county_seat") %>%  
  left_join(nc_nest, by = "NAME")

nc_ready <- nc_join %>% 
  mutate(YEAR_CREATED = map_int(county_seat, "YEAR_CREATED"),
         COUNTY_SEAT = map_chr(county_seat, "COUNTY_SEAT") ,
         NAME = NAME,
         geom_county_seat = map(county_seat, st_geometry) %>% invoke(c ,.),
         geom_county = map(county, st_geometry) %>% invoke(c,.)) %>%  
  st_sf %>% 
  st_set_geometry("geom_county")

nc_ready_seat <- st_set_geometry(nc_ready, "geom_county_seat")

par(mar= rep(0,4))
plot(st_geometry(nc_ready), col = "black", border = "white")
plot(st_geometry(nc_ready_seat), pch = 43, add = TRUE, col = "white")