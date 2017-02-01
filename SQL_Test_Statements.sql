-- This documents contains statements for testing

--INSERT 

INSERT INTO racingtrack(id, name, finalized) VALUES (nextval('racingtrackid'), 'first track', FALSE)

INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (4, 1432712399, 48.366937, 14.517274);
INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (4, 1432713399, 48.366824, 14.519130);
INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (4, 1432714399, 48.366011, 14.520267);
INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (4, 1432715399, 48.365655, 14.520847);
INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (4, 1432716399, 48.365313, 14.521898);

-- SELECT
SELECT * FROM racingtrack

SELECT row_to_json(racingtrack) FROM racingtrack;

SELECT id FROM racingtrack WHERE finalized = FALSE

SELECT * FROM position WHERE racingtrackid =4

SELECT array_to_json(array_agg(json_build_object('timestamp', timestamp, 'latitude', latitude, 'longitude', longitude))) as positions FROM position WHERE racingtrackid = 4

-- UPDATE

UPDATE racingtrack SET finalized = FALSE WHERE id = 4;

-- DELETE 

DELETE FROM racingtrack WHERE id = 1