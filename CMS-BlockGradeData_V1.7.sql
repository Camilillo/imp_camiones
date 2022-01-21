-- drop tmp tables if exists  #shiftini,#shiftend,#hexproot,#hdump,#hload, #Q1, #tmppvsid, #transitload
if object_id('tempdb.dbo.#shiftini','U') is not null drop table #shiftini;
if object_id('tempdb.dbo.#shiftend','U') is not null drop table #shiftend;
if object_id('tempdb.dbo.#hexproot','U') is not null drop table #hexproot;
if object_id('tempdb.dbo.#hdump','U') is not null drop table #hdump;
if object_id('tempdb.dbo.#hload','U') is not null drop table #hload;
if object_id('tempdb.dbo.#Q1','U') is not null drop table #Q1;
if object_id('tempdb.dbo.#tmppvsid','U') is not null drop table #tmppvsid;
if object_id('tempdb.dbo.#gradelist','U') is not null drop table #gradelist;
if object_id('tempdb.dbo.#transitload','U') is not null drop table #transitload;

-- Declare and set variables

DECLARE @h_ini NVARCHAR(19)--DATETIME;
DECLARE @h_fin NVARCHAR(19)--DATETIME;
DECLARE @n_camion NVARCHAR(6);
DECLARE @n_pala NVARCHAR(6);

SET @h_ini = '2021-08-02 20:00:00'; -- Hora Inicio (yyyy-mm-dd hh:mm:ss)
SET @h_fin = '2021-08-03 08:00:00';

--- BEGIN TEMP TABLES ---

select shiftindex 
into #shiftini from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_exproot] as he WITH (NOLOCK)
where date <= DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, @h_ini)) and
date > DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, @h_ini)) - he.len

select shiftindex 
into #shiftend from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_exproot] as he WITH (NOLOCK)
where date <= DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, @h_fin)) - 1 and
date > DATEDIFF(SECOND,{d '1970-01-01'},Convert(DATETIME, @h_fin)) - 1 - he.len

