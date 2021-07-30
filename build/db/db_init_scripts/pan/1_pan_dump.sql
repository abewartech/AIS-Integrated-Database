--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.10
-- Dumped by pg_dump version 10.5 (Debian 10.5-1.pgdg90+1)

-- Started on 2021-07-28 08:20:54 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 216 (class 1259 OID 15705702)
-- Name: bad_ports_list; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bad_ports_list (
    country text,
    port text,
    id bigint NOT NULL
);


ALTER TABLE public.bad_ports_list OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 15705700)
-- Name: bad_ports_list_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bad_ports_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bad_ports_list_id_seq OWNER TO postgres;

--
-- TOC entry 3634 (class 0 OID 0)
-- Dependencies: 215
-- Name: bad_ports_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bad_ports_list_id_seq OWNED BY public.bad_ports_list.id;


--
-- TOC entry 204 (class 1259 OID 15705611)
-- Name: crew; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crew (
    family_name text,
    given_names text,
    initials text,
    gender text,
    birth_date date,
    nationality text,
    travel_doc_num text,
    travel_doc_exp date,
    crew_rank text,
    crew_add_info text,
    id bigint NOT NULL,
    vessel_report_id integer
);


ALTER TABLE public.crew OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 15705609)
-- Name: crew_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crew_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.crew_id_seq OWNER TO postgres;

--
-- TOC entry 3635 (class 0 OID 0)
-- Dependencies: 203
-- Name: crew_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.crew_id_seq OWNED BY public.crew.id;


--
-- TOC entry 206 (class 1259 OID 15705627)
-- Name: pax; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pax (
    family_name text,
    given_names text,
    initials text,
    gender text,
    birth_date date,
    nationality text,
    travel_doc_num text,
    travel_doc_exp date,
    pax_add_info text,
    pax_add_info_2 text,
    id bigint NOT NULL,
    vessel_report_id integer
);


ALTER TABLE public.pax OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 15705625)
-- Name: pax_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pax_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pax_id_seq OWNER TO postgres;

--
-- TOC entry 3636 (class 0 OID 0)
-- Dependencies: 205
-- Name: pax_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pax_id_seq OWNED BY public.pax.id;


--
-- TOC entry 210 (class 1259 OID 15705659)
-- Name: pax_other; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pax_other (
    family_name text,
    given_names text,
    initials text,
    gender text,
    birth_date date,
    nationality text,
    travel_doc_num text,
    travel_doc_exp date,
    reason_for_on_board text,
    other_add_info text,
    other_add_info2 text,
    id bigint NOT NULL,
    vessel_report_id integer
);


ALTER TABLE public.pax_other OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 15705657)
-- Name: pax_other_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pax_other_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pax_other_id_seq OWNER TO postgres;

--
-- TOC entry 3637 (class 0 OID 0)
-- Dependencies: 209
-- Name: pax_other_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pax_other_id_seq OWNED BY public.pax_other.id;


--
-- TOC entry 214 (class 1259 OID 15705691)
-- Name: persons_list; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.persons_list (
    name text,
    travel_doc_num text,
    birth_date date,
    id bigint NOT NULL
);


ALTER TABLE public.persons_list OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 15705689)
-- Name: persons_list_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.persons_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.persons_list_id_seq OWNER TO postgres;

--
-- TOC entry 3638 (class 0 OID 0)
-- Dependencies: 213
-- Name: persons_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.persons_list_id_seq OWNED BY public.persons_list.id;


--
-- TOC entry 212 (class 1259 OID 15705675)
-- Name: ports_visited; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ports_visited (
    country text,
    port text,
    date_visited date,
    visit_num integer,
    security_level text,
    special_measures text,
    appropriate_security text,
    vessel_report_id integer,
    id bigint NOT NULL
);


ALTER TABLE public.ports_visited OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 15705673)
-- Name: ports_visited_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ports_visited_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ports_visited_id_seq OWNER TO postgres;

--
-- TOC entry 3639 (class 0 OID 0)
-- Dependencies: 211
-- Name: ports_visited_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ports_visited_id_seq OWNED BY public.ports_visited.id;


