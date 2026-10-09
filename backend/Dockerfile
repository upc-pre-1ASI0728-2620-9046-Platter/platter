# syntax=docker/dockerfile:1
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S platter && adduser -S platter -G platter && mkdir -p /data/storage && chown -R platter /data
COPY --from=build /src/target/platter-backend-*.jar app.jar
USER platter
# Ajustado para instancias pequeñas (p. ej. Render free: 512 MB, CPU compartida)
ENV STORAGE_DIR=/data/storage \
    JAVA_OPTS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -Xss512k -XX:ReservedCodeCacheSize=48m -XX:TieredStopAtLevel=1"
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=40s --retries=5 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
