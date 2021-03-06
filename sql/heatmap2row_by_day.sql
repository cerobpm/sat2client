BEGIN;
CREATE OR REPLACE FUNCTION heatmap2row_by_day(_startdate timestamp, _enddate timestamp, _idEquipo int, _idSensor int) RETURNS BIGINT AS $$
WITH ts as (
    SELECT generate_series(_startdate::date,_enddate::date,'1 day'::interval) t
    ),
    tseries as (
    SELECT t,
           row_number() OVER (order by t) x,
           extract(month from t) mes,
           extract(year from t) anio,
           extract(day from t) dia
    FROM ts
    ),
     subobs as (
		SELECT historicos."idEquipo",
			   historicos."idSensor",
			   historicos."fecha",
			   historicos."valor",
			   extract(day from historicos.fecha) dia,
			   extract(month from historicos.fecha) mes,
			   extract(year from historicos.fecha) anio
		FROM historicos
		WHERE historicos."idEquipo"=_idEquipo
		AND historicos."idSensor"=_idSensor
		AND historicos.fecha>=_startdate::date
		AND historicos.fecha<_enddate::date + 1
	),
    countreg as (
    SELECT tseries.t date,
           coalesce(count(subobs.fecha),0) count 
    FROM tseries
    LEFT JOIN subobs ON (subobs.dia = tseries.dia AND subobs.mes=tseries.mes AND subobs.anio=tseries.anio)
    GROUP BY tseries.t 
    ORDER BY tseries.t
    )
    , inserted as (
    INSERT INTO count_by_day ("idEquipo", "idSensor", fecha, valor) 
    SELECT  _idEquipo, _idSensor, countreg.date, countreg.count 
    FROM countreg
    ON CONFLICT("idEquipo", "idSensor", fecha) DO UPDATE SET valor=excluded.valor
    RETURNING "idEquipo", "idSensor", fecha, valor
    ) SELECT count(valor) from inserted;
$$
LANGUAGE SQL;
COMMIT;
