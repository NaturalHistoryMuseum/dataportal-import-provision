dataportal-import-provision
===========================

Provision script for Data Portal import server (mongo &amp; luigi)

Install all of the components needed to run the KE EMu import tasks.

This does not mount the KE EMu export directories. Needs to be located on the same server as the export directories.


SETUP
-----

To run tasks using the scheduler, need to get the tornado server running:

    python luigi/server.py
    

RUNNING
-------

Set up a cron to run every thursday morning (after the exports have run) 

* * * * * /usr/lib/import/bin/python /usr/lib/import/src/ke2mongo/ke2mongo/tasks/cron.py >> /var/log/crontab/ke2mongo.log 2>&1



ERRORS
------

On error, an email will be sent to address LUIGI_ERROR_EMAIL

Note: The error messages only get sent if this isn't running from command line (with a terminal receiving stdout)

When running this, if there's an error luigi task will hold the state. It is safe to restart the tornado service, and manually rerun the task

