# Live Weather Forecasting — Tomcat 9 (Servlet 4 / javax.servlet, JDK 17)
FROM tomcat:9.0-jdk17-temurin

# Default for local `docker run -p 8080:8080`. Render overrides this with its
# own PORT (default 10000) once the service is created.
ENV PORT=8080

# Small-instance friendly flags + explicit UTF-8 so JSP output renders correctly.
ENV CATALINA_OPTS="-Dfile.encoding=UTF-8 -XX:+UseSerialGC"

# json-simple 1.1.1 — the only runtime dependency (JSON parsing).
ARG JSON_SIMPLE_URL=https://repo1.maven.org/maven2/com/googlecode/json-simple/json-simple/1.1.1/json-simple-1.1.1.jar

# 1. Clear the stock webapps so only our app is served at "/"
# 2. Point Tomcat's HTTP connector at the ${http.port} system property.
#    NOTE: server.xml resolves ${...} from *system properties*, so ${env.PORT}
#    does NOT work here — docker/setenv.sh maps $PORT onto -Dhttp.port.
# 3. Fetch json-simple into WEB-INF/lib
RUN set -eux; \
    rm -rf /usr/local/tomcat/webapps/*; \
    mkdir -p /usr/local/tomcat/webapps/ROOT/WEB-INF/lib; \
    sed -i 's/port="8080"/port="${http.port}"/' /usr/local/tomcat/conf/server.xml; \
    grep -qF 'port="${http.port}"' /usr/local/tomcat/conf/server.xml; \
    curl -fsSL "$JSON_SIMPLE_URL" -o /usr/local/tomcat/webapps/ROOT/WEB-INF/lib/json-simple-1.1.1.jar; \
    test -s /usr/local/tomcat/webapps/ROOT/WEB-INF/lib/json-simple-1.1.1.jar

# Maps $PORT -> -Dhttp.port before Tomcat boots. Must be executable.
COPY docker/setenv.sh /usr/local/tomcat/bin/setenv.sh
RUN chmod +x /usr/local/tomcat/bin/setenv.sh

COPY weather.jsp /usr/local/tomcat/webapps/ROOT/index.jsp

EXPOSE 8080

# Fail the container if the app stops responding, so the host can restart it.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/" > /dev/null || exit 1

CMD ["catalina.sh", "run"]
