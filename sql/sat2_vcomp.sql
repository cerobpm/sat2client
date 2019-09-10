CREATE USER sat2 WITH PASSWORD 'sat2';

--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10 (Ubuntu 10.10-1.pgdg18.04+1)
-- Dumped by pg_dump version 10.10 (Ubuntu 10.10-1.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
--SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: sat2; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE sat2 WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


\connect sat2

SET statement_timeout = 0;
SET lock_timeout = 0;
--SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: heatmap(date, date, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap(_startdate date, _enddate date, _tabla integer, _varid integer, _use text DEFAULT 'id'::text) RETURNS TABLE(seriescontrol json)
    LANGUAGE plpgsql
    AS $$
 DECLARE
 _enddate2 timestamp := _enddate+'23:59:59'::interval;
 BEGIN
RETURN QUERY WITH ts as (
    SELECT generate_series(_startdate::date,_enddate::date,'1 day'::interval) t
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
		AND historicos.fecha<=_enddate2
	),
    countreg as (
    SELECT subobs."idEquipo",
           subobs.fecha::date date,
           count(subobs.fecha) count 
    FROM subobs,
         tseries
    WHERE subobs.fecha::date=tseries.t
    GROUP BY subobs."idEquipo",
             subobs.fecha::date 
    ORDER BY subobs."idEquipo",
             subobs.fecha::date
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
		SELECT array_agg(tseries.t::date) dates
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
$$;


--
-- Name: heatmap2row_by_3h(timestamp without time zone, timestamp without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap2row_by_3h(_startdate timestamp without time zone, _enddate timestamp without time zone, _idequipo integer, _idsensor integer) RETURNS bigint
    LANGUAGE sql
    AS $$
WITH ts as (
    SELECT generate_series(_startdate::timestamp,_enddate::timestamp,'3 hours'::interval) t
    ),
    tseries as (
    SELECT t,
           row_number() OVER (order by t) x,
           extract(month from t) mes,
           extract(year from t) anio,
           extract(day from t) dia,
           (extract(hour from t) - extract(hour from t)::int % 3) AS hora
    FROM ts
    ),
     subobs as (
		SELECT historicos."idEquipo",
			   historicos."idSensor",
			   historicos."fecha",
			   historicos."valor",
			   (extract(hour from fecha) - extract(hour from fecha)::int % 3) AS hora,
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
    LEFT JOIN subobs ON (subobs.hora = tseries.hora AND subobs.dia = tseries.dia AND subobs.mes=tseries.mes AND subobs.anio=tseries.anio)
    GROUP BY tseries.t 
    ORDER BY tseries.t
    )
    , inserted as (
    INSERT INTO count_by_3h ("idEquipo", "idSensor", fecha, valor) 
    SELECT  _idEquipo, _idSensor, countreg.date, countreg.count 
    FROM countreg
    ON CONFLICT("idEquipo", "idSensor", fecha) DO UPDATE SET valor=excluded.valor
    RETURNING "idEquipo", "idSensor", fecha, valor
    ) SELECT count(valor) from inserted;
$$;


--
-- Name: heatmap2row_by_day(timestamp without time zone, timestamp without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap2row_by_day(_startdate timestamp without time zone, _enddate timestamp without time zone, _idequipo integer, _idsensor integer) RETURNS bigint
    LANGUAGE sql
    AS $$
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
$$;


--
-- Name: heatmap2row_by_month(timestamp without time zone, timestamp without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap2row_by_month(_startdate timestamp without time zone, _enddate timestamp without time zone, _idequipo integer, _idsensor integer) RETURNS bigint
    LANGUAGE sql
    AS $$
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
$$;


--
-- Name: heatmap_anio(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap_anio(_year integer, _tabla integer, _varid integer, _use text DEFAULT false) RETURNS TABLE(seriescontrol json)
    LANGUAGE plpgsql
    AS $$
 DECLARE
 _startdate timestamp := make_timestamp(_year,1,1,0,0,0);
 _enddate timestamp := make_timestamp(_year,12,31,23,59,59);
 BEGIN
RETURN QUERY WITH ts as (
    SELECT generate_series(_startdate::date,_enddate::date,'1 month'::interval) t
    ),
    tseries as (
    SELECT t,
           row_number() OVER (order by t) x,
           extract(month from t) mes
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
			   historicos."fecha",
			   historicos."valor",
			   extract(month from historicos.fecha) mes,
		       allstations.descripcion
		FROM historicos,
			 allstations,
			 "sensoresPorEquipo"
		WHERE historicos."idEquipo"=allstations."idEquipo"
		AND historicos."idSensor"=allstations."idSensor"
		AND historicos.fecha>=_startdate
		AND historicos.fecha<=_enddate
	),
    countreg as (
    SELECT subobs."idEquipo",
           tseries.t date,
           count(subobs.fecha) count 
    FROM subobs,
         tseries
    WHERE subobs.mes=tseries.mes
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
		SELECT array_agg(tseries.t::date) dates
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
$$;


--
-- Name: heatmap_anio_fast(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap_anio_fast(_year integer, _tabla integer, _varid integer, _use text DEFAULT false) RETURNS TABLE(seriescontrol json)
    LANGUAGE plpgsql
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
$$;


--
-- Name: heatmap_day(date, interval, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap_day(_date date, _dt interval, _tabla integer, _varid integer, _use text DEFAULT NULL::text) RETURNS TABLE(seriescontrol json)
    LANGUAGE plpgsql
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
$$;


--
-- Name: heatmap_mes_fast(timestamp without time zone, timestamp without time zone, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heatmap_mes_fast(_startdate timestamp without time zone, _enddate timestamp without time zone, _tabla integer, _varid integer, _use text DEFAULT false) RETURNS TABLE(seriescontrol json)
    LANGUAGE plpgsql
    AS $$
 DECLARE
 _enddate2 timestamp := _startdate::date + (extract (day from _startdate))::int + '1 month'::interval - '2 day'::interval  +'23:59:59'::interval;
 BEGIN
RETURN QUERY WITH ts as (
    SELECT generate_series(_startdate::date,_enddate2::date,'1 day'::interval) t
    ),
    tseries as (
    SELECT t::date fecha,
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
    heatmap as (
    SELECT count_by_day.fecha,
		   tseries.x,
           allstations.y, 
           coalesce(count_by_day.valor, 0) count
    FROM count_by_day,
         allstations,
         tseries
    WHERE allstations."idEquipo" = count_by_day."idEquipo"
    AND allstations."idSensor" = count_by_day."idSensor"
    AND count_by_day.fecha = tseries.fecha
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
    SELECT json_build_object('dates',dates,'equipos',equipos,'heatmap',heatmap) heatmap
    FROM datearr,
         starr,
         heatmaparr;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: count_by_3h; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.count_by_3h (
    "idEquipo" integer NOT NULL,
    "idSensor" integer NOT NULL,
    fecha timestamp without time zone NOT NULL,
    valor integer NOT NULL
);


--
-- Name: count_by_day; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.count_by_day (
    "idEquipo" integer NOT NULL,
    "idSensor" integer NOT NULL,
    fecha timestamp without time zone NOT NULL,
    valor integer NOT NULL
);


--
-- Name: count_by_month; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.count_by_month (
    "idEquipo" integer NOT NULL,
    "idSensor" integer NOT NULL,
    fecha timestamp without time zone NOT NULL,
    valor integer NOT NULL
);


--
-- Name: equipos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipos (
    "idEquipo" integer NOT NULL,
    descripcion character varying NOT NULL,
    geom public.geometry NOT NULL,
    "NroSerie" integer,
    "fechaAlta" timestamp without time zone,
    "idGrupo" integer DEFAULT 1 NOT NULL,
    CONSTRAINT enforce_dimension_geom CHECK ((public.st_dimension(geom) = 0)),
    CONSTRAINT enforce_ndim_geom CHECK ((public.st_ndims(geom) = 2)),
    CONSTRAINT enforce_srid_geom CHECK ((public.st_srid(geom) = 4326))
);


--
-- Name: grupos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grupos (
    "idGrupo" integer NOT NULL,
    descripcion character varying NOT NULL
);


--
-- Name: historicos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historicos (
    gid integer NOT NULL,
    "idEquipo" integer NOT NULL,
    "idSensor" integer NOT NULL,
    fecha timestamp without time zone NOT NULL,
    valor real NOT NULL
);


--
-- Name: historicos_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.historicos_gid_seq
    --AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: historicos_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.historicos_gid_seq OWNED BY public.historicos.gid;


--
-- Name: sensores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sensores (
    "idSensor" integer NOT NULL,
    nombre character varying NOT NULL,
    "Icono" integer
);


--
-- Name: sensoresPorEquipo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."sensoresPorEquipo" (
    gid integer NOT NULL,
    "idEquipo" integer NOT NULL,
    "idSensor" integer NOT NULL
);


--
-- Name: sensoresPorEquipo_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."sensoresPorEquipo_gid_seq"
  --  AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensoresPorEquipo_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."sensoresPorEquipo_gid_seq" OWNED BY public."sensoresPorEquipo".gid;


--
-- Name: historicos gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historicos ALTER COLUMN gid SET DEFAULT nextval('public.historicos_gid_seq'::regclass);


--
-- Name: sensoresPorEquipo gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."sensoresPorEquipo" ALTER COLUMN gid SET DEFAULT nextval('public."sensoresPorEquipo_gid_seq"'::regclass);


--
-- Name: count_by_3h count_by_3h_idEquipo_idSensor_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_3h
    ADD CONSTRAINT "count_by_3h_idEquipo_idSensor_fecha_key" UNIQUE ("idEquipo", "idSensor", fecha);


--
-- Name: count_by_day count_by_day_idEquipo_idSensor_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_day
    ADD CONSTRAINT "count_by_day_idEquipo_idSensor_fecha_key" UNIQUE ("idEquipo", "idSensor", fecha);


--
-- Name: count_by_month count_by_month_idEquipo_idSensor_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_month
    ADD CONSTRAINT "count_by_month_idEquipo_idSensor_fecha_key" UNIQUE ("idEquipo", "idSensor", fecha);


--
-- Name: equipos equipos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipos
    ADD CONSTRAINT equipos_pkey PRIMARY KEY ("idEquipo");


--
-- Name: grupos grupos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grupos
    ADD CONSTRAINT grupos_pkey PRIMARY KEY ("idGrupo");


--
-- Name: historicos historicos_idEquipo_idSensor_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historicos
    ADD CONSTRAINT "historicos_idEquipo_idSensor_fecha_key" UNIQUE ("idEquipo", "idSensor", fecha);


--
-- Name: historicos historicos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historicos
    ADD CONSTRAINT historicos_pkey PRIMARY KEY (gid);


--
-- Name: sensoresPorEquipo sensoresPorEquipo_idEquipo_idSensor_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."sensoresPorEquipo"
    ADD CONSTRAINT "sensoresPorEquipo_idEquipo_idSensor_key" UNIQUE ("idEquipo", "idSensor");


--
-- Name: sensoresPorEquipo sensoresPorEquipo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."sensoresPorEquipo"
    ADD CONSTRAINT "sensoresPorEquipo_pkey" PRIMARY KEY (gid);


--
-- Name: sensores sensores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sensores
    ADD CONSTRAINT sensores_pkey PRIMARY KEY ("idSensor");


--
-- Name: count_by_3h count_by_3h_idEquipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_3h
    ADD CONSTRAINT "count_by_3h_idEquipo_fkey" FOREIGN KEY ("idEquipo") REFERENCES public.equipos("idEquipo");


--
-- Name: count_by_3h count_by_3h_idSensor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_3h
    ADD CONSTRAINT "count_by_3h_idSensor_fkey" FOREIGN KEY ("idSensor") REFERENCES public.sensores("idSensor");


--
-- Name: count_by_day count_by_day_idEquipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_day
    ADD CONSTRAINT "count_by_day_idEquipo_fkey" FOREIGN KEY ("idEquipo") REFERENCES public.equipos("idEquipo");


--
-- Name: count_by_day count_by_day_idSensor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_day
    ADD CONSTRAINT "count_by_day_idSensor_fkey" FOREIGN KEY ("idSensor") REFERENCES public.sensores("idSensor");


--
-- Name: count_by_month count_by_month_idEquipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_month
    ADD CONSTRAINT "count_by_month_idEquipo_fkey" FOREIGN KEY ("idEquipo") REFERENCES public.equipos("idEquipo");


--
-- Name: count_by_month count_by_month_idSensor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.count_by_month
    ADD CONSTRAINT "count_by_month_idSensor_fkey" FOREIGN KEY ("idSensor") REFERENCES public.sensores("idSensor");


--
-- Name: historicos historicos_idEquipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historicos
    ADD CONSTRAINT "historicos_idEquipo_fkey" FOREIGN KEY ("idEquipo") REFERENCES public.equipos("idEquipo");


--
-- Name: historicos historicos_idSensor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historicos
    ADD CONSTRAINT "historicos_idSensor_fkey" FOREIGN KEY ("idSensor") REFERENCES public.sensores("idSensor");


--
-- Name: equipos idGrupo_foreign_key; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipos
    ADD CONSTRAINT "idGrupo_foreign_key" FOREIGN KEY ("idGrupo") REFERENCES public.grupos("idGrupo");


--
-- Name: sensoresPorEquipo sensoresPorEquipo_idEquipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."sensoresPorEquipo"
    ADD CONSTRAINT "sensoresPorEquipo_idEquipo_fkey" FOREIGN KEY ("idEquipo") REFERENCES public.equipos("idEquipo");


--
-- Name: sensoresPorEquipo sensoresPorEquipo_idSensor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."sensoresPorEquipo"
    ADD CONSTRAINT "sensoresPorEquipo_idSensor_fkey" FOREIGN KEY ("idSensor") REFERENCES public.sensores("idSensor");


--
-- Name: TABLE count_by_3h; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.count_by_3h TO sat2;


--
-- Name: TABLE count_by_day; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.count_by_day TO sat2;


--
-- Name: TABLE count_by_month; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.count_by_month TO sat2;


--
-- Name: TABLE equipos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.equipos TO sat2;


--
-- Name: TABLE grupos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,DELETE,UPDATE ON TABLE public.grupos TO sat2;


--
-- Name: TABLE historicos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.historicos TO sat2;


--
-- Name: SEQUENCE historicos_gid_seq; Type: ACL; Schema: public; Owner: -
--

GRANT USAGE ON SEQUENCE public.historicos_gid_seq TO sat2;


--
-- Name: TABLE sensores; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sensores TO sat2;


--
-- Name: TABLE "sensoresPorEquipo"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."sensoresPorEquipo" TO sat2;


--
-- Name: SEQUENCE "sensoresPorEquipo_gid_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT USAGE ON SEQUENCE public."sensoresPorEquipo_gid_seq" TO sat2;


--
-- PostgreSQL database dump complete
--


-- GRANT SELECT,UPDATE,DELETE,INSERT ON count_by_3h, count_by_day, count_by_month, equipos, geography_columns, geometry_columns , grupos, historicos, raster_columns , raster_overviews, sensores, sensoresPorEquipo TO sat2;

COPY public.grupos ("idGrupo", descripcion) FROM stdin;
1       Red Hidrometeorológica Nacional
2       Prueba
3       SiNaRaMe
\.



