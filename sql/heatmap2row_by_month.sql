BEGIN;
CREATE OR REPLACE FUNCTION heatmap2row_by_month(_startdate timestamp, _enddate timestamp, _idEquipo int, _idSensor int) RETURNS BIGINT AS $$
WITH ts as (
    SELECT generate_series(_startdate::date,_enddate::date,'1 month'::interval) t
    ),
    tseries as (
    SELECT t,
           row_number() OVER (order by t) x,
           extract(month from t) mes,
           extract(year from t) anio
    FROM ts
    ),
     subobs as (
		SELECT historicos."idEquipo",
			   historicos."idSensor",
			   historicos."fecha",
			   historicos."valor",
			   extract(month from historicos.fecha) mes,
			   extract(year from historicos.fecha) anio
		FROM historicos
		WHERE historicos."idEquipo"=_idEquipo
		AND historicos."idSensor"=_idSensor
		AND historicos.fecha>=_startdate - (extract(day from _startdate)::text || ' days')::interval + '1 day'::interval
		AND historicos.fecha<_enddate - (extract(day from _startdate)::text || ' days')::interval +  '1 month'::interval + '1 day'::interval
	),
    countreg as (
    SELECT tseries.t date,
           coalesce(count(subobs.fecha),0) count 
    FROM tseries
    LEFT JOIN subobs ON (subobs.mes=tseries.mes AND subobs.anio=tseries.anio)
    GROUP BY tseries.t 
    ORDER BY tseries.t
    )
    , inserted as (
    INSERT INTO count_by_month ("idEquipo", "idSensor", fecha, valor) 
    SELECT  _idEquipo, _idSensor, countreg.date, countreg.count 
    FROM countreg
    ON CONFLICT("idEquipo", "idSensor", fecha) DO UPDATE SET valor=excluded.valor
    RETURNING "idEquipo", "idSensor", fecha, valor
    ) SELECT count(valor) from inserted;
$$
LANGUAGE SQL;
COMMIT;
