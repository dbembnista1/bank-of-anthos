# Multi-stage build for Bank of Anthos balancereader (Spring Boot).
# Maven runs only in the build stage; the runtime image ships the fat JAR + JRE.

FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app

COPY pom.xml checkstyle.xml ./
COPY src ./src

RUN mvn -q -DskipTests package \
    && mv target/balancereader-1.0.jar /app/app.jar

FROM eclipse-temurin:17.0.13_11-jre-alpine
WORKDIR /app

RUN addgroup -S app && adduser -S -G app app
USER app

COPY --from=build /app/app.jar /app/app.jar

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
