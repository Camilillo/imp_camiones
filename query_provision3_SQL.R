BDP3 = function(inicio, final){

query1 = paste("
               SELECT pReco.ID PRecID
               ,pReco.PersonID PersonID
               ,pCycl.[ID] CycleID
               ,lOper.ID LoadID
               ,eUnit.EquipmentTypeID EquipmentTypeID
               ,eUnit.ShortName EUnit
               ,tUnit.ShortName TUnit
               ,tUnit.Capacity TCapacity
               ,hLoad.GpsPolygonID GpsPolygonID 
               ,hLoad.DispatchLoadId DispLoad
               ,hLoad.BucketCount BucketCount
               ,SUBSTRING(hLoad.DispatchLoadId, 13, 6) as dspLoadID
               ,SUBSTRING(hLoad.DispatchLoadId, 7, 5) as dspShiftID
               ,DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.StartTime) AS LoadStart
               ,DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.EndTime) AS LoadEnd
               FROM [ProductionTrackingHistorical].[ProductionCycleRecord] pCycl
               JOIN [ProductionTrackingHistorical].[LoadOperationRecord] lOper ON lOper.ProductionCycleRecordID = pCycl.ID
               JOIN [ProductionTrackingHistorical].[ProductionRecord] pReco ON pReco.ID = lOper.ID
               JOIN [EquipmentConfigurationOperational].[EquipmentUnit] eUnit ON pReco.EquipmentUnitID = eUnit.ID
               JOIN [EquipmentConfigurationOperational].[EquipmentUnit] tUnit ON lOper.PairedEquipmentUnitID1 = tUnit.ID
               JOIN [ProductionTrackingHistorical].[HpLoadOperationRecord] hLoad ON lOper.ID = hLoad.LoadOperationID
               WHERE DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.StartTime)
               BETWEEN '", inicial, "' and '", final, "';", sep = "")

### Equipos

