library("data.table")
library("tidyverse")
library("lubridate")
library("stringr")

setwd("C:\\Users\\lillcam\\Documents\\IMP\\movement_value_management")

data5 = fread("movement_value.csv")
data5 = as.data.frame(data5)
names(data5)

fase2 = str_split(data5$d.Source, "-", simplify = TRUE)[,1]
data5$fase2 = fase2

data5$origen_real = data5$fase2

data5$origen_real[(data5$p.LoadX > 73030.50)&
                    (data5$p.LoadX < 73471.23)&
                    (data5$p.LoadY > 481024.42)&
                    (data5$p.LoadY < 481817.01)] = "STA"

data5$origen_real[(data5$p.LoadX > 72680.84)&
                    (data5$p.LoadX < 73030.50)&
                    (data5$p.LoadY > 481000.00)&
                    (data5$p.LoadY < 481840.00)] = "OBSIN"

data5$origen_real[(data5$p.LoadX > 72198.38)&
                    (data5$p.LoadX <= 72680.84)&
                    (data5$p.LoadY > 481000.00)&
                    (data5$p.LoadY < 481840.00)] = "SBSIN"

data5$origen_real[(data5$p.LoadX > 73464.37)&
                    (data5$p.LoadX <= 73977.89)&
                    (data5$p.LoadY > 481048.38)&
                    (data5$p.LoadY < 481746.06)] = "SBSE/SASIN/SHIA-E/OOARG"

data5$origen_real[(data5$p.LoadX > 72200.67)&
                    (data5$p.LoadX <= 72500.00)&
                    (data5$p.LoadY > 480799.68)&
                    (data5$p.LoadY < 481000.00)] = "STCH2"

data5$origen_real[(data5$p.LoadX > 70406.40)&
                    (data5$p.LoadX <= 71700.00)&
                    (data5$p.LoadY > 482400.30)&
                    (data5$p.LoadY < 483300.00)] = "SHIM/SHIB"

data5$origen_real[(data5$p.LoadX > 71746.70)&
                    (data5$p.LoadX < 72213.82)&
                    (data5$p.LoadY > 481846.53)&
                    (data5$p.LoadY < 482793.61)] = "SHIA-N/SACY"

data5$origen_real[(data5$p.LoadX > 72207.98)&
                    (data5$p.LoadX < 72845.00)&
                    (data5$p.LoadY > 481822.01)&
                    (data5$p.LoadY < 483000.00)] = "OBSIB/SIBERIA"

data5$origen_real[(data5$p.LoadX > 72224.33)&
                    (data5$p.LoadX < 72427.53)&
                    (data5$p.LoadY > 481970.00)&
                    (data5$p.LoadY < 482372.04)] = "SHIAONSIB"

data5$origen_real[(data5$p.LoadX > 73346.79)&
                    (data5$p.LoadX < 73751.69)&
                    (data5$p.LoadY > 479871.46)&
                    (data5$p.LoadY < 480247.67)] = "STRA"

data5$origen_real[(data5$p.LoadX > 73100.21)&
                    (data5$p.LoadX < 73550.00)&
                    (data5$p.LoadY > 479548.76)&
                    (data5$p.LoadY < 479871.46)] = "SACH"

data5 = as_tibble(data5)


data5$date_time = ymd_hms(data5$d.DateTime)

data5$year  = year(data5$date_time)
data5$month = month(data5$date_time)
data5$day   = day(data5$date_time)
data5$hour  = hour(data5$date_time)

#data5[,c("date_time", "year", "month", "day", "hour")]


#####################################################
#####################################################
#####################################################

cut =
  data5 %>%
  filter(d.To == "CH02") %>%
  filter(!is.na(d.Tonnage)) %>%
  filter(d.Tonnage > 0) %>%
  filter(!is.na(cut)) %>%
  filter(cut >= 0) %>%  
  group_by(year, month, day, hour) %>%
  summarise(cut = (sum(cut * d.Tonnage)/sum(d.Tonnage)))

d.Tonnaje =
  data5 %>%
  filter(d.To == "CH02") %>%
  filter(!is.na(d.Tonnage)) %>%
  filter(d.Tonnage > 0) %>%
  group_by(year, month, day, hour) %>%
  summarise(d.Tonnage = sum(d.Tonnage))

data_hora = left_join(cut, d.Tonnaje, 
                      by = c("year", "month", "day", "hour"))

fwrite(data_hora, "data_hora.csv")
