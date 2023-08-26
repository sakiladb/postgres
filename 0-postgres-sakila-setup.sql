-- The database dump uses the 'postgres' user, so we create that user here.
-- We'll delete it later.
CREATE USER postgres WITH PASSWORD 'p_ssW0rd' CREATEDB;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
