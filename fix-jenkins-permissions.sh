#!/bin/bash
# Fix Jenkins home directory permissions
echo "Fixing jenkins_home permissions..."
sudo chown -R 1000:1000 jenkins_home/
echo "Restarting Jenkins..."
docker compose restart jenkins
echo "Done! Wait 60 seconds for Jenkins to start, then check with: docker logs amazon-api-jenkins"
