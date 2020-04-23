CREATE USER sakila WITH PASSWORD 'p_ssW0rd' CREATEDB;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sakila;

SELECT 'sakiladb/postgres has successfully initialized.' AS sakiladb_completion_message;