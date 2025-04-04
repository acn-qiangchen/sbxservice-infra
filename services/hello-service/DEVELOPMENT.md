# Development Setup Guide

This document provides detailed instructions for setting up your local development environment for the Hello Service microservice.

## Required Tools

### Java Development Kit (JDK) 17

The microservice requires JDK 17 or later.

#### Installation

**Mac OS (using Homebrew)**:
```bash
brew install openjdk@17
```

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install openjdk-17-jdk
```

**Windows**:
1. Download the installer from [Adoptium](https://adoptium.net/) or [Oracle](https://www.oracle.com/java/technologies/downloads/#java17)
2. Run the installer and follow the instructions

**Verify installation**:
```bash
java -version
```
The output should show Java version 17.x.x

### Maven (3.8+)

Maven is used for building and managing dependencies.

#### Installation

**Mac OS (using Homebrew)**:
```bash
brew install maven
```

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install maven
```

**Windows**:
1. Download the binary from [Maven's official site](https://maven.apache.org/download.cgi)
2. Extract to a directory of your choice
3. Add the `bin` directory to your PATH environment variable

**Verify installation**:
```bash
mvn -version
```
The output should show Maven version 3.8.x or higher

### Docker

Docker is used for containerization and local environment setup.

#### Installation

**Mac OS**:
Install [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```
Note: You may need to log out and back in for the group changes to take effect.

**Windows**:
Install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)

**Verify installation**:
```bash
docker --version
docker-compose --version
```

### IDE (Optional but recommended)

We recommend using an IDE for development:

- **IntelliJ IDEA**: [Download](https://www.jetbrains.com/idea/download/) (Community edition is free)
- **Eclipse**: [Download](https://www.eclipse.org/downloads/) with Spring Tools
- **Visual Studio Code**: [Download](https://code.visualstudio.com/) with Java extensions

## Setting Up the Project

### Clone the Repository

```bash
git clone https://github.com/your-org/sbxservice.git
cd sbxservice
```

### Building the Project

```bash
cd services/hello-service
mvn clean install
```

### Running the Application

#### Using Maven

```bash
mvn spring-boot:run
```

#### Using Maven with a specific profile

```bash
mvn spring-boot:run -Dspring.profiles.active=local
```

#### Using your IDE

Import the project as a Maven project and run the `HelloServiceApplication` class.

#### Using Docker

```bash
docker-compose up
```

This will build and start the service in a container.

## Development Workflow

### Making Changes

1. Write your code changes
2. Run tests to verify your changes: `mvn test`
3. Start the application to test manually
4. Access the API at http://localhost:8080/api/hello
5. Check the API documentation at http://localhost:8080/swagger-ui.html

### Coding Standards

Please follow these guidelines:
- Use 4 spaces for indentation
- Follow Java naming conventions
- Write Javadoc for public methods
- Include appropriate unit tests for new features
- Format code according to the project style

## Troubleshooting

### Common Issues

#### Port 8080 is already in use

Change the port in `application.yml` or use a command-line override:
```bash
mvn spring-boot:run -Dserver.port=8081
```

#### Maven build fails

Ensure you have the correct JDK version:
```bash
java -version
mvn -v
```

Both should show Java 17.

#### Docker issues

If you encounter permission issues with Docker:
```bash
sudo chmod 666 /var/run/docker.sock
```

## Helpful Commands

### Maven Commands

```bash
# Clean and build
mvn clean install

# Run tests only
mvn test

# Run with a specific profile
mvn spring-boot:run -Dspring.profiles.active=local

# Generate project site with reports
mvn site
```

### Docker Commands

```bash
# Build container
docker build -t sbxservice/hello-service .

# Run container
docker run -p 8080:8080 sbxservice/hello-service

# See running containers
docker ps

# Stop container
docker stop <container-id>

# View logs
docker logs <container-id>
```

## Additional Resources

- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [OpenAPI/Swagger Documentation](https://springdoc.org/)
- [Maven Documentation](https://maven.apache.org/guides/index.html)
- [Docker Documentation](https://docs.docker.com/) 