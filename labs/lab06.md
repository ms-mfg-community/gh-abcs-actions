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
> - GitHub Enterprise Cloud plan (required)
> - Azure subscription with **Subscription Contributor** and **Network Contributor** roles
>   - [Assign Azure roles using the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal)
>   - [Azure built-in roles reference](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
> - Existing Azure VNET with available subnet (minimum /28 CIDR recommended)
>   - [Quickstart: Create an Azure Virtual Network](https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network)

### Configuration Steps

Setting up private networking involves Azure configuration and GitHub Enterprise settings:

1. **Register the GitHub.Network resource provider** in your Azure subscription
   - In Azure Portal: **Subscriptions** → Select your subscription → **Settings** → **Resource providers**
   - Search for `GitHub.Network` and click **Register**
   - Or via Azure CLI: `az provider register --namespace GitHub.Network`
   - [Azure resource providers and types](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types)

2. **Add a new subnet to your existing VNET** (from Lab 6.1's Azure setup)
   - In Azure Portal: **Virtual networks** → Select your VNET → **Subnets** → **+ Subnet**
   - Configure the subnet with these settings:
     | Setting | Value |
     |---------|-------|
     | **Subnet purpose** | `Default` |
     | **Name** | `github-runners` (or your preferred name) |
     | **Starting address** | Use next available in your VNET (e.g., `10.0.1.0` if `10.0.0.0` is used) |
     | **Size** | `/28` minimum (16 IPs). Use `/27` for ~30 concurrent runners |
     | **Subnet delegation** | Select `GitHub.Network/networkSettings` |
     | All other settings | Leave as defaults |
   - Click **Add**
   - [Add or change a subnet](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-subnet) | [Subnet delegation](https://learn.microsoft.com/en-us/azure/virtual-network/manage-subnet-delegation)

3. **Create a network configuration** in GitHub Enterprise settings
   - Links your Azure VNET subnet to GitHub
   - [Configuring private networking for GitHub-hosted runners](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/configuring-private-networking-for-github-hosted-runners-in-your-enterprise)

4. **Create a runner group** with the network configuration
   - Runner groups organize runners and apply network settings
   - [About private networking with GitHub-hosted runners](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/about-azure-private-networking-for-github-hosted-runners-in-your-enterprise)

5. **Use the runner group in your workflow** with the `runs-on` group syntax:

```yaml
jobs:
  build:
    runs-on:
      group: my-private-network-runner-group
      labels: [ubuntu-latest-4cores]
    steps:
      - uses: actions/checkout@v4
      - name: Access private resource
        run: |
          # This runner can now access resources in your Azure VNET
          echo "Connected to private network!"
```

> **Note:** Private networking requires larger GitHub-hosted runners (2-64 vCPU). Standard runners are not supported.

> **November 2025 Update:** NICs created by the GitHub Actions service are now provisioned in a GitHub service subscription. They will not appear in your Azure portal, but networking functions identically.

6. **Clean up** your Azure and GitHub resources when no longer needed