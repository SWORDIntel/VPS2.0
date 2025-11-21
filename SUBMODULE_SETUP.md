# VPS2.0 Submodule Setup Guide

This document describes the submodule configuration and setup process for VPS2.0.

## Overview

VPS2.0 uses git submodules to integrate external components:

| Submodule | Path | Repository | Branch | Status |
|-----------|------|------------|--------|--------|
| HURRICANE | `external/HURRICANE` | SWORDIntel/HURRICANE | `main` | ✓ Public |
| CLOUDCLEAR | `external/CLOUDCLEAR` | SWORDIntel/CLOUDCLEAR | `master` | ✓ Public |
| SWORDINTELLIGENCE | `external/SWORDINTELLIGENCE` | SWORDOps/SWORDINTELLIGENCE | `main` | ✓ Public |
| ARTICBASTION | `external/ARTICBASTION` | SWORDIntel/ARTICBASTION | `main` | ⚠️ Private |

## Branch Tracking

All submodules are configured to track their respective main/master branches instead of specific commits. This ensures you always get the latest updates when running:

```bash
git submodule update --remote
```

## Initial Setup

### Automated Setup (Recommended)

Run the preparation script to initialize all submodules:

```bash
./prepare-installation.sh
```

This script will:
- Sync submodule URLs from `.gitmodules`
- Initialize and update all public submodules
- Verify branch tracking configuration
- Check system requirements
- Provide next steps for installation

### Manual Setup

If you prefer to initialize submodules manually:

```bash
# Sync submodule configuration
git submodule sync

# Initialize and update all submodules
git submodule update --init --remote --recursive
```

## ARTICBASTION Setup (Private Repository)

The ARTICBASTION submodule requires authentication as it's a private repository. You have two options:

### Option 1: SSH Authentication (Recommended)

1. **Generate SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Add SSH key to GitHub**:
   - Copy your public key: `cat ~/.ssh/id_ed25519.pub`
   - Go to GitHub Settings → SSH and GPG keys → New SSH key
   - Paste and save

3. **Update ARTICBASTION URL to use SSH**:
   ```bash
   git config submodule.external/ARTICBASTION.url git@github.com:SWORDIntel/ARTICBASTION.git
   git submodule sync external/ARTICBASTION
   git submodule update --init --remote external/ARTICBASTION
   ```

### Option 2: Personal Access Token (HTTPS)

1. **Create GitHub Personal Access Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `repo` scope
   - Copy the token

2. **Initialize ARTICBASTION with token**:
   ```bash
   git config submodule.external/ARTICBASTION.url https://YOUR_TOKEN@github.com/SWORDIntel/ARTICBASTION.git
   git submodule sync external/ARTICBASTION
   git submodule update --init --remote external/ARTICBASTION
   ```

   **Note**: For security, consider using Git credential helpers instead of embedding tokens in URLs.

### Option 3: Skip ARTICBASTION (Not Recommended)

If you don't need the ARTICBASTION secure gateway component, you can proceed without it. However, this will disable certain security features. To skip:

```bash
# Remove from .gitmodules and index
git config --remove-section submodule.external/ARTICBASTION
git rm --cached external/ARTICBASTION
```

## Updating Submodules

### Update All Submodules

To update all submodules to the latest commit on their tracked branches:

```bash
git submodule update --remote --recursive
```

### Update Specific Submodule

To update only one submodule:

```bash
git submodule update --remote external/HURRICANE
```

### Commit Submodule Updates

After updating submodules, you need to commit the changes in the parent repository:

```bash
git add external/HURRICANE external/CLOUDCLEAR external/SWORDINTELLIGENCE
git commit -m "Update submodules to latest versions"
git push
```

## Verifying Submodule Status

Check the current status of all submodules:

```bash
git submodule status
```

Output explanation:
- `[space]<commit>` - Submodule is checked out at the correct commit
- `-<commit>` - Submodule is not initialized
- `+<commit>` - Submodule is checked out at a different commit than expected
- `U<commit>` - Submodule has merge conflicts

## Troubleshooting

### Submodule is empty or not initialized

```bash
git submodule deinit -f external/SUBMODULE_NAME
git submodule update --init --remote external/SUBMODULE_NAME
```

### Submodule is detached from HEAD

```bash
cd external/SUBMODULE_NAME
git checkout main  # or master for CLOUDCLEAR
cd ../..
```

### Reset all submodules to clean state

```bash
git submodule foreach --recursive git reset --hard
git submodule update --init --remote --recursive
```

### Authentication errors for ARTICBASTION

If you get authentication errors:

1. Verify your SSH key is added to GitHub:
   ```bash
   ssh -T git@github.com
   ```

2. Check submodule URL configuration:
   ```bash
   git config --get submodule.external/ARTICBASTION.url
   ```

3. Ensure you have access to the private repository on GitHub

## Integration with VPS2.0 Deployment

The submodules are integrated into VPS2.0's deployment system:

- **HURRICANE**: IPv6 proxy and tunneling (`docker-compose.hurricane.yml`)
- **CLOUDCLEAR**: Cloud infrastructure detection and analysis (`docker-compose.cloudclear.yml`)
- **SWORDINTELLIGENCE**: Main intelligence platform (`docker-compose.intelligence.yml`)
- **ARTICBASTION**: Secure bastion gateway (`docker-compose.articbastion.yml`)

These components are deployed as part of the unified deployment manager (`deploy-vps2.sh`) or can be deployed individually.

## Best Practices

1. **Always update submodules before deployment**:
   ```bash
   git submodule update --remote --recursive
   ```

2. **Commit submodule pointer updates**:
   When submodules are updated, commit the changes in the parent repo to track the new commits.

3. **Use branch tracking**:
   The `.gitmodules` file specifies which branch each submodule should track, ensuring consistent updates.

4. **Regular updates**:
   Periodically update submodules to get the latest features and security patches.

## Additional Resources

- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [VPS2.0 README](./README.md)
- [VPS2.0 Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)
- [Quick Start Guide](./QUICKSTART.md)
