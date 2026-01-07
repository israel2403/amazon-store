# Jenkins CLI - Quick Reference

## Setup Complete! ✅

Your Jenkins CLI is configured and ready to use from anywhere.

---

## Aliases (Available Now)

```bash
jlist              # List all jobs
jbuild JOB_NAME    # Trigger build
jconsole JOB_NAME  # View console output
jc COMMAND         # Short for jenkins-cli
```

**Note:** For new terminal sessions, run: `source ~/.bashrc`

---

## Common Commands

### Jobs
```bash
jlist                           # List all jobs
jbuild amazon-api-users         # Build job
jconsole amazon-api-users       # View latest console
jconsole amazon-api-users 42    # View build #42
jenkins-cli get-job JOB_NAME    # Get job XML config
```

### Build Status
```bash
jenkins-cli list-builds amazon-api-users    # List all builds
jenkins-cli queue                           # View build queue
jenkins-cli version                         # Jenkins version
```

### System
```bash
jenkins-cli who-am-i              # Current user (should show: admin)
jenkins-cli list-nodes            # List Jenkins agents
jenkins-cli list-plugins          # List installed plugins
```

---

## Examples

### Trigger Build and Wait
```bash
jbuild amazon-api-users -s
```

### Follow Console in Real-Time
```bash
jbuild amazon-api-users -s -v
```

### Watch Latest Build
```bash
watch -n 2 'jconsole amazon-api-users | tail -20'
```

### Export Job Config
```bash
jenkins-cli get-job amazon-api-users > backup.xml
```

---

## Authentication

✅ **Automatic!** Credentials loaded from Kubernetes and saved to `~/.jenkins-cli`

**Manual override (if needed):**
```bash
export JENKINS_USER=admin
export JENKINS_PASS=your-password
```

**Credential file location:** `~/.jenkins-cli`

---

## Troubleshooting

### Path not working?
```bash
source ~/.bashrc
# Or start a new terminal
```

### Port forward not working?
```bash
kubectl port-forward -n amazon-api svc/jenkins 8080:8080
```

### Credentials issue?
```bash
rm ~/.jenkins-cli          # Remove cached creds
jenkins-cli version        # Will re-fetch from K8s
```

---

## Full Documentation

See `docs/JENKINS_CLI.md` for complete guide.

---

**Jenkins CLI:** `jenkins-cli` (available from any directory)  
**Config:** `~/.jenkins-cli`  
**Aliases:** `jc`, `jlist`, `jbuild`, `jconsole`
