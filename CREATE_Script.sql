-- Table: public.RacingTrack

-- DROP TABLE public.RacingTrack;

CREATE TABLE public.RacingTrack
(
    Id integer NOT NULL,
    Name character varying COLLATE pg_catalog.default NOT NULL,
    Finalized boolean NOT NULL,
    CONSTRAINT RacingTrack_pkey PRIMARY KEY (Id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.RacingTrack
    OWNER to postgres;
    
    
CREATE SEQUENCE racingtrackid START 1;

-- Table: public.Position

-- DROP TABLE public.Position;

CREATE TABLE public.Position
(
    RacingTrackId integer NOT NULL,
    Timestamp bigint NOT NULL,
    Latitude double precision NOT NULL,
    Longitude double precision NOT NULL,
    CONSTRAINT Position_pkey PRIMARY KEY (RacingTrackId, Timestamp),
    CONSTRAINT RacingTrackId FOREIGN KEY (RacingTrackId)
        REFERENCES public.RacingTrack (Id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.Position
    OWNER to postgres;