This is a notification system that is, a web application to send notes over IOT (mqtt broker). It is based on the PUBLISH-SUBSCRIBE Architural style.

The core of the project was developed by ildus

TO RUN THE PROGRAM RUN THE FOLLOWING COMMANDS IN THE TERMINAL:
git clone git@github.com:chiefcorlyns/etables.git
git clone git@github.com:ildus/etables.git
cd etables
mkdir db && mkdir db/dev
make
../start-dev.sh


TO SETUP THE MNESIA DATABASE CLICK ENTER AND CONTINUE TO RUN:
tablesdb:reset().
helpers:new_user("admin", "password", true).


The webpage can be accessed on this ip: http://localhost:8080