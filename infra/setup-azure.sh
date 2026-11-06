#!/usr/bin/env bash
# One-time Azure bootstrap. Run in Azure Cloud Shell (bash) or any shell with `az login` done.
#   GH_REPO=<github-user>/<repo> ./infra/setup-azure.sh
set -euo pipefail

RG="${RG:-rg-javaapp-devops}"
LOCATION="${LOCATION:-centralindia}"     # change if your subscription restricts regions
AKS="${AKS:-aks-javaapp}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"   # pick a size your subscription/region allows
GH_REPO="${GH_REPO:?set GH_REPO=owner/repo}"
APP_NAME="${APP_NAME:-gh-oidc-javaapp}"

echo "== Registering providers =="
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait

echo "== Resource group =="
az group create -n "$RG" -l "$LOCATION" -o table

echo "== AKS cluster (takes ~5-10 min) =="
az aks create -g "$RG" -n "$AKS" \
  --node-count 2 --node-vm-size "$NODE_SIZE" \
  --generate-ssh-keys -o table

echo "== Entra app + federated credential for GitHub OIDC =="
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
az ad sp create --id "$APP_ID" -o none
SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG" -o none

az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"github-main\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GH_REPO}:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" -o none

cat <<OUT

========= Add these in GitHub: Settings > Secrets and variables > Actions =========
Secrets:
  AZURE_CLIENT_ID        = $APP_ID
  AZURE_TENANT_ID        = $TENANT_ID
  AZURE_SUBSCRIPTION_ID  = $SUB_ID
Variables (optional, defaults already match):
  AKS_RESOURCE_GROUP     = $RG
  AKS_CLUSTER_NAME       = $AKS
=====================================================================================
OUT
