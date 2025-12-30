# Kubernetes Troubleshooting Guide

This guide contains commands and procedures for diagnosing and fixing issues in your Kubernetes cluster.

---

## Table of Contents
- [Pod Issues](#pod-issues)
- [Service & Network Issues](#service--network-issues)
- [Jenkins Issues](#jenkins-issues)
- [Vault Issues](#vault-issues)
- [ConfigMap & Secret Issues](#configmap--secret-issues)
- [Deployment Issues](#deployment-issues)
- [Storage Issues](#storage-issues)
- [Common Error Patterns](#common-error-patterns)

---

## Pod Issues

### 1. Check Pod Status
**Command:**
```bash
kubectl get pods -n amazon-api
```

**What to look for:**
- `STATUS` column: Should be `Running` (not `CrashLoopBackOff`, `Error`, `CreateContainerConfigError`, `ImagePullBackOff`)
- `READY` column: Should show `1/1` or `X/X` (all containers ready)
- `RESTARTS` column: Low numbers are okay, but high numbers indicate recurring crashes

**Example output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
jenkins-54f5876f95-rlq72         1/1     Running   0          10m
vault-55c7bc5645-m6zq7           1/1     Running   0          20m
postgres-abc123-xyz              1/1     Running   0          30m
```

---

### 2. View Pod Details
**Command:**
```bash
kubectl describe pod <pod-name> -n amazon-api
```

**What to look for:**
- **Events section** (at the bottom): Shows recent errors like:
  - `Failed to pull image`
  - `Error: secret "xyz" not found`
  - `CrashLoopBackOff`
  - `Liveness probe failed`
  - `Readiness probe failed`
- **Containers section**: Check if containers started successfully
- **Conditions section**: All should be `True` for a healthy pod

**Example:**
```bash
kubectl describe pod jenkins-54f5876f95-rlq72 -n amazon-api
```

---

### 3. View Pod Logs
**Command:**
```bash
# View last 50 lines
kubectl logs -n amazon-api <pod-name> --tail=50

# View last 100 lines
kubectl logs -n amazon-api <pod-name> --tail=100

# Follow logs in real-time
kubectl logs -n amazon-api <pod-name> -f

# View logs from previous crashed container
kubectl logs -n amazon-api <pod-name> --previous
```

**What to look for:**
- Error messages, stack traces, exceptions
- "Connection refused" - indicates service not available
- "Permission denied" - indicates file permission issues
- "Port already in use" - indicates port conflict

**Example:**
```bash
kubectl logs -n amazon-api jenkins-54f5876f95-rlq72 --tail=50
```

---

### 4. Common Pod Status Issues

#### CrashLoopBackOff
**Meaning:** Container keeps crashing and Kubernetes keeps restarting it

**Diagnosis:**
```bash
# Check logs from the crashed container
kubectl logs -n amazon-api <pod-name> --previous

# Check pod events
kubectl describe pod <pod-name> -n amazon-api | grep -A 20 "Events:"
```

**Common causes:**
- Application error (check logs)
- Missing environment variables
- Wrong command or entrypoint
- Failed health checks

---

#### CreateContainerConfigError
**Meaning:** Cannot create container due to configuration issue

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n amazon-api
```

**Common causes:**
- Missing ConfigMap: `Error: configmap "xyz" not found`
- Missing Secret: `Error: secret "xyz" not found`
- Invalid volume mount

**Solution:**
```bash
# List ConfigMaps
kubectl get configmap -n amazon-api

# List Secrets
kubectl get secret -n amazon-api

# Create missing secret/configmap, then delete the pod (it will recreate)
kubectl delete pod <pod-name> -n amazon-api
```

---

#### ImagePullBackOff
**Meaning:** Cannot pull Docker image

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n amazon-api | grep -A 5 "Failed"
```

**Common causes:**
- Image doesn't exist
- Wrong image name/tag
- Private registry requires credentials
- Image is in local registry (use `imagePullPolicy: Never`)

**Solution:**
```bash
# For local images (like jenkins-custom:latest)
# Make sure image is loaded into minikube
minikube image load jenkins-custom:latest

# Or rebuild inside minikube
eval $(minikube docker-env)
docker build -t jenkins-custom:latest .
```

---

#### Pending
**Meaning:** Pod cannot be scheduled on any node

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n amazon-api | grep -A 10 "Events:"
```

**Common causes:**
- Insufficient resources (CPU/memory)
- PersistentVolumeClaim not bound
- Node selector doesn't match any nodes

**Solution:**
```bash
# Check node resources
kubectl top nodes

# Check PVCs
kubectl get pvc -n amazon-api

# Check if PVC is bound
kubectl describe pvc <pvc-name> -n amazon-api
```

---

## Service & Network Issues

### 1. Check Services
**Command:**
```bash
kubectl get svc -n amazon-api
```

**What to look for:**
- `CLUSTER-IP`: Should be assigned (not `<none>`)
- `PORT(S)`: Correct port mappings
- `TYPE`: ClusterIP, NodePort, or LoadBalancer

---

### 2. Check Service Endpoints
**Command:**
```bash
kubectl get endpoints <service-name> -n amazon-api
```

**What to look for:**
- Should show IP addresses of pods
- If empty, service selector doesn't match any pods

**Diagnosis:**
```bash
# Check service selector
kubectl describe svc <service-name> -n amazon-api | grep Selector

# Check if pods have matching labels
kubectl get pods -n amazon-api --show-labels
```

**Solution:**
```bash
# Update deployment to have correct labels matching service selector
kubectl edit deployment <deployment-name> -n amazon-api
```

---

### 3. Test Service Connectivity
**From inside cluster:**
```bash
# Run a test pod
kubectl run test-pod -n amazon-api --image=busybox --rm -it -- sh

# Inside the pod, test DNS and connectivity
wget -O- http://jenkins.amazon-api.svc.cluster.local:8080
wget -O- http://vault.amazon-api.svc.cluster.local:8200
```

**From outside cluster (port-forward):**
```bash
kubectl port-forward -n amazon-api svc/<service-name> <local-port>:<service-port>

# Example
kubectl port-forward -n amazon-api svc/jenkins 8080:8080
```

---

### 4. Network Access from External PC
**Start port-forward on all interfaces:**
```bash
kubectl port-forward -n amazon-api svc/jenkins 8080:8080 --address=0.0.0.0 &
```

**Test locally:**
```bash
curl http://localhost:8080
```

**Test from another PC:**
```bash
curl http://<server-ip>:8080
```

**If connection fails, check firewall:**
```bash
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 8080/tcp

# Check iptables
sudo iptables -L -n | grep 8080
```

---

## Jenkins Issues

### 1. Check Jenkins Status
```bash
# Check pod
kubectl get pods -n amazon-api | grep jenkins

# Check logs
kubectl logs -n amazon-api $(kubectl get pod -n amazon-api -l app=jenkins -o jsonpath='{.items[0].metadata.name}') --tail=100

# Check if Jenkins is ready
kubectl logs -n amazon-api $(kubectl get pod -n amazon-api -l app=jenkins -o jsonpath='{.items[0].metadata.name}') | grep "Jenkins is fully up and running"
```

---

### 2. Jenkins Configuration Issues
**Check ConfigMap:**
```bash
kubectl get configmap jenkins-casc -n amazon-api -o yaml
```

**Check Secrets:**
```bash
kubectl get secret jenkins-secrets -n amazon-api -o yaml

# Decode secret values
kubectl get secret jenkins-secrets -n amazon-api -o jsonpath='{.data.admin-user}' | base64 -d
kubectl get secret jenkins-secrets -n amazon-api -o jsonpath='{.data.admin-password}' | base64 -d
```

---

### 3. Jenkins Pipeline Issues
**Check pipeline logs in Jenkins UI:**
1. Go to http://localhost:8080
2. Click on pipeline → branch → build number
3. Click "Console Output"

**Check from CLI:**
```bash
# Restart Jenkins deployment
kubectl rollout restart deployment/jenkins -n amazon-api

# Watch rollout status
kubectl rollout status deployment/jenkins -n amazon-api
```

---

### 4. Jenkins Can't Access Vault
**Diagnosis:**
```bash
# Check if Vault is running
kubectl get pods -n amazon-api | grep vault

# Test connectivity from Jenkins pod
JENKINS_POD=$(kubectl get pod -n amazon-api -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n amazon-api $JENKINS_POD -- curl -I http://vault.amazon-api.svc.cluster.local:8200
```

**Check Vault credential:**
```bash
# Verify vault-root-token exists in jenkins-secrets
kubectl get secret jenkins-secrets -n amazon-api -o jsonpath='{.data.vault-root-token}' | base64 -d
```

---

### 5. Pipeline Fails with "denied: requested access to the resource is denied"

**Error in Jenkins Console:**
```
bc7091554844: Layer already exists
denied: requested access to the resource is denied
ERROR: script returned exit code 1
```

**Root Cause:**
This error occurs when Jenkins tries to push Docker images to DockerHub but authentication fails. The DockerHub credentials in Vault are either:
- Invalid/expired
- Incorrectly formatted
- Missing

**Diagnosis:**
```bash
# Check if DockerHub credentials exist in Vault
kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/dockerhub"
```

**What to check:**
- Token should be a valid DockerHub Personal Access Token (starts with `dckr_pat_`)
- Token should be 36-40 characters long
- Username should match your DockerHub username

**Solution:**

1. **Generate a new DockerHub Personal Access Token:**
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Name: `jenkins-ci`
   - Permissions: `Read, Write, Delete`
   - Copy the token (you won't see it again!)

2. **Update the token in Vault:**
   ```bash
   # Replace YOUR_NEW_TOKEN with the actual token
   kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv put kv/amazon-api/dockerhub username=israelhf24 token=YOUR_NEW_TOKEN"
   ```

3. **Verify the token was updated:**
   ```bash
   kubectl exec -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') -- sh -c "VAULT_TOKEN=hvs.qb4jSCwkdHBZwFZw14A7M7qV vault kv get kv/amazon-api/dockerhub"
   ```

4. **Re-run the Jenkins pipeline** - it should now successfully authenticate and push to DockerHub.

**Important Notes:**
- DockerHub tokens expire or can be revoked - regenerate them periodically
- Never commit tokens to Git
- Use Vault for all credential management
- **DO NOT** run `fix-jenkins-permissions.sh` - this is NOT a permissions issue

**Alternative: Test DockerHub login manually from Jenkins pod:**
```bash
JENKINS_POD=$(kubectl get pod -n amazon-api -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n amazon-api $JENKINS_POD -- sh -c "echo 'YOUR_TOKEN' | docker login -u israelhf24 --password-stdin"
```

---

## Vault Issues

### 1. Check Vault Status
```bash
# Check pod
kubectl get pods -n amazon-api | grep vault

# Check logs
kubectl logs -n amazon-api $(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}') --tail=50
```

---

### 2. Vault Not Starting
**Check for secret issues:**
```bash
kubectl describe pod -n amazon-api -l app=vault | grep -A 10 "Events:"
```

**Common issue: Missing secrets**
```bash
# Check if vault-secrets exists
kubectl get secret vault-secrets -n amazon-api

# If missing, create it
kubectl create secret generic vault-secrets -n amazon-api \
  --from-literal=root-token=dev-root-token
```

---

### 3. Test Vault Access
```bash
VAULT_POD=$(kubectl get pod -n amazon-api -l app=vault -o jsonpath='{.items[0].metadata.name}')

# Check if Vault is unsealed (dev mode auto-unseals)
kubectl exec -n amazon-api $VAULT_POD -- vault status

# List secrets
kubectl exec -n amazon-api $VAULT_POD -- vault kv list kv/amazon-api

# Read a secret
kubectl exec -n amazon-api $VAULT_POD -- vault kv get kv/amazon-api/dockerhub
```

---

### 4. Re-initialize Vault Secrets
```bash
# Run initialization script
./k8s/scripts/init-vault-secrets.sh
```

---

## ConfigMap & Secret Issues

### 1. List All ConfigMaps and Secrets
```bash
kubectl get configmap -n amazon-api
kubectl get secret -n amazon-api
```

---

### 2. View ConfigMap Contents
```bash
kubectl get configmap <name> -n amazon-api -o yaml
```

---

### 3. View Secret Contents (Decoded)
```bash
# View entire secret
kubectl get secret <name> -n amazon-api -o yaml

# Decode specific key
kubectl get secret <name> -n amazon-api -o jsonpath='{.data.<key>}' | base64 -d
```

**Example:**
```bash
kubectl get secret postgres-secrets -n amazon-api -o jsonpath='{.data.postgres-password}' | base64 -d
```

---

### 4. Update ConfigMap or Secret
```bash
# Edit directly
kubectl edit configmap <name> -n amazon-api
kubectl edit secret <name> -n amazon-api

# Or apply from file
kubectl apply -f k8s/path/to/configmap.yaml

# Restart pods to pick up changes
kubectl rollout restart deployment/<deployment-name> -n amazon-api
```

---

## Deployment Issues

### 1. Check Deployment Status
```bash
kubectl get deployments -n amazon-api
```

**What to look for:**
- `READY`: Should match `DESIRED` (e.g., 1/1, 3/3)
- `UP-TO-DATE`: All replicas running latest version
- `AVAILABLE`: Replicas passing health checks

---

### 2. Check Deployment Events
```bash
kubectl describe deployment <name> -n amazon-api
```

---

### 3. Check Rollout Status
```bash
kubectl rollout status deployment/<name> -n amazon-api
```

---

### 4. Rollout Failed - Rollback
```bash
# View rollout history
kubectl rollout history deployment/<name> -n amazon-api

# Rollback to previous version
kubectl rollout undo deployment/<name> -n amazon-api

# Rollback to specific revision
kubectl rollout undo deployment/<name> -n amazon-api --to-revision=2
```

---

### 5. Update Deployment Image
```bash
kubectl set image deployment/<name> -n amazon-api \
  <container-name>=<new-image>:<new-tag>
```

---

### 6. Restart Deployment
```bash
kubectl rollout restart deployment/<name> -n amazon-api
```

---

## Storage Issues

### 1. Check PersistentVolumeClaims
```bash
kubectl get pvc -n amazon-api
```

**What to look for:**
- `STATUS`: Should be `Bound` (not `Pending`)
- `VOLUME`: Should show a PV name

---

### 2. Check PersistentVolumes
```bash
kubectl get pv
```

---

### 3. PVC Stuck in Pending
**Diagnosis:**
```bash
kubectl describe pvc <name> -n amazon-api
```

**Common causes:**
- No PV available that matches the PVC requirements
- Insufficient storage on nodes
- StorageClass doesn't exist

**Solution for Minikube:**
```bash
# Minikube usually auto-provisions, but you can manually create PV if needed
# Check if dynamic provisioning is enabled
kubectl get storageclass
```

---

## Common Error Patterns

### Error: "dial tcp: lookup xyz on X.X.X.X:53: no such host"
**Meaning:** DNS resolution failed

**Solution:**
```bash
# Check if CoreDNS is running
kubectl get pods -n kube-system | grep coredns

# Check service FQDN format
# Should be: <service-name>.<namespace>.svc.cluster.local
```

---

### Error: "connection refused"
**Meaning:** Service not listening on that port or not running

**Solution:**
```bash
# Check if pod is running
kubectl get pods -n amazon-api

# Check if service has endpoints
kubectl get endpoints <service-name> -n amazon-api

# Test from within cluster
kubectl run test -n amazon-api --image=busybox --rm -it -- wget -O- http://<service>:8080
```

---

### Error: "context deadline exceeded"
**Meaning:** Operation timed out

**Common in:**
- Image pulls (slow network)
- Readiness/liveness probes (app slow to start)
- kubectl commands (API server overloaded)

**Solution:**
```bash
# Increase timeout
kubectl wait --for=condition=ready pod/<pod-name> -n amazon-api --timeout=5m

# For probes, edit deployment to increase initialDelaySeconds
kubectl edit deployment <name> -n amazon-api
```

---

### Error: "OOMKilled"
**Meaning:** Container exceeded memory limit and was killed

**Diagnosis:**
```bash
kubectl describe pod <name> -n amazon-api | grep -A 5 "Last State"
```

**Solution:**
```bash
# Increase memory limits in deployment
kubectl edit deployment <name> -n amazon-api

# Find the resources section and increase limits:
# resources:
#   limits:
#     memory: "2Gi"  # Increase this
```

---

## Quick Reference Commands

### Get Everything in Namespace
```bash
kubectl get all -n amazon-api
```

### Delete and Recreate Pod
```bash
kubectl delete pod <pod-name> -n amazon-api
# Deployment will automatically create a new one
```

### Force Delete Stuck Pod
```bash
kubectl delete pod <pod-name> -n amazon-api --force --grace-period=0
```

### Get Pod YAML
```bash
kubectl get pod <pod-name> -n amazon-api -o yaml
```

### Execute Command in Pod
```bash
kubectl exec -n amazon-api <pod-name> -- <command>

# Interactive shell
kubectl exec -n amazon-api <pod-name> -it -- /bin/sh
```

### Copy Files To/From Pod
```bash
# Copy from pod to local
kubectl cp amazon-api/<pod-name>:/path/to/file ./local-file

# Copy from local to pod
kubectl cp ./local-file amazon-api/<pod-name>:/path/to/file
```

### Watch Resources in Real-Time
```bash
watch -n 2 kubectl get pods -n amazon-api
```

### Get Resource Usage
```bash
kubectl top nodes
kubectl top pods -n amazon-api
```

---

## Emergency Recovery

### Restart Entire Stack
```bash
# Restart all deployments
kubectl rollout restart deployment -n amazon-api

# Or delete all pods (they will recreate)
kubectl delete pods --all -n amazon-api
```

### Redeploy Everything
```bash
# Dev environment
kubectl delete namespace amazon-api
kubectl apply -k k8s/overlays/dev/

# Prod environment
kubectl delete namespace amazon-api
kubectl apply -k k8s/overlays/prod/
```

### Reset Minikube
```bash
minikube stop
minikube delete
minikube start
```

---

## Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods -n amazon-api'
alias kgd='kubectl get deployments -n amazon-api'
alias kgs='kubectl get svc -n amazon-api'
alias klogs='kubectl logs -n amazon-api'
alias kdesc='kubectl describe -n amazon-api'
alias kexec='kubectl exec -n amazon-api -it'
```

Then use:
```bash
kgp  # Instead of kubectl get pods -n amazon-api
klogs <pod-name> --tail=50
```

---

## Getting Help

### Kubernetes Documentation
```bash
# Get help for any resource
kubectl explain pod
kubectl explain deployment.spec
kubectl explain service.spec.ports

# List all resource types
kubectl api-resources
```

### Jenkins Documentation
- Configuration as Code: https://github.com/jenkinsci/configuration-as-code-plugin
- Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/

### Vault Documentation
- Dev Mode: https://developer.hashicorp.com/vault/docs/concepts/dev-server
- KV Secrets Engine: https://developer.hashicorp.com/vault/docs/secrets/kv

---

## Troubleshooting Workflow

When something breaks, follow this order:

1. **Check pod status** → `kubectl get pods -n amazon-api`
2. **Check pod events** → `kubectl describe pod <name> -n amazon-api`
3. **Check logs** → `kubectl logs -n amazon-api <name> --tail=100`
4. **Check service endpoints** → `kubectl get endpoints <service> -n amazon-api`
5. **Check secrets/configmaps** → `kubectl get secret,configmap -n amazon-api`
6. **Test connectivity** → Port-forward and curl
7. **Check resources** → `kubectl top nodes` and `kubectl top pods -n amazon-api`

Most issues will be revealed in steps 1-3!
