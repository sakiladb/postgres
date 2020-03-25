# sakiladb/postgres

Postgres docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jooq](https://www.jooq.org/sakila)).

By default these are created:
- database: `sakila`
- user/pass: `sakila` / `p_ssW0rd`


To start:

```shell script
docker run -p 5432:5432 -d sakiladb/postgres
```

Note that it may take some time for the container to boot up. Then Verify that all is well:

```shell script
$ PGPASSWORD=p_ssW0rd psql -h localhost -d sakila -U sakila -c 'SELECT * FROM actor LIMIT 5'                                     master ✱
 actor_id | first_name |  last_name   |     last_update
----------+------------+--------------+---------------------
        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33
        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33
        3 | ED         | CHASE        | 2006-02-15 04:34:33
        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33
        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33
```