select * into #hdump from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_dumps] as hd
where hd.shiftindex BETWEEN (select shiftindex from #shiftini) and (select shiftindex from #shiftend)

select * into #hload from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_loads] as hl
where hl.shiftindex BETWEEN (select shiftindex from #shiftini) and (select shiftindex from #shiftend)

select * into #hexproot from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_exproot] as he
where he.shiftindex BETWEEN (select shiftindex from #shiftini) and (select shiftindex from #shiftend)

select * into #tmppvsid from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_pvs3id] as pvs3id
where pvs3id.shiftindex BETWEEN (select shiftindex from #shiftini) and (select shiftindex from #shiftend)

select * into #gradelist from [CJCSPC-VMPVIEW].[Powerview].[dbo].[hist_gradelist] as gradelist
where gradelist.shiftindex BETWEEN (select shiftindex from #shiftini) and (select shiftindex from #shiftend)

SELECT [load.id] = NULL
,S.name [Turno]
,ROUND(D.timedump/3600.0,0,1) [Hora]
,L.timeload [TimeLoad]
,D.dumptons [LoadTons]
,D.timedump [TimeDump]
,D.excav [Excavadora]
,D.truck [Camion]
,D.grade COLLATE SQL_Latin1_General_CP1_CI_AS [Ley Op]
,D.loc as DumpLoc
,D.gpsxtkd as DumpPointX
,D.gpsytkd as DumpPointY
,D.gpsztkd as DumpPointZ into #transitload from #hdump as D

JOIN #hexproot as S WITH (NOLOCK) ON D.shiftindex = S.shiftindex
LEFT JOIN #hload as L WITH (NOLOCK) ON S.shiftindex = L.shiftindex AND L.dumprec = D.ddbkey 
WHERE
L.dumprec IS NULL

SELECT pReco.ID PRecID
 ,pPers.FirstName FirstN
 ,pPers.[Login] PersonL
 ,pCycl.[ID] CycleID
 ,lOper.ID LoadID
 ,eUnit.ShortName EUnit
 ,uType.Name UType
 ,tUnit.ShortName TUnit
 ,tUnit.Capacity TCapacity
 ,gps.Name GpsGrade
 ,op.Name OperGrade
 ,gpsmat.ShortName GpsMaterial
 --,opmat.ShortName OperMaterial
 ,hLoad.DispatchLoadId DispLoad
 ,hLoad.BucketCount BucketCount
 ,SUBSTRING(hLoad.DispatchLoadId, 13, 6) as dspLoadID
 ,SUBSTRING(hLoad.DispatchLoadId, 7, 5) as dspShiftID
 ,DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.StartTime) AS LoadStart
 ,DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.EndTime) AS LoadEnd
 -- ,CONVERT(datetime, SWITCHOFFSET(CONVERT(datetimeoffset,pReco.StartTime),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) LoadStart
INTO #Q1
FROM [ProductionTrackingHistorical].[ProductionCycleRecord] pCycl
JOIN [ProductionTrackingHistorical].[LoadOperationRecord] lOper ON lOper.ProductionCycleRecordID = pCycl.ID
JOIN [ProductionTrackingHistorical].[ProductionRecord] pReco ON pReco.ID = lOper.ID
JOIN [EquipmentConfigurationOperational].[EquipmentUnit] eUnit ON pReco.EquipmentUnitID = eUnit.ID
JOIN [EquipmentConfigurationOperational].[EquipmentUnit] tUnit ON lOper.PairedEquipmentUnitID1 = tUnit.ID
JOIN [EquipmentConfigurationOperational].[EquipmentType] uType ON eUnit.EquipmentTypeID = uType.ID
JOIN [ProductionTrackingHistorical].[HpLoadOperationRecord] hLoad ON lOper.ID = hLoad.LoadOperationID
LEFT JOIN [TopographyAndGeologyOperational].[MaterialPolygon] poly ON hLoad.GpsPolygonID = poly.ID
LEFT JOIN [MaterialManagementOperational].[MaterialGrade] gps ON poly.MaterialGradeID = gps.ID
LEFT JOIN [MaterialManagementOperational].[MaterialType] gpsmat ON gps.MaterialTypeID = gpsmat.ID
LEFT JOIN [MaterialManagementOperational].[MaterialGrade] op ON OperatorMaterialGradeID = op.ID
LEFT JOIN [MaterialManagementOperational].[MaterialType] opmat ON op.MaterialTypeID = opmat.ID
LEFT JOIN [PersonnelManagementOperational].[Person] pPers ON pReco.PersonID = pPers.ID
WHERE DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), pReco.StartTime) BETWEEN @h_ini and @h_fin;
--- End temp Tables ---

WITH Q2 AS
(
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
 ,hDigO.BlockModelName DigBlock

--## Info Pos. Bloque
 ,hDigO.BlockCenterX BlockCenterX
 ,hDigO.BlockCenterY BlockCenterY
 ,hDigO.BlockCenterZ BlockCenterZ
 ,hDump.PositionX PositionX
 ,hDump.PositionY PositionY
 ,hDump.PositionZ PositionZ
 ,hDump.SwingAngle [Angle]
 ,hDigO.BlockID BlockID
 ,first_id = ISNULL((Select top 1 bd.ID from TopographyAndGeologyOperational.BlockData as bd WITH (NOLOCK) where bd.BlockID = hDigO.BlockID ),NULL)
 ,GradeRecordID = ISNULL(IIF(hDigO.BlockMaterialRecordID IS NULL, hDigO.GpsMaterialRecordID, hDigO.BlockMaterialRecordID), NULL)
 --,GradeRecordID = IIF(hDigO.BlockMaterialRecordID IS NULL, hDigO.GpsMaterialRecordID, hDigO.BlockMaterialRecordID) -- Opcion B
 ,hDigO.OperatorMaterialGradeID as OpMaterialGrade
 --,hDigO.OperatorMaterialRecordID as opid -- Debug
 --,hDigO.GpsMaterialRecordID as gpsid     -- Debug
 --,hDigO.BlockMaterialRecordID as bloid   -- Debug
 ,dOper.ID digid
 ,blk.BlockName BlockName


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
)


SELECT Q1.PRecID [load.id]
 ,S.name [Turno]
 ,ROUND(L.timeload/3600.0,0,1) [Hora]
 ,L.timeload [TimeLoad]
 ,D.timedump [TimeDump]
 ,D.excav [Excavadora]
 ,Q1.UType [Tipo]
 ,Q1.TUnit [Camion]
 ,Q1.TCapacity [Capacidad]
 ,L.loadtons [LoadTons]
 ,cast(Q1.TCapacity/IIF(Q1.BucketCount = 0,1,Q1.BucketCount) as decimal(10,2)) [BucketLoad]
 ,cast(L.loadtons/IIF(Q1.BucketCount = 0,1,Q1.BucketCount) as decimal(10,2)) [BucketLoadTons]
-- ,Q2.DigPayload DigPayload
-- ,Q2.DumpPayload DumpPayload
 ,Q2.Bucket [Baldada]
 ,Q2.DigPointX [DigPointX]
 ,Q2.DigPointY [DigPointY]
 ,Q2.DigPointZ [DigPointZ]
 ,Q2.DigGpsGrade [Ley GPS]
 ,Q2.DigOperGrade [Ley Op]
 ,D.grade [Ley Dispatch]
 ,Q2.DigGpsMat [Material GPS]
 ,Q2.DigOpMat [Material Op]
 ,Q2.DigBlock [Modelo de Bloque]
 ,Q2.BlockID
 ,Q2.BlockName [Bloque]


 --## Otra Info
-- ,Q2.first_id [First ID]
-- ,Q1.LoadStart [load.start.time]
-- ,Q1.LoadEnd [load.end.time]
-- ,Q1.GpsGrade [Ley GPS]
-- ,Q1.OperGrade [Ley Op]
 --,Q2.DigOperID [bucket.id]
 --,Q2.PositionX [bucket.center.x]
 --,Q2.PositionY [bucket.center.y]
 --,Q2.PositionZ [bucket.center.z]
-- ,Q2.Angle [bucket.angle]
 --,Q1.PersonL [oper]
 --,Q1.GpsMaterial [Material GPS]
-- ,Q2.BlockCenterX [bucket.block.x]
-- ,Q2.BlockCenterY [bucket.block.y]
-- ,Q2.BlockCenterZ [bucket.block.z]
-- ,Q2.BlockID [bucket.block.id]



--## Materiales
 ,CuT      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 1 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 1 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade00 from  #gradelist where #gradelist.gradeid = D.grade))
 ,CuS      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 2 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 2 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade01 from  #gradelist where #gradelist.gradeid = D.grade))
 ,CO3      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 3 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 3 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade02 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Cl       = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 4 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 4 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade03 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Den      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 5 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 5 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade04 from  #gradelist where #gradelist.gradeid = D.grade))
 ,[Min]    = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 6 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 6 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade05 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Lit      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 7 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 7 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade06 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Clay     = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 8 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 8 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade07 from  #gradelist where #gradelist.gradeid = D.grade))
 ,AcF      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 9 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 9 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade08 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Cal      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 10 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 10 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade09 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Clay_B   = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 11 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 11 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade10 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Mo       = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 12 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 12 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade11 from  #gradelist where #gradelist.gradeid = D.grade))
 ,[As]     = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 13 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 13 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade12 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Ag       = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 14 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 14 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade13 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Au       = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 15 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 15 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade14 from  #gradelist where #gradelist.gradeid = D.grade))
 ,csrCC    = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 16 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 16 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade15 from  #gradelist where #gradelist.gradeid = D.grade))
 ,csrCV    = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 17 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 17 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade16 from  #gradelist where #gradelist.gradeid = D.grade))
 ,csrCPY   = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 18 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 18 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade17 from  #gradelist where #gradelist.gradeid = D.grade))
 ,UGG      = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 19 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 19 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade18 from  #gradelist where #gradelist.gradeid = D.grade))
 ,Sericita = ISNULL(ISNULL((SELECT top 1 Grade FROM MaterialManagementHistorical.ElementGrade WITH (NOLOCK) WHERE ElementID = 20 AND GradeRecordID = [Q2].[GradeRecordID]), (SELECT top 1 Grade FROM MaterialManagementOperational.ElementGrade WITH (NOLOCK) WHERE ElementID = 20 AND MaterialGradeID = [Q2].[OpMaterialGrade])), (SELECT top 1 grade19 from  #gradelist where #gradelist.gradeid = D.grade))

--## Otras Variables
 ,pol_index   = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+1) = ID),0)
 ,fase        = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+2) = ID),0)
 ,banco       = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+3) = ID),0)
 ,cufe        = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+4) = ID),0)
 ,sb          = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+5) = ID),0)
 ,ci          = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+6) = ID),0)
 ,agsag_tph   = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+7) = ID),0)
 ,bm_tph      = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+8) = ID),0)	
 ,circuit_tph = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+9) = ID),0)
 ,agsag_kwh_t = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+10) = ID),0)
 ,bm_kwt_t    = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+11) = ID),0)
 ,t80         = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+12) = ID),0)
 ,p80         = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+13) = ID),0)
 ,pccl        = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+14) = ID),0)
 ,rec_cu      = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+15) = ID),0)
 ,rec_mo      = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+16) = ID),0)
 ,rec_ag      = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+17) = ID),0)
 ,rec_au      = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+18) = ID),0)
 ,conc_ag     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+19) = ID),0)
 ,conc_au     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+20) = ID),0)
 ,conc_cu     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+21) = ID),0)
 ,conc_mo     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+22) = ID),0)
 ,zn          = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+23) = ID),0)
 ,fsag        = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+24) = ID),0)
 ,f50         = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+25) = ID),0)
 ,f80         = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+26) = ID),0)
 ,conc_sb     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+27) = ID),0)
 ,conc_as     = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+28) = ID),0)
 ,fe          = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+29) = ID),0)
 ,s2          = ISNULL((SELECT top 1 Value FROM TopographyAndGeologyOperational.BlockNumberData WHERE (Q2.first_id+30) = ID),0)

 ,Q1.DispLoad [Dispatch.Load.ID]

