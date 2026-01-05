az aks get-credentials --resource-group RG-GH-ARC-QYFRL --name GH-ARC-RUNNER-QYFRL

Install Controller:

$NAMESPACE="arc-systems"
helm install arc `
    --namespace "$NAMESPACE" `
    --create-namespace `
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

Configure Scale Set:

$INSTALLATION_NAME="arc-runner-set"
$NAMESPACE="arc-runners"
$GITHUB_CONFIG_URL="https://github.com/<your_enterprise/org/repo>"
$GITHUB_PAT="<PAT>"
helm install "$INSTALLATION_NAME" `
    --namespace "$NAMESPACE" `
    --create-namespace `
    --set githubConfigUrl="$GITHUB_CONFIG_URL" `
    --set githubConfigSecret.github_token="$GITHUB_PAT" `
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

