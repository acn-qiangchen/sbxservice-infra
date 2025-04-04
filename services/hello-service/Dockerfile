# Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /app
# Copy pom.xml to download dependencies
COPY pom.xml .
# Download dependencies (separate layer for caching)
RUN mvn dependency:go-offline -B
# Copy source code
COPY src ./src
# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# Add a non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
# Copy the JAR file from the build stage
COPY --from=builder /app/target/*.jar app.jar
# Expose application port
EXPOSE 8080
# Set healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

# Run the application with proper JVM options
ENTRYPOINT ["java", \
  "-XX:+UnlockExperimentalVMOptions", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", \
  "app.jar"] 