# 6 - Self-hosted runners
In this lab you will create and use your self-hosted runners.
> Duration: 10-15 minutes

References:
- [Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners)
- [Using self-hosted runners in a workflow](https://docs.github.com/en/actions/hosting-your-own-runners/using-self-hosted-runners-in-a-workflow)
- [Using labels with self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners)

## Understanding Self-Hosted Runner Labels

### Default Labels
When you register a self-hosted runner, GitHub automatically assigns these **default labels**:
- `self-hosted` - Identifies the runner as self-hosted (not GitHub-hosted)
- **Operating System**: `linux`, `windows`, or `macOS` - Based on the runner's OS
- **Architecture**: `x64`, `ARM`, or `ARM64` - Based on the runner's hardware

### Custom Labels
You can add **custom labels** during runner registration to further identify your runners. For example, `self-hosted-linux` or `gpu` are custom labels you define.

### How Label Matching Works
**Important:** When you specify multiple labels in `runs-on`, the runner must have **ALL** of them. Labels operate cumulatively (AND logic), not as options (OR logic).

For example:
```yaml
runs-on: [self-hosted, linux, x64, self-hosted-linux]
```
This means the job will **only** run on a runner that has **all four labels**:
- `self-hosted` ✓ (default)
- `linux` ✓ (default)
- `x64` ✓ (default)
- `self-hosted-linux` ✓ (**custom** - must be added during registration)

If your runner only has the three default labels, the job will **not** match and will remain queued.

## (Optional) 6.1 Add a self-hosted runner
> Prerequisites: Access to a Cloud platform to create a runner machine

1. If you have access to an Azure subscription, follow the guide to create a Linux virtual machine
    - [Create a Linux virtual machine](https://docs.microsoft.com/en-us/learn/modules/host-build-agent/4-create-build-agent)
2. Create a new private repository `my-private-repo`
    - [Creating a new repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)
3. Follow the guide to install the agent on the runner
    - [Adding a self-hosted runner to a repository](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-a-repository)
    - **Important:** During registration, add the custom label `self-hosted-linux` (for Linux) or `self-hosted-windows` (for Windows) so your runner matches the workflow's `runs-on` requirements. You can add labels using the `--labels` flag:
      ```bash
      ./config.sh --url <REPO_URL> --token <TOKEN> --labels self-hosted-linux
      ```
4. Follow the guide to use the self-hosted runner in a workflow
    - [Using self-hosted runners in a workflow](https://docs.github.com/en/actions/hosting-your-own-runners/using-self-hosted-runners-in-a-workflow)
5. Create a new workflow `.github/workflows/self-hosted-runners.yml` in your private repository and run the workflow on the self-hosted runner

    > **Note on `runs-on` labels:** The workflow below uses `runs-on: [self-hosted, linux, x64, self-hosted-linux]`. This requires the runner to have **all four labels**:
    > - `self-hosted`, `linux`, `x64` — Default labels (assigned automatically)
    > - `self-hosted-linux` — Custom label (you must add this during runner registration)

```YAML
name: Self-Hosted Runners Hello

on:
  workflow_dispatch:
    inputs:
      name:
        description: 'What is your name?'
        required: true
        default: 'World'
        
jobs:
  say_hello_linux:
    name: Say Hello from Linux Self-Hosted Runner
    runs-on: [self-hosted, linux, x64, self-hosted-linux]
    steps:
      - name: Say hello from self-hosted linux runner
        run: |
          echo "Hello ${{ github.event.inputs.name }}, from self-hosted linux runner!"

  say_hello_windows:
    name: Say Hello from Windows Self-Hosted Runner
    runs-on: [self-hosted, windows, x64, self-hosted-windows]
    needs: say_hello_linux
    steps:
      - name: Say hello from self-hosted windows runner
        run: |
          echo "Hello ${{ github.event.inputs.name }}, from self-hosted windows runner!"
```
6. Clean up your runner resources if not needed

## (Optional) 6.2 Private Networking for GitHub-Hosted Runners

This section covers configuring GitHub-hosted runners with Azure VNET integration, enabling runners to access private resources without self-hosting.

### What Private Networking Provides

- **Private resource access**: GitHub-hosted runners connect to your Azure VNET, accessing internal databases, APIs, and on-premises resources via ExpressRoute or VPN
- **Network policy control**: Your VNET's Network Security Groups (NSGs) apply to runners, controlling outbound traffic
- **GitHub-managed infrastructure**: Get enterprise networking capabilities without maintaining runner infrastructure

### Why This Matters

- **Security & compliance**: Meet data residency and network isolation requirements
- **Internal CI/CD access**: Connect pipelines to private artifact registries, databases, and APIs
- **Simplified operations**: GitHub manages runner infrastructure while you control network policies

> **Prerequisites:**
>
> - GitHub Enterprise Cloud plan (required)
> - Azure subscription with **Subscription Contributor** and **Network Contributor** roles
>   - [Assign Azure roles using the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal)
>   - [Azure built-in roles reference](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
> - Azure CLI installed and authenticated
> - GitHub CLI (`gh`) installed and authenticated

### Configuration Steps

Setting up private networking involves Azure infrastructure deployment, GitHub configuration, and workflow setup.

**References:**

- [Configuring private networking for GitHub-hosted runners in your organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization)
- [About Azure private networking for GitHub-hosted runners in your organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization)
- [Network details for GHE.com](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/network-details-for-ghecom) (required for GitHub Enterprise Cloud environments)

#### Step 1: Get your organization's database ID

Run the following GitHub CLI command to retrieve your organization's database ID:

```bash
gh api graphql -f query='
  query($login: String!) {
    organization(login: $login) {
      login
      databaseId
    }
  }' -f login='YOUR_ORG_NAME'
```

Save the `databaseId` value from the output—you'll need it for the deployment script.

#### Step 2: Configure and run the Azure deployment script

The deployment script and Bicep template are located in `.github/bicep/`. The script automates:

- Resource group creation
- Network Security Group (NSG) with required GitHub IP ranges
- Virtual network and subnet creation
- Subnet delegation to `GitHub.Network/networkSettings`
- Network settings resource creation

Edit `.github/bicep/deployment_script.sh` and configure these variables:

| Variable | Description | Example |
| -------- | ----------- | ------- |
| `AZURE_LOCATION` | Azure region for resources | `westus2` |
| `SUBSCRIPTION_ID` | Your Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `RESOURCE_GROUP_NAME` | Name for new resource group | `github-runners-rg` |
| `VNET_NAME` | Name for the virtual network | `GitHubRunnersVNET` |
| `SUBNET_NAME` | Name for the subnet | `github-runners-subnet` |
| `NSG_NAME` | Name for the network security group | `github-runners-nsg` |
| `NETWORK_SETTINGS_RESOURCE_NAME` | Name for the network settings resource | `github-network-settings` |
| `DATABASE_ID` | Organization database ID from Step 1 | `123456789` |

> **Note:** The `ADDRESS_PREFIX` and `SUBNET_PREFIX` have sensible defaults (`10.0.0.0/16` and `10.0.0.0/24`). Adjust only if they conflict with your existing network.

Run the script:

```bash
cd .github/bicep
chmod +x deployment_script.sh
./deployment_script.sh
```

Save the `GitHubId` from the output—you'll need it for the GitHub configuration.

#### Step 3: Create the network configuration in GitHub

1. Navigate to your organization's **Settings** → **Actions** → **Hosted compute networking**
2. Click **New network configuration** → **Azure private network**
3. Enter the `GitHubId` from Step 2
4. Name your network configuration and save

#### Step 4: Create a runner group with the network configuration

1. In your organization, go to **Settings** → **Actions** → **Runner groups**
2. Click **New runner group**
3. Enter a name for your runner group (e.g., `private-network-runners`)
4. Under **Network configurations**, select the network configuration you created in Step 3
5. Under **Repository access**, choose which repositories can use this runner group
6. Click **Create group**

#### Step 5: Create a GitHub-hosted runner in the group

1. Click on your newly created runner group to open it
2. Click **New runner** → **New GitHub-hosted runner**
3. Configure the runner with these settings:
   - **Name**: Enter a descriptive name (e.g., `ubuntu-vnet-4core`). This name becomes the label you use in workflows.
   - **Image**: Select an Ubuntu or Windows image (e.g., `Ubuntu 22.04` or `Ubuntu 24.04`)
   - **Size**: Select a size with 2-64 vCPU (private networking requires larger runners)
4. Click **Create runner**

> **Important:** The runner **Name** you enter becomes the label used in your workflow's `runs-on.labels` field. For example, if you name your runner `ubuntu-vnet-4core`, you reference it as `labels: [ubuntu-vnet-4core]`.
>
> **Note:** Private networking requires larger GitHub-hosted runners. Standard runners are not supported.

#### Step 6: Create a workflow to test the private network runner

Create a new workflow file `.github/workflows/private-network-runner.yml` in your repository:

```yaml
name: 06-2. Private Network Runner Test

on:
  workflow_dispatch:
    inputs:
      message:
        description: 'Message to display'
        required: false
        default: 'Hello from private network!'

jobs:
  test-private-network:
    name: Test Private Network Connectivity
    runs-on:
      group: private-network-runners
      labels: [ubuntu-vnet-4core]
    steps:
      - uses: actions/checkout@v4
      - name: Verify private network connectivity
        run: |
          echo "${{ github.event.inputs.message }}"
          echo "Runner is connected to Azure VNET"
          # Add commands here to test connectivity to private resources
          # Example: curl http://internal-api.your-vnet.local/health
```

Update the workflow with your values:

- Replace `private-network-runners` with your runner group name from Step 4
- Replace `ubuntu-vnet-4core` with your runner name from Step 5

#### Step 7: Run and verify the workflow

1. Navigate to **Actions** → **06-2. Private Network Runner Test**
2. Click **Run workflow**
3. Verify the job runs successfully on your private network runner

> **November 2025 Update:** NICs created by the GitHub Actions service are now provisioned in a GitHub service subscription. They will not appear in your Azure portal, but networking functions identically.

#### Step 8: Clean up resources

When finished, clean up your resources:

**Azure:**

```bash
az group delete --resource-group YOUR_RESOURCE_GROUP_NAME
```

**GitHub:**

1. Delete the runner from the runner group
2. Delete the runner group
3. Delete the network configuration