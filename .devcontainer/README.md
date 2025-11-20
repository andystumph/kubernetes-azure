# Dev Container Configuration

This project uses a dev container based on the `astumph/iac` image, which includes Terraform, Ansible, and Azure CLI tools.

## Platform-Specific Configuration

The `devcontainer.json` file contains platform-specific mount configurations. The current configuration is set for **Windows**.

### Windows Configuration (Current)
```json
"mounts": [
  "source=${localEnv:USERPROFILE}/.azure,target=/root/.azure,type=bind,consistency=cached"
]
```

### Linux/Mac Configuration
For Linux or Mac systems, modify the mounts section in `devcontainer.json`:
```json
"mounts": [
  "source=${localEnv:HOME}/.azure,target=/root/.azure,type=bind,consistency=cached"
]
```

## Environment Variables

### Required Setup
1. Copy the environment template:
   ```bash
   # Windows (PowerShell)
   Copy-Item .env.example .env
   
   # Linux/Mac
   cp .env.example .env
   ```

2. Edit `.env` with your Azure credentials and configuration

### Optional: Mount .env File
If you want to share the `.env` file with the container, add this to the mounts array:
```json
"source=${localWorkspaceFolder}/.env,target=/workspaces/${localWorkspaceFolderBasename}/.env,type=bind,consistency=cached"
```

**Note**: Only add this mount after creating the `.env` file, otherwise the container will fail to start.

## Azure CLI Authentication

The dev container automatically mounts your local Azure CLI configuration (`~/.azure` or `%USERPROFILE%\.azure`) to preserve authentication between container restarts.

Make sure you're logged in to Azure CLI on your host system:
```bash
az login
az account set --subscription <your-subscription-id>
```

## Troubleshooting

### Mount Errors
- **Windows**: Ensure you're using `${localEnv:USERPROFILE}` for the Azure mount
- **Linux/Mac**: Ensure you're using `${localEnv:HOME}` for the Azure mount
- **Missing .env**: Don't mount `.env` file until it exists

### Permissions (Linux/Mac)
If you encounter permission issues, you may need to adjust the `remoteUser` setting or use a non-root user configuration.

### Container Not Starting
1. Check Docker is running
2. Verify the mount paths exist on your host system
3. Ensure VS Code has the Dev Containers extension installed
4. Try rebuilding the container: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"