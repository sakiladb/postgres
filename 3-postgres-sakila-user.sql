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

-- ---------------------------------------------------------------------------
-- Mutation-maintenance triggers — exact parity with sakiladb/mysql.
--
-- Defined here, after 2-postgres-sakila-insert-data.sql, so they govern only
-- post-build mutations and never clobber the historical data. MySQL does the
-- same: its triggers are defined after the data load (e.g. customer_create_date
-- follows the customer INSERTs), which is why the historical dates survive.
-- All sq-invisible (sq counts tables/views, not triggers), so the fixture's
-- schema contract is unchanged.
-- ---------------------------------------------------------------------------

-- film_text stays in sync with film (MySQL's ins_film / upd_film / del_film).
-- The functional GIN index above rides along automatically, so full-text
-- search stays correct under mutation.
CREATE FUNCTION film_text_ins() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO film_text (film_id, title, description)
        VALUES (NEW.film_id, NEW.title, NEW.description);
    RETURN NEW;
END $$;

CREATE TRIGGER ins_film
    AFTER INSERT ON film
    FOR EACH ROW
    EXECUTE FUNCTION film_text_ins();

CREATE FUNCTION film_text_upd() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    IF (OLD.title <> NEW.title)
        OR (OLD.description <> NEW.description)
        OR (OLD.film_id <> NEW.film_id) THEN
        UPDATE film_text
            SET title = NEW.title,
                description = NEW.description,
                film_id = NEW.film_id
            WHERE film_id = OLD.film_id;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER upd_film
    AFTER UPDATE ON film
    FOR EACH ROW
    EXECUTE FUNCTION film_text_upd();

CREATE FUNCTION film_text_del() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM film_text WHERE film_id = OLD.film_id;
    RETURN OLD;
END $$;

CREATE TRIGGER del_film
    AFTER DELETE ON film
    FOR EACH ROW
    EXECUTE FUNCTION film_text_del();

-- Date columns are forced to NOW() on insert (MySQL's customer_create_date /
-- payment_date / rental_date BEFORE INSERT triggers). Like MySQL, these
-- override any supplied value; the columns carry no DEFAULT, so the trigger is
-- the sole mechanism that stamps new rows.
CREATE FUNCTION set_customer_create_date() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    NEW.create_date = NOW();
    RETURN NEW;
END $$;

CREATE TRIGGER customer_create_date
    BEFORE INSERT ON customer
    FOR EACH ROW
    EXECUTE FUNCTION set_customer_create_date();

CREATE FUNCTION set_payment_date() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    NEW.payment_date = NOW();
    RETURN NEW;
END $$;

CREATE TRIGGER payment_date
    BEFORE INSERT ON payment
    FOR EACH ROW
    EXECUTE FUNCTION set_payment_date();

CREATE FUNCTION set_rental_date() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    NEW.rental_date = NOW();
    RETURN NEW;
END $$;

CREATE TRIGGER rental_date
    BEFORE INSERT ON rental
    FOR EACH ROW
    EXECUTE FUNCTION set_rental_date();

-- The database dump used the "postgres" user. But we want everything to
-- be owned by the sakila user.
ALTER SCHEMA public OWNER TO sakila;
ALTER DATABASE sakila OWNER TO sakila;
REASSIGN OWNED BY postgres TO sakila;
DROP OWNED BY postgres;
DROP USER IF EXISTS postgres;

SELECT 'sakiladb/postgres has successfully initialized.' AS sakiladb_completion_message;
