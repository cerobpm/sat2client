BEGIN;
CREATE OR REPLACE FUNCTION heatmap_day(_date date, _dt interval, _tabla int, _varid int, _use text default null)
 RETURNS TABLE (seriescontrol json) 
 AS $$
 DECLARE
 _startdate timestamp := _date::timestamp;
 _enddate timestamp := _date+'23:59:59'::interval;
 BEGIN
RETURN QUERY WITH ts as (
    SELECT generate_series(_startdate,_enddate,_dt) t
    ),
    tseries as (
    SELECT t,
           row_number() OVER (order by t) x
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
     subobs as (
		SELECT historicos."idEquipo",
		       historicos."idSensor",
		       historicos.fecha,
		       historicos.valor,
		       allstations.descripcion,
		       allstations."NroSerie"
		FROM historicos,
			 allstations
		WHERE allstations."idEquipo" = historicos."idEquipo"
		AND allstations."idSensor" = historicos."idSensor"
		AND historicos.fecha>=_startdate
		AND historicos.fecha<=_enddate
	),
    countreg as (
    SELECT subobs."idEquipo",
           tseries.t date,
           count(subobs.fecha) count 
    FROM subobs,
         tseries
    WHERE subobs.fecha >= tseries.t
    AND   subobs.fecha < tseries.t+_dt
    GROUP BY subobs."idEquipo",
             tseries.t 
    ORDER BY subobs."idEquipo",
             tseries.t
    ),
        heatmap as (
    SELECT tseries.x, 
           allstations.y, 
           coalesce(countreg.count, 0) count
    FROM tseries
    JOIN allstations ON (allstations."idEquipo" is not null)
    LEFT JOIN countreg ON (tseries.t=countreg.date AND allstations."idEquipo"=countreg."idEquipo") 
    ),
    datearr as (
		SELECT array_agg(tseries.t) dates
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
    SELECT json_build_object('dates',dates,'equipos',equipos,'heatmap',heatmap) as heatmap
    FROM datearr,
         starr,
         heatmaparr;
END;
$$
LANGUAGE plpgsql;
COMMIT;