query2 = paste("
               SELECT [ID]
               ,[StandardEquipmentTypeID]
               ,[Name]
               FROM [IntelliMineNextGenSPENCE].[EquipmentConfigurationOperational].[EquipmentType]")

### Topos

query3 = paste("
               SELECT [ID]
               ,[Name]
               ,[Elevation]
               ,[BoundaryPositionTopRightX]
               ,[BoundaryPositionTopRightY]
               ,[BoundaryPositionBottomLeftX]
               ,[BoundaryPositionBottomLeftY]
               ,[MaterialGradeID]
               ,[IsActive]
               ,[LastUpdate]
               ,[IsDeleted]
               FROM [IntelliMineNextGenSPENCE].[TopographyAndGeologyOperational].[MaterialPolygon]")

### Material grade

query4 = paste("SELECT [ID]
               ,[Name]
               ,[MaterialTypeID]
               ,[TopologicalObjectID]
               ,[IsDispatch]
               ,[LastUpdate]
               ,[RecordStatus]
               FROM [IntelliMineNextGenSPENCE].[MaterialManagementOperational].[MaterialGrade]")

### Material Type

query5 = paste("
               SELECT [ID]
               ,[DayStyleColor]
               ,[NightStyleColor]
               ,[LabelDayStyleColor]
               ,[LabelNightStyleColor]
               ,[MaterialGroupID]
               ,[ShortName]
               ,[FullName]
               ,[Density]
               ,[IsActive]
               ,[DispatchIdx]
               ,[LastUpdate]
               ,[RecordStatus]
               FROM [IntelliMineNextGenSPENCE].[MaterialManagementOperational].[MaterialType]")

### Query Personas

query6 = paste("
               SELECT [ID]
               ,[FirstName]
               ,[Login]
               FROM [IntelliMineNextGenSPENCE].[PersonnelManagementOperational].[Person]")

B1 = as_tibble(dbGetQuery(con2, query1)) ## Main Query 
B2 = as_tibble(dbGetQuery(con2, query2)) ## Equipos
B3 = as_tibble(dbGetQuery(con2, query3)) ## Topos / Poligonos
B4 = as_tibble(dbGetQuery(con2, query4)) ## Material Grade 
B5 = as_tibble(dbGetQuery(con2, query5)) ## Material Type
B6 = as_tibble(dbGetQuery(con2, query6)) ## Personas

C1 = left_join(B1, B6, by = c("PersonID"        = "ID"))
C2 = left_join(C1, B3, by = c("GpsPolygonID"    = "ID"))
C3 = left_join(C2, B4, by = c("MaterialGradeID" = "ID"))
C4 = left_join(C3, B5, by = c("MaterialTypeID"  = "ID"))
C5 = left_join(C4, B2, by = c("EquipmentTypeID" = "ID"))

names(C5)[names(C5) == "FirstName"] = "FirstN"
names(C5)[names(C5) == "Login"]     = "PersonL"
names(C5)[names(C5) == "Name"]      = "UType"
names(C5)[names(C5) == "Name.x"]    = "GpsGrade"
names(C5)[names(C5) == "ShortName"] = "GpsMaterial"

Q1 = C5 %>% 
  select(c("PRecID", "FirstN", "PersonL", "CycleID", 
           "LoadID", "EUnit", "UType", "TUnit", "TCapacity",
           "GpsGrade", "DispLoad", "BucketCount",
           "dspLoadID", "dspShiftID", 
           "LoadStart", "LoadEnd"))


queryB = 
paste("
SELECT pCycl.[ID] CycleID
,dOper.ID DigOperID
,duOpe.ID DumpOperID
,dOper.Payload DigPayload
,duOpe.Payload DumpPayload
,hDigO.BucketID Bucket
,hDigO.DigPointX DigPointX
,hDigO.DigPointY DigPointY
,hDigO.DigPointZ DigPointZ
,op.Name DigOperGrade
,gps.Name DigGpsGrade
,gpsmat.ShortName DigGpsMat
,opmat.ShortName DigOpMat
,hDump.PositionX PositionX
,hDump.PositionY PositionY
,hDump.PositionZ PositionZ
,hDump.SwingAngle [Angle]
,hDigO.OperatorMaterialGradeID as OpMaterialGrade
,dOper.ID digid

FROM [ProductionTrackingHistorical].[ProductionCycleRecord] pCycl
JOIN [ProductionTrackingHistorical].DigOperationRecord dOper ON dOper.ProductionCycleRecordID = pCycl.ID
JOIN [ProductionTrackingHistorical].[ProductionRecord] pDig ON dOper.ID = pDig.ID
JOIN [ProductionTrackingHistorical].HpDigOperationRecord hDigO ON hDigO.DigOperationID = dOper.ID
LEFT JOIN [TopographyAndGeologyOperational].[MaterialPolygon] poly ON hDigO.GpsPolygonID = poly.ID
LEFT JOIN [MaterialManagementOperational].[MaterialGrade] gps ON poly.MaterialGradeID = gps.ID
LEFT JOIN [MaterialManagementOperational].[MaterialType] gpsmat ON gps.MaterialTypeID = gpsmat.ID
LEFT JOIN [MaterialManagementOperational].[MaterialGrade] op ON hDigO.OperatorMaterialGradeID = op.ID
LEFT JOIN [MaterialManagementOperational].[MaterialType] opmat ON op.MaterialTypeID = opmat.ID
JOIN [ProductionTrackingHistorical].DumpOperationRecord duOpe ON duOpe.ProductionCycleRecordID = pCycl.ID
JOIN [ProductionTrackingHistorical].[ProductionRecord] pDump ON duOpe.ID = pDump.ID
JOIN [ProductionTrackingHistorical].HpDumpOperationRecord hDump ON duOpe.ID = hDump.DumpOperationID AND hDigO.BucketID = hDump.BucketID
LEFT JOIN [TopographyAndGeologyOperational].[Block] blk ON hDigO.BlockID = blk.ID
LEFT JOIN [MaterialManagementHistorical].[MaterialRecord] bMat ON blk.MaterialRecordID = bMat.ID
")

E1 = dbGetQuery(con2, queryB)
Q2 = as_tibble(E1)

Q = list()
Q[["Q1"]] = Q1
Q[["Q2"]] = Q2

return(Q)
}
