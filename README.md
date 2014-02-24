aqs
===

aqs: Asynchronous Queries Scheduler

Gems:

- pg: https://rubygems.org/gems/pg
- pgpass: http://rubygems.org/gems/pgpass
- work_queue: http://rubygems.org/gems/work_queue

Modules:
- Timeout: http://www.ruby-doc.org/stdlib-2.1.0/libdoc/timeout/rdoc/Timeout.html

---------------------------------------------------------------------------------------

The purpose of this script is to run a series of queries stored in a database (a PostgreSQL in this case), where each query is supposed to run on a specific day.
Each query from the group of queries is ran by a different thread, all of them belonging to an asynchronous and limited thread pool.
Operations information is logged to a file, as well as the tasks database is also uptaded with the information of the queries result.
This script is intended to run associated to a cron table.

Some details are still incomplete, and some pieces of code may be a bit rough.