--## Powerview
 ,D.loc as DumpLoc
 ,D.gpsxtkd as DumpPointX
 ,D.gpsytkd as DumpPointY
 ,D.gpsztkd as DumpPointZ
 , 0 as [EsPowerView]

FROM #Q1 as Q1 
 LEFT JOIN Q2 ON Q1.CycleID = Q2.CycleID
 JOIN #hexproot as S WITH (NOLOCK) ON Q1.dspShiftID = S.shiftindex
 JOIN #tmppvsid as PVS3ID WITH (NOLOCK) ON Q1.dspShiftID = PVS3ID.shiftindex and 
                                                                                (PVS3ID.pvs3id = Q1.DispLoad COLLATE SQL_Latin1_General_CP1_CI_AS 
																				or CONCAT(PVS3ID.excav COLLATE SQL_Latin1_General_CP1_CI_AS,'_',PVS3ID.shiftindex ,'_',PVS3ID.timefull) = Q1.DispLoad)
 JOIN #hload as L WITH (NOLOCK) ON Q1.dspShiftID = L.shiftindex AND (L.shiftlink = PVS3ID.shiftlink)-- AND L.excav = @n_pala
 JOIN #hdump as D WITH (NOLOCK) ON Q1.dspShiftID = D.shiftindex AND L.dumprec = D.ddbkey--  AND D.excav = @n_pala
 WHERE Q1.LoadStart BETWEEN @h_ini AND @h_fin
 
 --- Union Descargas en transito

