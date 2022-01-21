########################################################
### Código original: 'CMS-BlockGradeData_V1.7.sql'
### Generado por: Modular Mining
### Original distribuido por: Camila Cancino
### Editado y generado en R por: Camilo Lillo
### Fecha: 2022-01-04

query_powerview = function(inicial, final){

query1 = paste("
SELECT [shiftdate], [shiftindex]
FROM [PowerView].[dbo].[hist_exproot] as he WITH (NOLOCK) WHERE date <= DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, '", inicial,"')) and
date > DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, '", inicial,"')) - he.len
", sep = "")

query2 = paste("
SELECT [shiftdate], [shiftindex]
FROM [PowerView].[dbo].[hist_exproot] as he WITH (NOLOCK) WHERE date <= DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, '", final, "')) - 1 and
date > DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, '", final, "')) - 1 - he.len
", sep = "")

A1 = dbGetQuery(con1, query1)
A2 = dbGetQuery(con1, query2)

query3 = paste("
SELECT *
FROM [PowerView].[dbo].[hist_dumps] as hd
where hd.shiftindex BETWEEN ", A1$shiftindex, " and ", A2$shiftindex,  sep = "")

query4 = paste("
SELECT *
FROM [PowerView].[dbo].[hist_loads] as hl
where hl.shiftindex BETWEEN ", A1$shiftindex, " and ", A2$shiftindex,  sep = "")

query5 = paste("
SELECT *
FROM [PowerView].[dbo].[hist_exproot] as he
where he.shiftindex BETWEEN ", A1$shiftindex, " and ", A2$shiftindex,  sep = "")

query6 = paste("
SELECT *
FROM [PowerView].[dbo].[hist_pvs3id] as pvs3id
where pvs3id.shiftindex BETWEEN ", A1$shiftindex, " and ", A2$shiftindex,  sep = "")

query7 = paste("
SELECT *
FROM [PowerView].[dbo].[hist_gradelist] as gradelist
where gradelist.shiftindex BETWEEN ", A1$shiftindex, " and ", A2$shiftindex,  sep = "")
            
A3 = as_tibble(dbGetQuery(con1, query3)) #hist_dumps
A4 = as_tibble(dbGetQuery(con1, query4)) #hist_loads
A5 = as_tibble(dbGetQuery(con1, query5)) #hist_exproot
A6 = as_tibble(dbGetQuery(con1, query6)) #hist_pvs3id
A7 = as_tibble(dbGetQuery(con1, query7)) #hist_gradelist

A4_2 = A4 %>% select(c("shiftindex", "timeload", "dumprec"))
A5_2 = A5 %>% select(c("name", "shiftindex"))
names(A5_2)[names(A5_2) == "name"] = "Turno"

S = left_join(A3, A5_2, by = "shiftindex")
S$Hora = round(S$timedump/3600, 0)

S2 = left_join(A4_2, S, by = c("shiftindex" = "shiftindex", "dumprec" = "ddbkey"))

Sf = S2 %>% select(c("Turno", "Hora", "timeload", 
                     "dumptons", "timedump", "excav",
                     "truck", "grade", "loc", 
                     "gpsxtkd", "gpsytkd", "gpsztkd"))

names(Sf) = c("Turno", "Hora", "TimeLoad", 
              "LoadTons", "TimeDump", "Excavadora", 
              "Camion", "Ley Op", "DumpLoc", 
              "DumpPointX", "DumpPointY", "DumpPointZ")

SS = list()
SS[["Sf"]] = Sf
SS[["hist_exproot"]] = A5 
SS[["hist_pvs3id"]]  = A6
SS[["hist_dumps"]]   = A3
SS[["hist_loads"]]   = A4

return(SS)
}