--
-- TOC entry 208 (class 1259 OID 15705643)
-- Name: security; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.security (
    family_name text,
    given_names text,
    initials text,
    gender text,
    birth_date date,
    status text,
    nationality text,
    travel_doc_num text,
    travel_doc_exp date,
    port_embarked text,
    date_employed date,
    security_company text,
    security_address text,
    security_contact text,
    security_add_info text,
    security_add_info_2 text,
    id bigint NOT NULL,
    vessel_report_id integer
);


ALTER TABLE public.security OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 15705641)
-- Name: security_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.security_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.security_id_seq OWNER TO postgres;

--
-- TOC entry 3640 (class 0 OID 0)
-- Dependencies: 207
-- Name: security_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.security_id_seq OWNED BY public.security.id;


--
-- TOC entry 218 (class 1259 OID 15708975)
-- Name: vessel_red_list; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vessel_red_list (
    callsign text,
    imo text,
    mmsi text,
    name text,
    id bigint NOT NULL
);


ALTER TABLE public.vessel_red_list OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 15708973)
-- Name: vessel_red_list_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vessel_red_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vessel_red_list_id_seq OWNER TO postgres;

--
-- TOC entry 3641 (class 0 OID 0)
-- Dependencies: 217
-- Name: vessel_red_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vessel_red_list_id_seq OWNED BY public.vessel_red_list.id;


--
-- TOC entry 202 (class 1259 OID 15705599)
-- Name: vessel_report; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vessel_report (
    name text,
    imo text,
    callsign text,
    port_of_registry text,
    current_security_level text,
    report_time timestamp with time zone,
    processed_time timestamp with time zone,
    reported_position public.geometry(Point,4326),
    reported_class text,
    reported_cog numeric,
    reported_sog numeric,
    destination text,
    next_destination text,
    weapons text,
    cargo text,
    eta text,
    filename text,
    id bigint NOT NULL,
    opl_stores text,
    opl_crewchange text,
    opl_technicalservices text,
    opl_bunkers text,
    opl_medicalevac text,
    opl_emergency text,
    opl_other text,
    opl_tanker text
);


ALTER TABLE public.vessel_report OWNER TO postgres;

--
-- TOC entry 201 (class 1259 OID 15705597)
-- Name: vessel_report_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vessel_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vessel_report_id_seq OWNER TO postgres;

--
-- TOC entry 3642 (class 0 OID 0)
-- Dependencies: 201
-- Name: vessel_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vessel_report_id_seq OWNED BY public.vessel_report.id;


--
-- TOC entry 3478 (class 2604 OID 15705705)
-- Name: bad_ports_list id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bad_ports_list ALTER COLUMN id SET DEFAULT nextval('public.bad_ports_list_id_seq'::regclass);


--
-- TOC entry 3472 (class 2604 OID 15705614)
-- Name: crew id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crew ALTER COLUMN id SET DEFAULT nextval('public.crew_id_seq'::regclass);


--
-- TOC entry 3473 (class 2604 OID 15705630)
-- Name: pax id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax ALTER COLUMN id SET DEFAULT nextval('public.pax_id_seq'::regclass);


--
-- TOC entry 3475 (class 2604 OID 15705662)
-- Name: pax_other id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax_other ALTER COLUMN id SET DEFAULT nextval('public.pax_other_id_seq'::regclass);


--
-- TOC entry 3477 (class 2604 OID 15705694)
-- Name: persons_list id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons_list ALTER COLUMN id SET DEFAULT nextval('public.persons_list_id_seq'::regclass);


--
-- TOC entry 3476 (class 2604 OID 15705678)
-- Name: ports_visited id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ports_visited ALTER COLUMN id SET DEFAULT nextval('public.ports_visited_id_seq'::regclass);


--
-- TOC entry 3474 (class 2604 OID 15705646)
-- Name: security id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.security ALTER COLUMN id SET DEFAULT nextval('public.security_id_seq'::regclass);


