﻿-- CREA UN ARRAY AGGREGANDO GLI OGGETTI
DROP AGGREGATE IF EXISTS array_accum (anyelement);
CREATE AGGREGATE array_accum (anyelement)
(
    sfunc = array_append,
    stype = anyarray,
    initcond = '{}'
);


drop schema if exists grafo cascade;
create schema grafo;
-- TABELLA DEGLI ARCHI
CREATE TABLE grafo.archi AS
SELECT 
   fid AS id_arco, -- fid è la chiave anzichè gs_id
   NULL::integer as da_nodo,
   NULL::integer as a_nodo,
   NULL::character varying as da_tipo,
   NULL::character varying as a_tipo,  
   geom as the_geom
FROM
   --acqua.ratraccia_g;
   teleriscaldamento.fcl_h_ww_section
where id_tipo_verso in (1,3);

ALTER TABLE grafo.archi ADD CONSTRAINT archi_pkey PRIMARY KEY(id_arco); 


-- TABELLA DEI NODI RAGGRUPPATI PER GEOMETRIA E ASSEGNAZIONE DI ID UNIVOCO
CREATE SEQUENCE grafo.nodi_nodo_id_seq INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1;
CREATE TABLE grafo.nodi AS
SELECT 
	nextval('grafo.nodi_nodo_id_seq'::regclass)::integer as id_nodo,
	array_accum(arco_entrante) AS arco_entrante,
	array_accum(arco_uscente) AS arco_uscente,
	the_geom
FROM (
  SELECT 
    ST_StartPoint(geom) AS the_geom, 
    fid AS arco_uscente, -- fid anzichè gs_id
    NULL::integer AS arco_entrante
  --FROM acqua.ratraccia_g 
  FROM teleriscaldamento.fcl_h_ww_section
  where id_tipo_verso in (1,3)
  UNION ALL
  SELECT 
    ST_EndPoint(geom) AS the_geom, 
    NULL::integer AS arco_uscente,
    fid AS arco_entrante -- fid anzichè gs_id
  --FROM acqua.ratraccia_g 
  FROM teleriscaldamento.fcl_h_ww_section
  where id_tipo_verso in (1,3)
) AS foo
GROUP BY the_geom;
ALTER TABLE grafo.nodi ADD PRIMARY KEY (id_nodo);


--ESPANDO LA TABELLA DEI NODI PER POTER FARE LE QUERY DI JOIN E AGGIORNARE LA TABELLA DEGLI ARCHI
UPDATE grafo.archi a SET da_nodo = b.id_nodo FROM
	(WITH 
	nodi_serie AS (
		  SELECT 
		    id_nodo, 
		    arco_uscente, 
		    generate_series(1, array_upper(arco_uscente, 1)) AS uscente_upper,
		    arco_entrante, 
		    generate_series(1, array_upper(arco_entrante, 1)) AS entrante_upper
		  FROM grafo.nodi
	), 
	nodi_espansi AS(
		SELECT 
		  id_nodo, 
		  arco_uscente[uscente_upper], 
		  arco_entrante[entrante_upper]
		FROM nodi_serie
	)
	SELECT * FROM nodi_espansi) b
WHERE a.id_arco = b.arco_uscente;


UPDATE grafo.archi a SET a_nodo = b.id_nodo FROM
	(WITH 
	nodi_serie AS (
		  SELECT 
		    id_nodo, 
		    arco_uscente, 
		    generate_series(1, array_upper(arco_uscente, 1)) AS uscente_upper,
		    arco_entrante, 
		    generate_series(1, array_upper(arco_entrante, 1)) AS entrante_upper
		  FROM grafo.nodi
	), 
	nodi_espansi AS(
		SELECT 
		  id_nodo, 
		  arco_uscente[uscente_upper], 
		  arco_entrante[entrante_upper]
		FROM nodi_serie
	)
	SELECT * FROM nodi_espansi) b
WHERE a.id_arco = b.arco_entrante;


-- FINE COSTRUZIONE DEL GRAFO


-- AGGIORNO LA TIPOLOGIA DEI NODI IN RELAZIONE AGLI OGGETTI CON IL NOME DEL QUERY LAYER IN AUTHOR PER AVERE LE DEFINIZIONE DEI CAMPI 
-- TODO DATO UN ELENCO DI LIVELLI GISCLIENT QUESTO VIENE FATTO AUTOMATICAMENTE
ALTER TABLE grafo.nodi ADD COLUMN tipo_nodo character varying;
ALTER TABLE grafo.nodi ADD COLUMN id_elemento integer;

-- VALVOLE ZONA (1)/MAGLIATURA (2)
update grafo.nodi set tipo_nodo='valvola zona', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=1) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola zona', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=1 and e.id_stato_valvola not in (4,5)) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola zona CR', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=1 and e.id_stato_valvola=5) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola zona AR', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=1 and e.id_stato_valvola=4) as foo where nodi.id_nodo=foo.id_nodo;

update grafo.nodi set tipo_nodo='valvola magliatura', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=2) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola magliatura', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=2 and e.id_stato_valvola not in (4,5)) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola magliatura CR', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=2 and e.id_stato_valvola=5) as foo where nodi.id_nodo=foo.id_nodo;
--update grafo.nodi set tipo_nodo='valvola magliatura AR', id_elemento = fid from
--(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_isolation_device e where
--ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=2 and e.id_stato_valvola=4) as foo where nodi.id_nodo=foo.id_nodo;


