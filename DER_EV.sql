SELECT  
/*+ parallel (4) */ 

JURISDICTION, 
DIV_ALIAS,

SUBSTATION_ID,
CIRCUT_ID,
FACILITY_ID,

SA_IDS,

SP_KW_CAPACITY,
NET_METER_START_DT,
METER_NBRS,

GEN_TYPE,
CASE WHEN RATE_DESCRS LIKE '%Electric Vehicle%' THEN 'EV' ELSE NULL END AS CONSUMP_TYPE,
RATE_DESCRS,

BSEG_END_DT,
BILL_YM, 
GROSS_KWH_USE,
NET_KWH_BILLED,
KWH_RECEIVED,
DEMAND_PEAK_HR_KW_BILLED,
DAYS_BILLED,
(ROUND((SP_KWH/NBR_HOURS), 4) * - 1) AS AVE_SP_KW_GENERATION,
(ROUND((DER_NET_KWH/NBR_HOURS), 4) * - 1) AS AVE_DER_KW_GENERATION,
ROUND((EV_NET_KWH/NBR_HOURS), 4) AS AVE_EV_KW_CONSUMPTION

FROM (

SELECT DISTINCT
TRIM(CI_SA.CIS_DIVISION) AS JURISDICTION,
DECODE(TRIM(CI_SA.CIS_DIVISION), 
'GMO', 'Missouri West', 'KCPLM', 'Missouri Metro', 'KCPLK', 'Kansas Metro', 
'WSTRS', 'Kansas Central South', 'WSTRC', 'Kansas Central') AS DIV_ALIAS,

ALFD.SUBSTATION_ID,
ALFD.FEEDER_ID AS CIRCUT_ID,
ALFD.TRANSFORMER_ID AS FACILITY_ID,

REGEXP_REPLACE(
RTRIM(XMLAGG(XMLELEMENT(E,TRIM(CI_SA.SA_ID), ',').EXTRACT('//text()') 
ORDER BY CI_SA.SA_ID).GETCLOBVAL(),','),
'(^|,)([^,]*)(,\2)+','\1\2') AS SA_IDS,

CI_SP_CHAR.ADHOC_CHAR_VAL AS SP_KW_CAPACITY,

MIN(CI_SP_CHAR_3.ADHOC_CHAR_VAL)  AS NET_METER_START_DT,

REGEXP_REPLACE(
RTRIM(XMLAGG(XMLELEMENT(E,TRIM(ALFD.METER_NBR), ',').EXTRACT('//text()') 
ORDER BY ALFD.METER_NBR).GETCLOBVAL(),','),
'(^|,)([^,]*)(,\2)+','\1\2') AS METER_NBRS,

CI_BSEG.END_DT AS BSEG_END_DT,
TO_CHAR(CI_BSEG.END_DT, 'yyyy-MM') AS BILL_YM,

CI_SP_CHAR_2.CHAR_VAL AS GEN_TYPE,

REGEXP_REPLACE(
RTRIM(XMLAGG(XMLELEMENT(E,TRIM(CI_RS_L.DESCR ), ',').EXTRACT('//text()') 
ORDER BY CI_RS_L.DESCR ).GETCLOBVAL(),','),
'(^|,)([^,]*)(,\2)+','\1\2') AS RATE_DESCRS,

CI_BSEG.END_DT-CI_BSEG.START_DT AS DAYS_BILLED,
(CI_BSEG.END_DT-CI_BSEG.START_DT) * 24 AS NBR_HOURS,

ROUND(SUM(CI_BSEG_SQ.INIT_SQ)/COUNT(CI_SP.SP_ID), 4) AS GROSS_KWH_USE,

ROUND(SUM(CI_BSEG_SQ.BILL_SQ)/COUNT(CI_SP.SP_ID), 4) AS NET_KWH_BILLED,

(ROUND(SUM(CI_BSEG_SQ.INIT_SQ)/COUNT(CI_SP.SP_ID), 4) - ROUND(SUM(CI_BSEG_SQ.BILL_SQ)/COUNT(CI_SP.SP_ID), 4)) * - 1 AS KWH_RECEIVED,

ROUND(SUM(CI_BSEG_SQ_2.BILL_SQ)/COUNT(CI_SP.SP_ID), 4) AS DEMAND_PEAK_HR_KW_BILLED,

CASE WHEN CI_SP_CHAR_2.CHAR_VAL IN ('PV','WIND','BIO') THEN (ROUND(SUM(CI_BSEG_SQ.INIT_SQ)/COUNT(CI_SP.SP_ID), 4) - ROUND(SUM(CI_BSEG_SQ.BILL_SQ)/COUNT(CI_SP.SP_ID), 4))
ELSE 0 END AS SP_KWH,

CASE WHEN 
REGEXP_REPLACE(
RTRIM(XMLAGG(XMLELEMENT(E,TRIM(CI_RS_L.DESCR ), ',').EXTRACT('//text()') 
ORDER BY CI_RS_L.DESCR ).GETCLOBVAL(),','),
'(^|,)([^,]*)(,\2)+','\1\2') LIKE '%Electric Vehicle%' 
THEN (ROUND(SUM(CI_BSEG_SQ.INIT_SQ)/COUNT(CI_SP.SP_ID), 4) - ROUND(SUM(CI_BSEG_SQ.BILL_SQ)/COUNT(CI_SP.SP_ID), 4))
ELSE 0 END AS EV_NET_KWH,

CASE WHEN 
REGEXP_REPLACE(
RTRIM(XMLAGG(XMLELEMENT(E,TRIM(CI_RS_L.DESCR ), ',').EXTRACT('//text()') 
ORDER BY CI_RS_L.DESCR ).GETCLOBVAL(),','),
'(^|,)([^,]*)(,\2)+','\1\2') LIKE '%Distributed Gen%' 
THEN (ROUND(SUM(CI_BSEG_SQ.INIT_SQ)/COUNT(CI_SP.SP_ID), 4) - ROUND(SUM(CI_BSEG_SQ.BILL_SQ)/COUNT(CI_SP.SP_ID), 4))
ELSE 0 END AS DER_NET_KWH

FROM 
CCB1REP.CI_SA CI_SA, 
CCB1REP.CI_SA_RS_HIST CI_SA_RS_HIST,

CCB1REP.CI_RS_L CI_RS_L,
CCB1REP.CI_SA_CHAR CI_SA_CHAR,
CCB1REP.CI_CHAR_TYPE_L CI_CHAR_TYPE_L,
CCB1REP.CI_CHAR_VAL_L CI_CHAR_VAL_L,

CCB1REP.CI_ACCT CI_ACCT, 
CCB1REP.CI_BSEG CI_BSEG, 
CCB1REP.CI_BSEG_CALC CI_BSEG_CALC,
CCB1REP.CI_BSEG_SQ CI_BSEG_SQ,
CCB1REP.CI_BSEG_SQ CI_BSEG_SQ_2,

CCB1REP.CI_ACCT_PER CI_ACCT_PER, 
CCB1REP.CI_PER_NAME CI_PER_NAME, 
CCB1REP.CI_SA_SP CI_SA_SP, 
CCB1REP.CI_SP CI_SP,

CUSTANALYTICS_DW.AMI_LP_FLAT_DIMENSION ALFD,

CCB1REP.CI_SP_CHAR CI_SP_CHAR,
CCB1REP.CI_SP_CHAR CI_SP_CHAR_2,
CCB1REP.CI_SP_CHAR CI_SP_CHAR_3

/* conditions */
WHERE 
CI_SA.SA_STATUS_FLG <> '70'
AND CI_SA.CUST_READ_FLG = 'N'
AND CI_BSEG.BSEG_STAT_FLG = 50

--AND CI_BSEG.END_DT BETWEEN :startDate AND :endDate
--AND CI_BSEG_CALC.END_DT BETWEEN :startDate AND :endDate
--AND (CI_BSEG.END_DT >= ADD_MONTHS(TRUNC(SYSDATE), - 1) AND CI_BSEG_CALC.END_DT >= ADD_MONTHS(TRUNC(SYSDATE), - 1))
--AND CI_BSEG.END_DT BETWEEN :startDate AND :endDate
--AND CI_BSEG.END_DT >= TRUNC(SYSDATE) - 1
AND CI_BSEG.END_DT >= ADD_MONTHS(TRUNC(SYSDATE), - 1)

AND CI_SP_CHAR_2.CHAR_VAL IN ('PV','WIND','BIO') 
AND CI_SA.SA_TYPE_CD LIKE 'NM%'

AND CI_BSEG_SQ.UOM_CD IN ('KWH')
AND CI_BSEG_SQ.TOU_CD = 'TOTAL'
AND CI_BSEG_SQ.SQI_CD IN ('DEL')
AND CI_BSEG_SQ.BILL_SQ > 0

AND CI_BSEG_SQ_2.SQI_CD (+) = 'BD'
AND CI_BSEG_SQ_2.UOM_CD (+) = 'KW'

AND CI_SP_CHAR.CHAR_TYPE_CD = 'NMCAP'
AND CI_SP_CHAR_2.CHAR_TYPE_CD (+) = 'CMGENTYP'
AND CI_SP_CHAR_3.CHAR_TYPE_CD  = 'NMSTART'

AND CI_ACCT_PER.MAIN_CUST_SW = 'Y'  
AND CI_PER_NAME.PRIM_NAME_SW = 'Y'
AND CI_ACCT_PER.FIN_RESP_SW = 'Y'

--AND CI_SA.SA_ID IN ('2660744025')
--AND CI_SA.ACCT_ID IN ('0758863348')
--AND CI_SA.ACCT_ID IN ('1116638568')
--AND CI_SA.ACCT_ID IN ('9269037442')
--AND CI_SA.SA_ID IN ('1249379490')
--AND CI_SA.SA_ID IN ('9235019508')
--AND CI_SA.SA_ID IN ('9684591053')

/* joins */
AND CI_SA.SA_ID = CI_SA_RS_HIST.SA_ID (+)
AND CI_SA.SA_ID = CI_SA_CHAR.SA_ID (+)
AND CI_SA_RS_HIST.RS_CD = CI_RS_L.RS_CD 
AND CI_SA_CHAR.CHAR_TYPE_CD = CI_CHAR_TYPE_L.CHAR_TYPE_CD 
AND CI_SA_CHAR.CHAR_VAL = CI_CHAR_VAL_L.CHAR_VAL 

AND CI_SA.ACCT_ID = CI_ACCT.ACCT_ID
AND CI_SA.SA_ID = CI_BSEG.SA_ID
AND CI_BSEG.BSEG_ID = CI_BSEG_CALC.BSEG_ID
AND CI_BSEG.BSEG_ID = CI_BSEG_SQ.BSEG_ID
AND CI_BSEG.BSEG_ID = CI_BSEG_SQ_2.BSEG_ID (+)

AND CI_SA.ACCT_ID = CI_ACCT_PER.ACCT_ID
AND CI_ACCT_PER.PER_ID = CI_PER_NAME.PER_ID 
AND CI_SA.SA_ID = CI_SA_SP.SA_ID 
AND CI_SA_SP.SP_ID = CI_SP.SP_ID 

AND CI_SA.ACCT_ID = ALFD.ACCOUNT_NBR

AND CI_SA_SP.SP_ID = CI_SP_CHAR.SP_ID (+)
AND CI_SA_SP.SP_ID = CI_SP_CHAR_2.SP_ID (+)
AND ALFD.SERVICE_POINT_NBR = CI_SP_CHAR_3.SP_ID

GROUP BY 
TRIM(CI_SA.CIS_DIVISION),
DECODE(TRIM(CI_SA.CIS_DIVISION), 
'GMO', 'Missouri West', 'KCPLM', 'Missouri Metro', 'KCPLK', 'Kansas Metro', 
'WSTRS', 'Kansas Central South', 'WSTRC', 'Kansas Central'),
ALFD.SUBSTATION_ID,
ALFD.FEEDER_ID,
ALFD.TRANSFORMER_ID,
CI_SP_CHAR.ADHOC_CHAR_VAL,
CI_BSEG.END_DT,
TO_CHAR(CI_BSEG.END_DT, 'yyyy-MM'),
CI_SP_CHAR_2.CHAR_VAL,
CI_BSEG.END_DT-CI_BSEG.START_DT,
(CI_BSEG.END_DT-CI_BSEG.START_DT) * 24
)
ORDER BY JURISDICTION, BILL_YM DESC
