# 3 - Environments and Secrets
In this lab you will use environments and secrets.
> Duration: 10-15 minutes

References:
- [Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Accessing your secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#accessing-your-secrets)

## 3.1 Create new encrypted secrets

1. Follow the guide to create a new environment called `UAT`, add a reviewer and an environment variable.
    - [Creating an environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#creating-an-environment)
    - [Add required reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers)
    - [Create an encrypted secret in the environment](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-an-environment) called `MY_ENV_SECRET`.
2. Follow the guide to create a new repository secret called `MY_REPO_SECRET`
    - [Creating encrypted secrets for a repository](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository)
4. Open the workflow file [environments-secrets.yml](/.github/workflows/environments-secrets.yml)
5. Edit the file and copy the following YAML content as a first job (after the `jobs:` line):
```YAML

  use-secrets:
    name: Use secrets
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    steps:
      - name: Hello world action with secrets
        uses: actions/hello-world-javascript-action@main
        with: # Set the secret as an input
          who-to-greet: ${{ secrets.MY_REPO_SECRET }}
        env: # Or as an environment variable
          super_secret: ${{ secrets.MY_REPO_SECRET }}
      - name: Echo secret is redacted in the logs
        run: |
          echo Env secret is ${{ secrets.MY_REPO_SECRET }}
          echo Warning: GitHub automatically redacts secrets printed to the log, 
          echo          but you should avoid printing secrets to the log intentionally.
          echo ${{ secrets.MY_REPO_SECRET }} | sed 's/./& /g'
```
6. Update the workflow to also run on push and pull_request events
```YAML
on:
  push:
     branches: [main]
  pull_request:
     branches: [main]
  workflow_dispatch:    
```
7. Commit the changes into the `main` branch
8. Go to `Actions` and see the details of your running workflow


## 3.2 Add a new workflow job to deploy to UAT environment

1. Open the workflow file [environments-secrets.yml](/.github/workflows/environments-secrets.yml)
2. Edit the file and copy the following YAML content between the test and prod jobs (before the `use-environment-prod:` line):
```YAML

  use-environment-uat:
    name: Use UAT environment
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    needs: use-environment-test

    environment:
      name: UAT
      url: 'https://uat.github.com'
    
    steps:
      - name: Step that uses the UAT environment
        run: echo "Deployment to UAT..."
        env: 
          env_secret: ${{ secrets.MY_ENV_SECRET }}

```
7. Inside the `use-environment-prod` job, replace `needs: use-environment-test` with:
```YAML
    needs: use-environment-uat
```
8. Commit the changes into the `main` branch
9. Go to `Actions` and see the details of your running workflow
10. Review your deployment and approve the pending UAT job
    - [Reviewing deployments](https://docs.github.com/en/actions/managing-workflow-runs/reviewing-deployments)
11. Go to `Settings` > `Environments` and update the `PROD` environment created to protect it with approvals (same as UAT)

## (Advanced) 3.3 GitHub App + Rulesets for CI/CD Automation

> Prerequisites:
> - GitHub account with **admin access** to a repository
> - A repository where you can configure branch protection (or create a new test repo)
> - An existing workflow that needs to commit and push changes (or willingness to create one)

### The Problem

A common CI/CD challenge: your workflow builds a Docker image and needs to update a deployment manifest with the new image tag, then commit that change back to `main`. But with branch protection enabled, the push fails:

```text
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: Changes must be made through a pull request.
```

The `github-actions[bot]` user is not authorized to push directly to protected branches. This blocks GitOps patterns like:
- Updating deployment manifests with new image tags
- Auto-incrementing version numbers
- Generating changelogs
- Synchronizing configuration files

### The Solution: GitHub App + Repository Rulesets

Instead of using a Personal Access Token (PAT)—which is tied to a specific user and is an antipattern for production—create a dedicated **GitHub App** for CI/CD automation:

| Aspect | PAT (Antipattern) | GitHub App (Recommended) |
| ------ | ------------------ | ------------------------ |
| Identity | Tied to user account | Independent entity |
| Permissions | Often overly broad | Scoped to specific needs |
| Audit trail | Shows as user | Shows as App |
| What if user leaves? | Token becomes invalid | App continues working |

**Why Rulesets instead of legacy Branch Protection?**

Repository Rulesets (the modern replacement for branch protection rules) properly support GitHub App bypass. Legacy branch protection does not reliably support this pattern.

### Steps

1. **Create a GitHub App** with minimal permissions
   - Go to your GitHub Settings → Developer settings → GitHub Apps → New GitHub App
   - [Creating GitHub Apps documentation](https://docs.github.com/en/apps/creating-github-apps)
   - Set these **Repository permissions**:

   | Permission | Access Level   |
   | ---------- | -------------- |
   | Contents   | Read & Write   |

   - Generate and download a **private key** (you'll need this)
   - Note the **App ID** from the app's settings page

2. **Install the App on your repository**
   - From your App's settings, click "Install App"
   - Select the repository where you need CI/CD automation
   - [Installing GitHub Apps documentation](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app)

3. **Create a Repository Ruleset** requiring PRs for main
   - Go to your repository → Settings → Rules → Rulesets → New ruleset → New branch ruleset
   - [Creating rulesets documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
   - Target the `main` branch (or `default` branch)
   - Enable "Require a pull request before merging"

4. **Add your GitHub App to the Bypass list**
   - In the same ruleset, find "Bypass list"
   - Add your GitHub App
   - Set bypass type to **"Exempt"** (silently skips enforcement—ideal for automation)
   - [About rulesets and bypass](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

   > **Note:** "Exempt" bypass (available since September 2025) silently skips enforcement. Standard "Bypass" generates audit signals and is better for "break glass" scenarios.

5. **Store App credentials as repository secrets**
   - Go to Settings → Secrets and variables → Actions
   - Create a **variable** `CI_BOT_APP_ID` with your App ID
   - Create a **secret** `CI_BOT_PRIVATE_KEY` with your private key contents

6. **Update the workflow** to use the App token
   - Open the workflow file [github-app-manifest-update.yml](/.github/workflows/github-app-manifest-update.yml)
   - Replace the entire contents with:

```yaml
name: 03-2. GitHub App Manifest Update

on:
  workflow_dispatch:

jobs:
  update-manifest:
    name: Update Manifest (GitHub App)
    runs-on: ubuntu-latest
    steps:
      # 1. Generate GitHub App token
      - uses: actions/create-github-app-token@v2
        id: app-token
        with:
          app-id: ${{ vars.CI_BOT_APP_ID }}
          private-key: ${{ secrets.CI_BOT_PRIVATE_KEY }}

      # 2. Checkout with App token (enables push as App identity)
      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}

      # 3. Make changes and push
      - name: Update manifest and push
        run: |
          echo "image: myapp:${{ github.sha }}" > manifest.yaml
          git config user.name "ci-bot[bot]"
          git config user.email "ci-bot[bot]@users.noreply.github.com"
          git add manifest.yaml
          git commit -m "Update manifest to ${{ github.sha }}"
          git push
```

- [actions/create-github-app-token documentation](https://github.com/actions/create-github-app-token)

7. **Commit the changes** into the `main` branch

8. **Test the workflow**
   - Go to `Actions` and select "03-2. GitHub App Manifest Update"
   - Click "Run workflow" → "Run workflow"
   - Verify the commit appears on `main` with your App as the author
   - The push succeeds because your App is in the ruleset's bypass list

9. **Cleanup**
   - Settings → GitHub Apps → Uninstall the app from the repository
   - Settings → Rules → Rulesets → Delete the ruleset
   - Settings → Secrets → Delete `CI_BOT_PRIVATE_KEY` and `CI_BOT_APP_ID`

## 3.4 Final
<details>
  <summary>environments-secrets.yml</summary>
  
```YAML
name: 03-1. Environments and Secrets

on:
  push:
     branches: [main]
  pull_request:
     branches: [main]
  workflow_dispatch:    
      
# Limit the permissions of the GITHUB_TOKEN
permissions:
  contents: read
  actions: read
  deployments: read

env:
  PROD_URL: 'https://github.com'
  DOCS_URL: 'https://docs.github.com'
  DEV_URL:  'https://docs.github.com/en/developers'

jobs:
  use-secrets:
    name: Use secrets
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    steps:
      - name: Hello world action with secrets
        uses: actions/hello-world-javascript-action@main
        with: # Set the secret as an input
          who-to-greet: ${{ secrets.MY_REPO_SECRET }}
        env: # Or as an environment variable
          super_secret: ${{ secrets.MY_REPO_SECRET }}
      - name: Echo secret is redacted in the logs
        run: |
          echo Env secret is ${{ secrets.MY_REPO_SECRET }}
          echo Warning: GitHub automatically redacts secrets printed to the log, 
          echo          but you should avoid printing secrets to the log intentionally.
          echo ${{ secrets.MY_REPO_SECRET }} | sed 's/./& /g'
    
  use-environment-dev:
    name: Use DEV environment
    runs-on: ubuntu-latest
    # Use conditionals to control whether the job is triggered or skipped
    # if: ${{ github.event_name == 'pull_request' }}
    
    # An environment can be specified per job
    # If the environment cannot be found, it will be created
    environment:
      name: DEV
      url: ${{ env.DEV_URL }}
    
    steps:
      - run: echo "Run id = ${{ github.run_id }}"

      - name: Checkout
        uses: actions/checkout@v4

      - name: Step that uses the DEV environment
        run: echo "Deployment to ${{ env.URL1 }}..."

      - name: Echo env secret is redacted in the logs
        run: |
          echo Env secret is ${{ secrets.MY_ENV_SECRET }}
          echo ${{ secrets.MY_ENV_SECRET }} | sed 's/./& /g'

  use-environment-test:
    name: Use TEST environment
    runs-on: ubuntu-latest
    #if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    needs: use-environment-dev

    environment:
      name: TEST
      url: ${{ env.DOCS_URL }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Step that uses the TEST environment
        run: echo "Deployment to ${{ env.DOCS_URL }}..."
      
      # Secrets are redacted in the logs
      - name: Echo secrets are redacted in the logs
        run: |
          echo Repo secret is ${{ secrets.MY_REPO_SECRET }}
          echo Org secret is ${{ secrets.MY_ORG_SECRET }}
          echo Env secret is not accessible ${{ secrets.MY_ENV_SECRET }}

  use-environment-uat:
    name: Use UAT environment
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    needs: use-environment-test

    environment:
      name: UAT
      url: 'https://uat.github.com'
    
    steps:
      - name: Step that uses the UAT environment
        run: echo "Deployment to UAT..."
        env: 
          env_secret: ${{ secrets.MY_ENV_SECRET }}

  use-environment-prod:
    name: Use PROD environment
    runs-on: ubuntu-latest
    #if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    
    needs: use-environment-uat

    environment:
      name: PROD
      url: ${{ env.PROD_URL }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Step that uses the PROD environment
        run: echo "Deployment to ${{ env.PROD_URL }}..."
```
</details>

<details>
  <summary>github-app-manifest-update.yml</summary>

```yaml
name: 03-2. GitHub App Manifest Update

on:
  workflow_dispatch:

jobs:
  update-manifest:
    name: Update Manifest (GitHub App)
    runs-on: ubuntu-latest
    steps:
      # 1. Generate GitHub App token
      - uses: actions/create-github-app-token@v2
        id: app-token
        with:
          app-id: ${{ vars.CI_BOT_APP_ID }}
          private-key: ${{ secrets.CI_BOT_PRIVATE_KEY }}

      # 2. Checkout with App token (enables push as App identity)
      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}

      # 3. Make changes and push
      - name: Update manifest and push
        run: |
          echo "image: myapp:${{ github.sha }}" > manifest.yaml
          git config user.name "ci-bot[bot]"
          git config user.email "ci-bot[bot]@users.noreply.github.com"
          git add manifest.yaml
          git commit -m "Update manifest to ${{ github.sha }}"
          git push
```
</details>
