--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10 (Ubuntu 10.10-1.pgdg18.04+1)
-- Dumped by pg_dump version 10.10 (Ubuntu 10.10-1.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
SET idle_in_transaction_session_timeout = 0;
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


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: equipos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipos (
    "idEquipo" integer NOT NULL,
    descripcion character varying NOT NULL,
    geom public.geometry NOT NULL,
    "NroSerie" integer,
    "fechaAlta" timestamp without time zone,
    CONSTRAINT enforce_dimension_geom CHECK ((public.st_dimension(geom) = 0)),
    CONSTRAINT enforce_ndim_geom CHECK ((public.st_ndims(geom) = 2)),
    CONSTRAINT enforce_srid_geom CHECK ((public.st_srid(geom) = 4326))
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
    AS integer
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
    AS integer
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
-- Name: equipos equipos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipos
    ADD CONSTRAINT equipos_pkey PRIMARY KEY ("idEquipo");


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
-- Name: TABLE equipos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.equipos TO sat2;


--
-- Name: TABLE historicos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.historicos TO sat2;


--
-- Name: TABLE sensores; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sensores TO sat2;


--
-- Name: TABLE "sensoresPorEquipo"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."sensoresPorEquipo" TO sat2;


--
-- PostgreSQL database dump complete
--

