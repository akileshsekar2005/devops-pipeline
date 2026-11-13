# Build once, ship that artifact: the pipeline runs `mvn verify` first and
# downloads target/app.jar into the build context. Locally: mvn package && docker build .
FROM eclipse-temurin:25-jre-alpine

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Non-root user (UID must match runAsUser in k8s/deployment.yaml)
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app

WORKDIR /app
COPY target/app.jar app.jar

USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
