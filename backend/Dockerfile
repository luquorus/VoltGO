# Build stage
FROM gradle:8.5-jdk17-alpine AS build
WORKDIR /app

# Copy Gradle files
COPY build.gradle settings.gradle ./
COPY gradle ./gradle

# Copy source code (V130 migration is added here)
COPY src ./src

# Build application — force no Gradle cache
RUN gradle clean build -x test --no-daemon --no-build-cache

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy built JAR
COPY --from=build /app/build/libs/*.jar app.jar

# Expose port
EXPOSE 8080

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]

