# Chatwoot Environment Variables & Secrets Guide

This guide explains how to generate and configure the necessary secrets and environment variables for your Chatwoot deployment on Hostinger VPS.

## 1. Generating Secrets

You need to generate a few secure values. You can run these commands in your local terminal (if you have Ruby/OpenSSL installed) or use an online generator (use with caution).

### Secret Key Base
This is used to verify the integrity of signed cookies.
```bash
# Option 1: If you have Ruby installed
rake secret

# Option 2: Using OpenSSL
openssl rand -hex 64
```

### Postgres Password
Generate a strong password for your database.
```bash
openssl rand -base64 24
```

## 2. GitHub Secrets

Go to your repository on GitHub:
1.  Click **Settings** tab.
2.  On the left, click **Secrets and variables** > **Actions**.
3.  Click **New repository secret**.

Add the following secrets:

| Name | Description | Example Value |
| :--- | :--- | :--- |
| `HOST_IP` | The IP address of your Hostinger VPS. | `123.45.67.89` |
| `HOST_USER` | The SSH username for your VPS (usually `root`). | `root` |
| `SSH_PRIVATE_KEY` | The private key to SSH into your VPS. | `-----BEGIN OPENSSH PRIVATE KEY----- ...` |
| `POSTGRES_PASSWORD` | The password you generated above. | `your_generated_postgres_password` |
| `SECRET_KEY_BASE` | The secret key you generated above. | `your_generated_secret_key` |
| `CHATWOOT_DOMAIN` | Your domain name. | `automationservice.cloud` |
| `LETSENCRYPT_EMAIL` | Email for SSL certificate notifications. | `admin@automationservice.cloud` |

### How to get `SSH_PRIVATE_KEY`
If you haven't set up an SSH key specifically for GitHub Actions:
1.  Generate a new key pair locally: `ssh-keygen -t ed25519 -f chatwoot_deploy`
2.  Check the private key: `cat chatwoot_deploy` -> **Copy this to GitHub Secret `SSH_PRIVATE_KEY`**.
3.  Check the public key: `cat chatwoot_deploy.pub` -> **Add this to `~/.ssh/authorized_keys` on your VPS**.

## 3. Server Environment Variables (.env)

The deployment workflow will automatically create a `.env` file on your server using the secrets you provided to GitHub. However, you might want to add more variables later.

The key variables that will be set are:
- `FRONTEND_URL`: `https://automationservice.cloud`
- `POSTGRES_PASSWORD`: (from GitHub Secret)
- `SECRET_KEY_BASE`: (from GitHub Secret)
- `RAILS_ENV`: `production`
- `NODE_ENV`: `production`

Refer to the `.env.example` file in the repository for a full list of available configurations (e.g., Email (SMTP), Object Storage (S3), Social Login).
