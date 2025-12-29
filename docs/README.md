# Documentation

Complete documentation for the Amazon Store project.

## 📚 Main Documentation

### Active Guides

- **[VAULT.md](VAULT.md)** - Complete Vault setup, unsealing, and secret management
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[SPRING_PROFILES_GUIDE.md](SPRING_PROFILES_GUIDE.md)** - Spring profiles configuration

### Kubernetes Specific

Located in `k8s/docs/`:
- **[CI_CD_SETUP.md](../k8s/docs/CI_CD_SETUP.md)** - CI/CD pipeline setup
- **[DEPLOYMENT_SUMMARY.md](../k8s/docs/DEPLOYMENT_SUMMARY.md)** - Deployment overview
- **[KAFKA_SETUP.md](../k8s/docs/KAFKA_SETUP.md)** - Kafka configuration
- **[KONG_SETUP.md](../k8s/docs/KONG_SETUP.md)** - Kong API gateway setup

## 🗄️ Archived Documentation

The `archive/` directory contains historical documentation that may be outdated but is kept for reference:

### Project History
- **CHANGES.md** - Initial changes log
- **IMPLEMENTATION_SUMMARY.md** - Original implementation notes
- **FILES_STATUS.md** - Old file status review
- **PORT_CHANGE_SUMMARY.md** - Port change history

### Replaced by Current Docs
- **VAULT_SETUP.md** - Now consolidated in [VAULT.md](VAULT.md)
- **VAULT_MIGRATION.md** - Production section now in [VAULT.md](VAULT.md)
- **VAULT_IMPLEMENTATION_COMPLETE.md** - Merged into [VAULT.md](VAULT.md)
- **POSTGRESQL_VAULT_INTEGRATION.md** - PostgreSQL section in [VAULT.md](VAULT.md)
- **VAULT-UNSEAL.md** - Unsealing section in [VAULT.md](VAULT.md)

### Old Setup Guides
- **DEPLOYMENT_STEPS.md** - Superseded by current README
- **STARTUP_GUIDE.md** - Superseded by QUICKSTART.md
- **CICD_ARCHITECTURE.md** - Now in k8s/docs/CI_CD_SETUP.md
- **JENKINS_CASC_GUIDE.md** - Jenkins configuration details
- **SEPARATE_PIPELINES_SETUP.md** - Pipeline setup information
- **QUICK_REFERENCE.md** - Old quick reference
- **INTRUCTIONS_TO_CONFIG_GITHUB.md** - GitHub setup (typo in original name)

## 🎯 Quick Links

### Getting Started
1. Read [../README.md](../README.md) - Project overview
2. Follow [../QUICKSTART.md](../QUICKSTART.md) - Quick setup guide
3. Configure [VAULT.md](VAULT.md) - Set up secrets management

### Need Help?
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) first
- Review relevant guide from the list above
- Check archived docs if looking for historical context

## 📝 Documentation Maintenance

### When to Archive
Move documentation to `archive/` when:
- Content is completely superseded by newer docs
- Information is outdated but worth keeping for reference
- Document describes one-time migrations/changes

### When to Keep Active
Keep documentation in main `docs/` when:
- Content is actively maintained and current
- Information is referenced regularly
- Guide is part of standard workflow

---

**Last Updated:** December 2025
