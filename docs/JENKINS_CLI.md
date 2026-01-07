# Jenkins CLI - Terminal Access Guide

Access Jenkins from your terminal without the GUI.

## Installation

Jenkins CLI is already installed at `~/bin/jenkins-cli`

### Manual Installation

If you need to reinstall:

```bash
# Port forward Jenkins
kubectl port-forward -n amazon-api svc/jenkins 8080:8080 &

# Download CLI
curl -sL http://localhost:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar

# Make wrapper executable
chmod +x ~/bin/jenkins-cli
```

---

## Quick Start

The CLI automatically authenticates using credentials from Kubernetes!

```bash
# List all jobs
jenkins-cli list-jobs

# Or use aliases
jlist                  # List jobs
jbuild amazon-api-users  # Build job
jconsole amazon-api-users  # View console

# Other commands
jenkins-cli get-job amazon-api-users-service
jenkins-cli version
```

### First Run

On first use, jenkins-cli automatically:
1. ✅ Fetches credentials from Kubernetes
2. ✅ Saves them to `~/.jenkins-cli`
3. ✅ Uses them for all future commands

---

## Common Commands

### Job Management

```bash
# List all jobs
jenkins-cli list-jobs

# Build job
jenkins-cli build JOB_NAME

# Build with parameters
jenkins-cli build JOB_NAME -p PARAM1=value1 -p PARAM2=value2

# Stop build
jenkins-cli stop-build JOB_NAME BUILD_NUMBER

# Get job config
jenkins-cli get-job JOB_NAME > job-config.xml

# Create/update job
jenkins-cli create-job NEW_JOB < job-config.xml
jenkins-cli update-job EXISTING_JOB < job-config.xml

# Delete job
jenkins-cli delete-job JOB_NAME

# Disable/enable job
jenkins-cli disable-job JOB_NAME
jenkins-cli enable-job JOB_NAME
```

### Build Information

```bash
# Get build info
jenkins-cli get-build JOB_NAME BUILD_NUMBER

# Console output
jenkins-cli console JOB_NAME
jenkins-cli console JOB_NAME BUILD_NUMBER

# List builds
jenkins-cli list-builds JOB_NAME

# Build queue
jenkins-cli queue
```

### Nodes & System

```bash
# List nodes
jenkins-cli list-nodes

# Node info
jenkins-cli get-node NODE_NAME

# Online/offline node
jenkins-cli online-node NODE_NAME
jenkins-cli offline-node NODE_NAME

# System info
jenkins-cli version
jenkins-cli who-am-i
```

### Plugin Management

```bash
# List plugins
jenkins-cli list-plugins

# Install plugin
jenkins-cli install-plugin PLUGIN_NAME

# Safe restart
jenkins-cli safe-restart

# Reload config
jenkins-cli reload-configuration
```

---

## Examples

### Trigger amazon-api-users Build

```bash
# Build latest
jenkins-cli build amazon-api-users-service

# Wait for completion
jenkins-cli build amazon-api-users-service -s

# Follow console output
jenkins-cli build amazon-api-users-service -s -v
```

### Check Build Status

```bash
# Latest build console
jenkins-cli console amazon-api-users-service

# Specific build
jenkins-cli console amazon-api-users-service 42

# Build result
jenkins-cli get-build amazon-api-users-service lastBuild
```

### Export/Import Jobs

```bash
# Backup all jobs
for job in $(jenkins-cli list-jobs); do
    jenkins-cli get-job "$job" > "backup/${job}.xml"
done

# Restore job
jenkins-cli create-job new-job < backup/amazon-api-users-service.xml
```

---

## Authentication

### Using API Token (Recommended)

1. Generate token in Jenkins GUI:
   - User menu → Configure → API Token → Add new Token

2. Use with CLI:
```bash
jenkins-cli -auth username:API_TOKEN list-jobs
```

3. Or set environment variable:
```bash
export JENKINS_USER_ID=your-username
export JENKINS_API_TOKEN=your-token

jenkins-cli list-jobs
```

### Using Password