Union 

SELECT 
TL.[load.id] 
,TL.[Turno]
,TL.[Hora]
,TL.[TimeLoad]
,TL.[TimeDump]
,TL.[Excavadora]
,NULL [Tipo]
,tUnit.ShortName [Camion]
,tUnit.Capacity [Capacidad]
,TL.[LoadTons]
,tUnit.Capacity  [BucketLoad]
,TL.[LoadTons] [BucketLoadTons]
-- ,Q2.DigPayload DigPayload (Nulo si se activa)
-- ,Q2.DumpPayload DumpPayload (Nulo si se activa)
,1 [Baldada]
,NULL[DigPointX]
,NULL [DigPointY]
,NULL [DigPointZ]
,NULL [Ley GPS]
,TL.[Ley Op]
,TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS  [Ley Dispatch]
,NULL [Material GPS] 
,NULL [Material Op]
,NULL [Modelo de Bloque]
,NULL [BlockID]
,NULL [Bloque]


--## Otra Info (Dejar en Nulo si se activan)
-- ,Q2.first_id [First ID]
-- ,Q1.LoadStart [load.start.time]
-- ,Q1.LoadEnd [load.end.time]
-- ,Q1.GpsGrade [Ley GPS]
-- ,Q1.OperGrade [Ley Op]
--,Q2.DigOperID [bucket.id]
--,Q2.PositionX [bucket.center.x]
--,Q2.PositionY [bucket.center.y]
--,Q2.PositionZ [bucket.center.z]
-- ,Q2.Angle [bucket.angle]
--,Q1.PersonL [oper]
--,Q1.GpsMaterial [Material GPS]
-- ,Q2.BlockCenterX [bucket.block.x]
-- ,Q2.BlockCenterY [bucket.block.y]
-- ,Q2.BlockCenterZ [bucket.block.z]
-- ,Q2.BlockID [bucket.block.id]