--
-- TOC entry 3479 (class 2604 OID 15708978)
-- Name: vessel_red_list id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vessel_red_list ALTER COLUMN id SET DEFAULT nextval('public.vessel_red_list_id_seq'::regclass);


--
-- TOC entry 3471 (class 2604 OID 15705602)
-- Name: vessel_report id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vessel_report ALTER COLUMN id SET DEFAULT nextval('public.vessel_report_id_seq'::regclass);


--
-- TOC entry 3496 (class 2606 OID 15705710)
-- Name: bad_ports_list bad_ports_list_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bad_ports_list
    ADD CONSTRAINT bad_ports_list_pkey PRIMARY KEY (id);


--
-- TOC entry 3484 (class 2606 OID 15705619)
-- Name: crew crew_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crew
    ADD CONSTRAINT crew_pkey PRIMARY KEY (id);


--
-- TOC entry 3490 (class 2606 OID 15705667)
-- Name: pax_other pax_other_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax_other
    ADD CONSTRAINT pax_other_pkey PRIMARY KEY (id);


--
-- TOC entry 3486 (class 2606 OID 15705635)
-- Name: pax pax_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax
    ADD CONSTRAINT pax_pkey PRIMARY KEY (id);


--
-- TOC entry 3494 (class 2606 OID 15705699)
-- Name: persons_list persons_list_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons_list
    ADD CONSTRAINT persons_list_pkey PRIMARY KEY (id);


--
-- TOC entry 3492 (class 2606 OID 15705683)
-- Name: ports_visited ports_visited_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ports_visited
    ADD CONSTRAINT ports_visited_pkey PRIMARY KEY (id);


--
-- TOC entry 3488 (class 2606 OID 15705651)
-- Name: security security_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.security
    ADD CONSTRAINT security_pkey PRIMARY KEY (id);


--
-- TOC entry 3498 (class 2606 OID 15708983)
-- Name: vessel_red_list vessel_red_list_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vessel_red_list
    ADD CONSTRAINT vessel_red_list_pkey PRIMARY KEY (id);


--
-- TOC entry 3481 (class 2606 OID 15705607)
-- Name: vessel_report vessel_report_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vessel_report
    ADD CONSTRAINT vessel_report_pkey PRIMARY KEY (id);


--
-- TOC entry 3482 (class 1259 OID 15705608)
-- Name: vessel_report_report_time_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX vessel_report_report_time_idx ON public.vessel_report USING btree (report_time);


--
-- TOC entry 3499 (class 2606 OID 15705620)
-- Name: crew crew_vessel_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crew
    ADD CONSTRAINT crew_vessel_report_id_fkey FOREIGN KEY (vessel_report_id) REFERENCES public.vessel_report(id) ON DELETE CASCADE;


--
-- TOC entry 3502 (class 2606 OID 15705668)
-- Name: pax_other pax_other_vessel_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax_other
    ADD CONSTRAINT pax_other_vessel_report_id_fkey FOREIGN KEY (vessel_report_id) REFERENCES public.vessel_report(id) ON DELETE CASCADE;


--
-- TOC entry 3500 (class 2606 OID 15705636)
-- Name: pax pax_vessel_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pax
    ADD CONSTRAINT pax_vessel_report_id_fkey FOREIGN KEY (vessel_report_id) REFERENCES public.vessel_report(id) ON DELETE CASCADE;


--
-- TOC entry 3503 (class 2606 OID 15705684)
-- Name: ports_visited ports_visited_vessel_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ports_visited
    ADD CONSTRAINT ports_visited_vessel_report_id_fkey FOREIGN KEY (vessel_report_id) REFERENCES public.vessel_report(id) ON DELETE CASCADE;


--
-- TOC entry 3501 (class 2606 OID 15705652)
-- Name: security security_vessel_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.security
    ADD CONSTRAINT security_vessel_report_id_fkey FOREIGN KEY (vessel_report_id) REFERENCES public.vessel_report(id) ON DELETE CASCADE;


-- Completed on 2021-07-28 08:20:54 UTC

--
-- PostgreSQL database dump complete
--