```bash
jenkins-cli -auth username:password list-jobs
```

---

## Advanced Usage

### Scripting

```bash
#!/bin/bash
# Deploy script

# Trigger build
BUILD=$(jenkins-cli build amazon-api-users-service -s -v | grep "Started")

# Wait for completion
while true; do
    STATUS=$(jenkins-cli get-build amazon-api-users-service lastBuild | grep "result")
    if [ -n "$STATUS" ]; then
        echo "$STATUS"
        break
    fi
    sleep 5
done
```

### Groovy Scripts

```bash
# Execute Groovy script
jenkins-cli groovy =<< 'EOF'
println "Hello from Groovy!"
Jenkins.instance.getAllItems().each { println it.name }
EOF
```

### Watch Build

```bash
# Follow build in real-time
watch -n 2 'jenkins-cli console amazon-api-users-service lastBuild | tail -20'
```

---

## Wrapper Script Features

The `~/bin/jenkins-cli` wrapper provides:

✅ **Auto Port-Forward** - Starts `kubectl port-forward` if needed  
✅ **Colored Output** - Easy-to-read error messages  
✅ **Automatic Cleanup** - Kills port-forward on exit  

### Configuration

Set environment variables to customize:

```bash
# Custom Jenkins URL
export JENKINS_URL=http://jenkins.example.com:8080

# Custom CLI jar location
export JENKINS_CLI_JAR=/path/to/jenkins-cli.jar
```

---

## Troubleshooting

### Issue: Connection Refused

```bash
# Check port-forward
kubectl get pods -n amazon-api | grep jenkins

# Manual port-forward
kubectl port-forward -n amazon-api svc/jenkins 8080:8080
```

### Issue: Authentication Failed

```bash
# Get current user
jenkins-cli who-am-i

# Check credentials
jenkins-cli -auth username:token who-am-i
```

### Issue: Command Not Found

```bash
# Add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or use full path
~/bin/jenkins-cli list-jobs
```

---

## Comparison: GUI vs CLI

| Task | GUI | CLI |
|------|-----|-----|
| **Trigger Build** | Click → Build Now | `jenkins-cli build JOB` |
| **View Console** | Click → Console Output | `jenkins-cli console JOB` |
| **Job Config** | Click → Configure | `jenkins-cli get-job JOB` |
| **Bulk Operations** | Manual, one by one | Script loops |
| **Automation** | Not possible | Full automation |
| **Speed** | Slow (page loads) | Fast (direct API) |

---

## Tips & Tricks

### 1. Alias for Convenience

```bash
# Add to ~/.bashrc
alias jc='jenkins-cli'
alias jbuild='jenkins-cli build'
alias jconsole='jenkins-cli console'

# Usage
jbuild amazon-api-users-service
jconsole amazon-api-users-service
```

### 2. Tab Completion

```bash
# List jobs for tab completion
jenkins-cli list-jobs > /tmp/jenkins-jobs.txt

# Use in scripts
JOB=$(cat /tmp/jenkins-jobs.txt | fzf)  # If you have fzf
jenkins-cli build "$JOB"
```

### 3. Watch Builds

```bash
# Real-time monitoring
watch -n 5 'jenkins-cli list-builds amazon-api-users-service | head -10'
```

---

## Resources

- [Jenkins CLI Official Docs](https://www.jenkins.io/doc/book/managing/cli/)
- [Jenkins REST API](https://www.jenkins.io/doc/book/using/remote-access-api/)

---

## Summary

```bash
# Essential commands
jenkins-cli list-jobs              # List all jobs
jenkins-cli build JOB_NAME         # Trigger build
jenkins-cli console JOB_NAME       # View output
jenkins-cli get-job JOB_NAME       # Get config
jenkins-cli version                # Jenkins version
```

**Jenkins CLI Location:** `~/bin/jenkins-cli`  
**Jenkins JAR:** `/tmp/jenkins-cli.jar`  
**Jenkins URL:** `http://localhost:8080` (via port-forward)

---

**Last Updated:** 2026-01-07  
**Maintained By:** Development Team
