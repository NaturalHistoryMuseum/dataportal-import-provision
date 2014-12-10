dataportal-import-provision
===========================

Provision script for Data Portal import server (mongo &amp; luigi)

Install all of the components needed to run the KE EMu import tasks.

This does not mount the KE EMu export directories. Needs to be located on the same server as the export directories.


SETUP
-----

To run tasks using the scheduler, need to get the tornado server running:

    python luigi/server.py
    
    



Note: The error messages are only get sent if this isn't running from command line (with a terminal receiving stdout)



RUNNING
-------

When running this, if there's an error luigi task will hold the state. It is safe to restart the tornado service, and manually rerun the task

