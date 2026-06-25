-- Populate film_text from film (the table is created in 1-postgres-sakila-schema.sql).
-- Done here, after 2-postgres-sakila-insert-data.sql has loaded the film rows.
INSERT INTO film_text (film_id, title, description)
    SELECT film_id, title, description FROM film;

-- Full-text search index on film_text. A *functional* GIN index (not a stored
-- tsvector column), so the column set stays identical to the other variants —
-- FTS is added "under" the table, invisible to schema introspection. Query via:
--   SELECT * FROM film_text
--   WHERE to_tsvector('english', title || ' ' || coalesce(description, ''))
--         @@ to_tsquery('english', 'astronaut');
CREATE INDEX film_text_fts ON film_text
    USING gin (to_tsvector('english', title || ' ' || coalesce(description, '')));

-- The database dump used the "postgres" user. But we want everything to
-- be owned by the sakila user.
ALTER SCHEMA public OWNER TO sakila;
ALTER DATABASE sakila OWNER TO sakila;
REASSIGN OWNED BY postgres TO sakila;
DROP OWNED BY postgres;
DROP USER IF EXISTS postgres;

SELECT 'sakiladb/postgres has successfully initialized.' AS sakiladb_completion_message;
