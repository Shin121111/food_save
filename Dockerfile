FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY backend/pom.xml backend/pom.xml
COPY backend/src backend/src
COPY user user
COPY ["Shop owner log in screen", "Shop owner log in screen"]
RUN mvn -f backend/pom.xml -B -DskipTests package
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/backend/target/good-store-0.1.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
