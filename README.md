# sakiladb/postgres

Postgres docker image preloaded with the [Sakila](https://dev.mysql.com/doc/sakila/en/) example
database (by way of [jooq](https://www.jooq.org/sakila)).
See on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres).

By default these are created:
- database: `sakila`
- username / password: `sakila` / `p_ssW0rd`



```shell script
docker run -p 5432:5432 -d sakiladb/postgres:latest
```

Or use a specific version of postgres (see all available image tags
on [Docker Hub](https://hub.docker.com/r/sakiladb/postgres/tags).)

```shell script
docker run -p 5432:5432 -d sakiladb/postgres:9.6
```



Note that it may take some time for the container to boot up.
Eventually the container's docker logs will show:

```
sakiladb/postgres has successfully initialized.
```

Note that even after this message is logged, it may take another few moments for
it to become available (due to a final server restart etc).


To verify that all is well:

```shell script
$ PGPASSWORD=p_ssW0rd psql -h localhost -d sakila -U sakila -c 'SELECT * FROM actor LIMIT 5'
 actor_id | first_name |  last_name   |     last_update
----------+------------+--------------+---------------------
        1 | PENELOPE   | GUINESS      | 2006-02-15 04:34:33
        2 | NICK       | WAHLBERG     | 2006-02-15 04:34:33
        3 | ED         | CHASE        | 2006-02-15 04:34:33
        4 | JENNIFER   | DAVIS        | 2006-02-15 04:34:33
        5 | JOHNNY     | LOLLOBRIGIDA | 2006-02-15 04:34:33
```