-- CAMERE gtype=10, VALVOLA (4)/ POLIVALENTI (3)/ BARICENTRO (1)/
update grafo.nodi set tipo_nodo='camera valvola', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=10 and e.id_tipologia=4) as foo where nodi.id_nodo=foo.id_nodo;
update grafo.nodi set tipo_nodo='camera polivalente', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=10 and e.id_tipologia=3) as foo where nodi.id_nodo=foo.id_nodo;
update grafo.nodi set tipo_nodo='camera baricentro', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=10 and e.id_tipologia=1) as foo where nodi.id_nodo=foo.id_nodo;


-- POZZETTI gtype=20, VALVOLA (4)/ BARICENTRO (3)/ POLIVALENTE (5)/
update grafo.nodi set tipo_nodo='pozzetto valvola', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=20 and e.id_tipologia=4) as foo where nodi.id_nodo=foo.id_nodo;
update grafo.nodi set tipo_nodo='pozzetto baricentro', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=20 and e.id_tipologia=3) as foo where nodi.id_nodo=foo.id_nodo;
update grafo.nodi set tipo_nodo='pozzetto polivalente', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_component e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=20 and e.id_tipologia=5) as foo where nodi.id_nodo=foo.id_nodo;

--
-- SOTTOSTAZIONI
update grafo.nodi set tipo_nodo='sottostazione utenza', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_service e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.id_tipologia=4) as foo where nodi.id_nodo=foo.id_nodo;
-- STAZIONI DI POMPAGGIO
update grafo.nodi set tipo_nodo='stazione di pompaggio', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_installation e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=20) as foo where nodi.id_nodo=foo.id_nodo;
-- CENTRALI IREN
update grafo.nodi set tipo_nodo='centrale IREN', id_elemento = fid from
(select fid, id_nodo from grafo.nodi n, teleriscaldamento.fcl_h_installation e where
ST_DWithin(n.the_geom,e.geom,0.01) and e.gtype_id=10) as foo where nodi.id_nodo=foo.id_nodo;

--ELEMENTO GENERICO
update grafo.nodi set tipo_nodo='altro' where tipo_nodo is null;

CREATE INDEX nodi_tipo_idx ON grafo.nodi (tipo_nodo);


-- AGGIORNO LA TABELLA ARCHI CON I TIPI E INDICI
UPDATE grafo.archi set da_tipo = nodi.tipo_nodo FROM grafo.nodi WHERE da_nodo=nodi.id_nodo;
UPDATE grafo.archi set a_tipo = nodi.tipo_nodo FROM grafo.nodi WHERE a_nodo=nodi.id_nodo;
CREATE INDEX archi_da_nodo_idx ON grafo.archi (da_nodo);
CREATE INDEX archi_a_nodo_idx ON grafo.archi (a_nodo);
CREATE INDEX archi_the_geom_gist ON grafo.archi USING gist (the_geom);


-- 20201002 MZ - rimossa temporaneamente parte del TEST, da concordare eventualmente con Zio
-- TEST 

drop table if exists grafo.ricerca;
CREATE TABLE grafo.ricerca
(
  id serial,
  a_nodo integer,
  a_tipo character varying,
  gs_id integer,
  the_geom geometry
);

-- SELEZIONE DALLA TRATTA CON ESCLUSIONE DI ELEMENTI
--insert into grafo.ricerca
--WITH RECURSIVE search_graph(da_nodo, a_nodo, a_tipo, gs_id, the_geom, depth, path, cycle) AS (
--        SELECT g.da_nodo, g.a_nodo, g.a_tipo, g.id_arco, g.the_geom, 1,
--          ARRAY[g.id_arco],
--          false
--        FROM grafo.archi g where g.id_arco=30421
--      UNION ALL
--        SELECT g.da_nodo, g.a_nodo, g.a_tipo, g.id_arco, g.the_geom, sg.depth + 1,
--          path || g.id_arco,
--          g.id_arco = ANY(path)
--        FROM grafo.archi g, search_graph sg
--        WHERE g.da_nodo = sg.a_nodo AND (g.da_tipo='altro' or g.da_nodo in(9137,9306)) AND NOT cycle
--)
--SELECT  da_nodo, a_nodo, a_tipo, gs_id, the_geom FROM search_graph  limit 10000;

-- SELEZIONE DALLA TRATTA CON ESCLUSIONE DI ELEMENTI
--WITH RECURSIVE search_graph(da_nodo, a_nodo, da_tipo, a_tipo, gs_id, the_geom, depth, path, cycle) AS (
--        SELECT g.da_nodo, g.a_nodo, g.da_tipo, g.a_tipo, g.id_arco, g.the_geom, 1,
--          ARRAY[g.id_arco],
--          false
--        FROM grafo.archi g where g.id_arco=6755
--      UNION ALL
--        SELECT g.da_nodo, g.a_nodo, g.da_tipo, g.a_tipo, g.id_arco, g.the_geom, sg.depth + 1,
--          path || g.id_arco,
--          g.id_arco = ANY(path) OR (g.da_tipo='altro')
--        FROM grafo.archi g, search_graph sg
--        WHERE g.da_nodo = sg.a_nodo AND (g.da_tipo='altro') AND NOT cycle
--)
--SELECT  da_nodo, a_nodo, da_tipo, a_tipo, gs_id, the_geom FROM search_graph  limit 10000;
