# Java dev workspace image for Coder on vajra.
# - JDK 21 (Temurin)
# - Maven, Gradle
# - Node 20 (frontend tooling)
# - code-server (browser IDE)
# - Non-root user `coder` UID 1000
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64 \
    MAVEN_HOME=/opt/maven \
    GRADLE_HOME=/opt/gradle \
    PATH=/opt/maven/bin:/opt/gradle/bin:/usr/lib/jvm/temurin-21-jdk-amd64/bin:/usr/local/bin:/usr/bin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release sudo git \
      unzip zip bash-completion jq vim less \
      build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Temurin JDK 21
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" \
      > /etc/apt/sources.list.d/adoptium.list \
 && apt-get update && apt-get install -y --no-install-recommends temurin-21-jdk \
 && rm -rf /var/lib/apt/lists/*

# Maven
ARG MAVEN_VERSION=3.9.9
RUN curl -fsSL "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt && ln -s "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven

# Gradle
ARG GRADLE_VERSION=8.10.2
RUN curl -fsSL -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
 && unzip -q /tmp/gradle.zip -d /opt && rm /tmp/gradle.zip \
 && ln -s "/opt/gradle-${GRADLE_VERSION}" /opt/gradle

# Node 20 (NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Non-root user
RUN useradd --create-home --uid 1000 --shell /bin/bash coder \
 && mkdir -p /home/coder/workspace \
 && chown -R coder:coder /home/coder

USER coder
WORKDIR /home/coder
