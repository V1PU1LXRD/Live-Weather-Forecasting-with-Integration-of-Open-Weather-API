#!/bin/sh
# Tomcat sources this before starting. Render (and most PaaS hosts) tell the app
# which port to bind by setting $PORT; locally we fall back to 8080.
#
# server.xml reads ${http.port}, and Tomcat resolves ${...} in server.xml from
# *system properties* — NOT from environment variables. So we translate the
# environment variable into a system property here.
PORT="${PORT:-8080}"
export CATALINA_OPTS="$CATALINA_OPTS -Dhttp.port=$PORT"