--## Materiales
,CuT      = (SELECT top 1 grade00 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,CuS      = (SELECT top 1 grade01 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,CO3      = (SELECT top 1 grade02 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Cl       = (SELECT top 1 grade03 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Den      = (SELECT top 1 grade04 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,[Min]    = (SELECT top 1 grade05 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Lit      = (SELECT top 1 grade06 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Clay     = (SELECT top 1 grade07 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,AcF      = (SELECT top 1 grade08 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Cal      = (SELECT top 1 grade09 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Clay_B   = (SELECT top 1 grade10 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Mo       = (SELECT top 1 grade11 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,[As]     = (SELECT top 1 grade12 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Ag       = (SELECT top 1 grade13 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Au       = (SELECT top 1 grade14 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,csrCC    = (SELECT top 1 grade15 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,csrCV    = (SELECT top 1 grade16 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,csrCPY   = (SELECT top 1 grade17 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,UGG      = (SELECT top 1 grade18 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)
,Sericita = (SELECT top 1 grade19 from  #gradelist where #gradelist.gradeid = TL.[Ley Op] COLLATE SQL_Latin1_General_CP1_CI_AS)

--## Otras Variables
,pol_index   = NULL
,fase        = NULL
,banco       = NULL
,cufe        = NULL
,sb          = NULL
,ci          = NULL
,agsag_tph   = NULL
,bm_tph      = NULL	
,circuit_tph = NULL
,agsag_kwh_t = NULL
,bm_kwt_t    = NULL
,t80         = NULL
,p80         = NULL
,pccl        = NULL
,rec_cu      = NULL
,rec_mo      = NULL
,rec_ag      = NULL
,rec_au      = NULL
,conc_ag     = NULL
,conc_au     = NULL
,conc_cu     = NULL
,conc_mo     = NULL
,zn          = NULL
,fsag        = NULL
,f50         = NULL
,f80         = NULL
,conc_sb     = NULL
,conc_as     = NULL
,fe          = NULL
,s2          = NULL

,NULL [Dispatch.Load.ID]

--## Powerview
,TL.DumpLoc
,TL.DumpPointX
,TL.DumpPointY
,TL.DumpPointZ
, 1 as [EsPowerView]

from #transitload as TL
JOIN [EquipmentConfigurationOperational].[EquipmentUnit] tUnit on tUnit.ShortName = TL.Camion COLLATE SQL_Latin1_General_CP1_CI_AS


 
order by Hora,'load.id'

drop table  #shiftini,#shiftend,#hexproot,#hdump,#hload, #Q1, #tmppvsid, #transitload, #gradelist
