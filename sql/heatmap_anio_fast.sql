BEGIN;
CREATE OR REPLACE FUNCTION heatmap_anio_fast(_year int, _tabla int, _varid int, _use text default false)
 RETURNS TABLE (seriescontrol json) 
 AS $$
 DECLARE
 _startdate timestamp := make_timestamp(_year,1,1,0,0,0);
 _enddate timestamp := make_timestamp(_year,12,31,23,59,59);
BEGIN
RETURN QUERY WITH ts as (
    SELECT generate_series(_startdate::date,_enddate::date,'1 month'::interval) t
    ),
    tseries as (
    SELECT t::date - extract(days from t)::int + 1 fecha,
           row_number() OVER (order by t) x,
           extract(month from t) mes,
           extract(year from t) anio
    FROM ts
    ),
    allstations as (
    SELECT equipos."idEquipo", 
           equipos.descripcion,
           equipos."NroSerie",
           "sensoresPorEquipo"."idSensor",
           row_number() OVER (ORDER BY CASE WHEN (_use = 'desc') THEN descripcion WHEN (_use = 'serie') THEN LPAD(equipos."NroSerie"::text,5,'0') ELSE LPAD(equipos."idEquipo"::text,5,'0') END) y
    FROM equipos,
         "sensoresPorEquipo"
    WHERE equipos."idGrupo"=_tabla
    AND equipos."idEquipo" = "sensoresPorEquipo"."idEquipo"
    AND "sensoresPorEquipo"."idSensor" = _varid
    ORDER BY CASE WHEN (_use = 'desc')
                  THEN equipos.descripcion
                  WHEN _use = 'series' 
                  THEN LPAD(equipos."NroSerie"::text,5,'0')
                  ELSE LPAD(equipos."idEquipo"::text,5,'0')
             END
    ),
    heatmap as (
    SELECT count_by_month.fecha,
		   tseries.x,
           allstations.y, 
           coalesce(count_by_month.valor, 0) count
    FROM count_by_month,
         allstations,
         tseries
    WHERE allstations."idEquipo" = count_by_month."idEquipo"
    AND allstations."idSensor" = count_by_month."idSensor"
    AND count_by_month.fecha = tseries.fecha
    ),
    datearr as (
		SELECT array_agg(tseries.fecha::date) dates
		FROM tseries),
	starr as (
		SELECT CASE WHEN _use = 'desc'
		            THEN array_agg(substring(allstations."idEquipo"::text,0,5) || ' - ' || substring(allstations.descripcion,0,20)) 
		            WHEN _use = 'NroSerie'
		            THEN array_agg(coalesce(LPAD(allstations."NroSerie"::text,5,'0'),'00000')) 
		            ELSE array_agg(LPAD(allstations."idEquipo"::text,5,'0'))
		       END equipos
		FROM allstations
	), heatmaparr as (
       SELECT array_agg(ARRAY[heatmap.x::int-1, heatmap.y::int-1, heatmap.count::int]) heatmap
       FROM heatmap)
    SELECT json_build_object('dates',dates,'equipos',equipos,'heatmap',heatmap)
    FROM datearr,
         starr,
         heatmaparr;
END;
$$
LANGUAGE plpgsql;
COMMIT;
