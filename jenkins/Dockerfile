# Dockerfile for Jenkins with Docker CLI (Docker-outside-of-Docker)
FROM jenkins/jenkins:lts-jdk17

# Skip Jenkins setup wizard for demo (no manual config needed)
ENV JAVA_OPTS=-Djenkins.install.runSetupWizard=false

# Install Docker CLI to enable docker build/push commands inside Jenkins
USER root
RUN apt-get update && apt-get install -y \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Switch back to jenkins user
USER jenkins

# Entrypoint tự động chạy Jenkins, không cần override
