dataportal-import-provision
===========================

Provision script for Data Portal import server (mongo &amp; luigi)

Install all of the components needed to run the KE EMu import tasks.

This does not mount the KE EMu export directories. Needs to be located on the same server as the export directories.
   

RUNNING
-------

Set up a cron to run 3am friday morning - exports are delivered throughout Thursday, and if there's an error it can be fixed on Friday

0 03 * * 5 /usr/lib/import/bin/python /usr/lib/import/src/ke2mongo/ke2mongo/run.py >> /var/log/crontab/ke2mongo.log 2>&1

The main file is run.py.

python run.py -l

Otherwise, will need the tornado scheduler.


SCHEDULER
---------

Luigi uses tornado as a centralised server for managing tasks. 

To start the tornado server manually:

    python luigi/server.py

Our provision script installs tornado and runs it under supervisor.

Tasks are viewable http://10.11.12.16:8082/

If there's an error, the task will get stuck in error. To rerun restart supervisor process.

    sudo supervisorctl restart tornado_luigi


ERRORS
------

On error, an email will be sent to address LUIGI_ERROR_EMAIL

Note: The error messages only get sent if this isn't running from command line (with a terminal receiving stdout)

When running this, if there's an error luigi task will hold the state. It is safe to restart the tornado service, and manually rerun the task.

