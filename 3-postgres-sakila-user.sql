-- Populate film_text from film (the table is created in 1-postgres-sakila-schema.sql).
-- Done here, after 2-postgres-sakila-insert-data.sql has loaded the film rows.
INSERT INTO film_text (film_id, title, description)
    SELECT film_id, title, description FROM film;

-- The database dump used the "postgres" user. But we want everything to
-- be owned by the sakila user.
ALTER SCHEMA public OWNER TO sakila;
ALTER DATABASE sakila OWNER TO sakila;
REASSIGN OWNED BY postgres TO sakila;
DROP OWNED BY postgres;
DROP USER IF EXISTS postgres;

SELECT 'sakiladb/postgres has successfully initialized.' AS sakiladb_completion_message;
