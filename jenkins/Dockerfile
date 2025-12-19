FROM jenkins/jenkins:lts-jdk21

USER root

# Install Docker CLI
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Maven
RUN apt-get update && \
    apt-get install -y maven && \
    rm -rf /var/lib/apt/lists/*

# Install Jenkins plugins
RUN jenkins-plugin-cli --plugins \
    configuration-as-code \
    job-dsl \
    git \
    workflow-aggregator \
    docker-workflow \
    kubernetes-cli \
    credentials-binding \
    hashicorp-vault-plugin \
    github-branch-source

# Add jenkins user to docker group (use host's docker group ID)
RUN groupadd -g 984 docker || true && \
    usermod -aG docker jenkins

USER jenkins
