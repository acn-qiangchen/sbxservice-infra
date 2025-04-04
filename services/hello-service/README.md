# Hello Service

## Overview

Hello Service is a simple Spring Boot microservice that provides a "Hello World" API. It serves as the first microservice implementation in the sbxservice project, establishing patterns and practices for future services.

## Features

- RESTful API with a simple greeting endpoint
- Swagger/OpenAPI documentation
- Health monitoring via Spring Boot Actuator
- Containerized with Docker
- Comprehensive test coverage

## API Endpoints

| Method | Endpoint | Description | Parameters |
|--------|----------|-------------|------------|
| GET | `/api/hello` | Returns a greeting message | `name` (optional): Name to include in greeting |
| GET | `/actuator/health` | Health check endpoint | None |
| GET | `/swagger-ui.html` | API documentation UI | None |

## Technology Stack

- Spring Boot 3.2.x
- Java 17
- Maven
- Docker
- JUnit 5 & Mockito (testing)
- SpringDoc OpenAPI (API documentation)

## Architecture

This service follows a standard layered architecture with controller, service, and model components. For a detailed explanation of the architecture, design decisions, and component interactions, see the [Architecture Documentation](docs/ARCHITECTURE.md).

## Getting Started

### Prerequisites

- Java 17 or higher
- Maven 3.8 or higher
- Docker (for containerized deployment)

For detailed installation instructions for these prerequisites, please refer to the [Development Setup Guide](DEVELOPMENT.md).

### Running Locally

#### Using Maven

```bash
# Navigate to the service directory
cd services/hello-service

# Build the application
mvn clean package

# Run the application
mvn spring-boot:run
```

#### Using Docker

```bash
# Navigate to the service directory
cd services/hello-service

# Build the Docker image
docker build -t sbxservice/hello-service .

# Run the container
docker run -p 8080:8080 sbxservice/hello-service
```

### Testing the API

Once the service is running, you can access:

- API endpoint: http://localhost:8080/api/hello
- With a name parameter: http://localhost:8080/api/hello?name=YourName
- API documentation: http://localhost:8080/swagger-ui.html
- Health check: http://localhost:8080/actuator/health

## Configuration

The service uses Spring Boot's configuration system with `application.yml` files:

- `application.yml` - Default configuration
- `application-local.yml` - Local development configuration
- `application-dev.yml` - Development environment configuration
- `application-test.yml` - Test environment configuration
- `application-prod.yml` - Production environment configuration

To run with a specific profile, use the `spring.profiles.active` property:

```bash
mvn spring-boot:run -Dspring.profiles.active=local
```

## Testing

```bash
# Run tests
mvn test

# Run tests with coverage report
mvn test jacoco:report
```

## Development

For a comprehensive guide on setting up your development environment, coding standards, and common troubleshooting tips, please refer to our [Development Setup Guide](DEVELOPMENT.md).

## Documentation

- [Development Setup Guide](DEVELOPMENT.md) - Detailed guide for setting up your development environment
- [Architecture Documentation](docs/ARCHITECTURE.md) - Detailed explanation of the service architecture

## Additional Information

- This service follows the standard Spring Boot architecture with controller, service, and configuration layers
- The service is designed to be stateless to support horizontal scaling
- Logging uses SLF4J with Logback configuration
- Error handling follows RESTful best practices with appropriate HTTP status codes 