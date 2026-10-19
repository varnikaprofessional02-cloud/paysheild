// PayShield AI - Azure resources. Shared inference for all companies (no per-company servers).
// az deployment group create -g <rg> -f main.bicep -p env=dev image=<registry>/times-payshield-ai:dev-latest ...
param location string = resourceGroup().location
param env string
param image string
param serviceBusNamespace string          // existing namespace (times-storefront-<env>)
param keyVaultName string                 // existing key vault
param postgresHost string
param tenantStoreDatabase string
param keycloakAuthority string
param entraTenantId string
param allowedAppIds array
param openAiAccountName string = ''       // existing Azure OpenAI account; empty = assistant LLM disabled
param openAiDeployment string = ''

var name = 'payshield-${env}'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-id'
  location: location
}

resource logs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${name}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' }, retentionInDays: 30 }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-ai'
  location: location
  kind: 'web'
  properties: { Application_Type: 'web', WorkspaceResourceId: logs.id }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: replace('${name}models', '-', '')
  location: location
  sku: { name: 'Standard_ZRS' }
  kind: 'StorageV2'
  properties: { allowBlobPublicAccess: false, minimumTlsVersion: 'TLS1_2', allowSharedKeyAccess: false }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storage.name}/default/payshield-models'
  properties: { publicAccess: 'None' }
}

resource sb 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = { name: serviceBusNamespace }

resource analysisQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: sb
  name: 'payshield-analysis-requested'
  properties: { maxDeliveryCount: 5, lockDuration: 'PT5M', deadLetteringOnMessageExpiration: true, requiresDuplicateDetection: true }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: keyVaultName }

// role assignments: least privilege for the shared identity
var roles = {
  blobContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  sbReceiver: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  sbSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  kvSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  openAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
}

resource blobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, identity.id, roles.blobContributor)
  scope: storage
  properties: { principalId: identity.properties.principalId, principalType: 'ServicePrincipal',
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.blobContributor) }
}

resource sbReceive 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(analysisQueue.id, identity.id, roles.sbReceiver)
  scope: analysisQueue
  properties: { principalId: identity.properties.principalId, principalType: 'ServicePrincipal',
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.sbReceiver) }
}

resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, identity.id, roles.kvSecretsUser)
  scope: kv
  properties: { principalId: identity.properties.principalId, principalType: 'ServicePrincipal',
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.kvSecretsUser) }
}

resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = if (!empty(openAiAccountName)) {
  name: openAiAccountName
}

resource openAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(openAiAccountName)) {
  name: guid(openAiAccountName, identity.id, roles.openAiUser)
  scope: openAi
  properties: { principalId: identity.properties.principalId, principalType: 'ServicePrincipal',
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.openAiUser) }
}

resource caEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${name}-env'
  location: location
  properties: {
    appLogsConfiguration: { destination: 'log-analytics', logAnalyticsConfiguration: {
      customerId: logs.properties.customerId, sharedKey: logs.listKeys().primarySharedKey } }
  }
}

var commonEnv = [
  { name: 'PAYSHIELD_ENVIRONMENT', value: env == 'prod' ? 'production' : env }
  { name: 'AZURE_CLIENT_ID', value: identity.properties.clientId }
  { name: 'PAYSHIELD_DB__HOST', value: postgresHost }
  { name: 'PAYSHIELD_DB__USERNAME', value: '${name}-id' }
  { name: 'PAYSHIELD_DB__USE_ENTRA_AUTH', value: 'true' }
  { name: 'PAYSHIELD_DB__TENANT_STORE_DATABASE', value: tenantStoreDatabase }
  { name: 'PAYSHIELD_KEYCLOAK__AUTHORITY', value: keycloakAuthority }
  { name: 'PAYSHIELD_SERVICE_AUTH__ENTRA_TENANT_ID', value: entraTenantId }
  { name: 'PAYSHIELD_SERVICE_AUTH__ENTRA_AUDIENCE', value: 'api://payshield-ai' }
  { name: 'PAYSHIELD_SERVICE_AUTH__ALLOWED_APP_IDS', value: string(allowedAppIds) }
  { name: 'PAYSHIELD_STORAGE__BACKEND', value: 'azure_blob' }
  { name: 'PAYSHIELD_STORAGE__BLOB_ACCOUNT_URL', value: storage.properties.primaryEndpoints.blob }
  { name: 'PAYSHIELD_MESSAGING__SERVICEBUS_FULLY_QUALIFIED_NAMESPACE', value: '${serviceBusNamespace}.servicebus.windows.net' }
  { name: 'PAYSHIELD_LLM__PROVIDER', value: empty(openAiAccountName) ? 'disabled' : 'azure_openai' }
  { name: 'PAYSHIELD_LLM__AZURE_ENDPOINT', value: empty(openAiAccountName) ? '' : 'https://${openAiAccountName}.openai.azure.com' }
  { name: 'PAYSHIELD_LLM__AZURE_DEPLOYMENT', value: openAiDeployment }
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
]

resource api 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${name}-api'
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
  properties: {
    managedEnvironmentId: caEnv.id
    configuration: { ingress: { external: false, targetPort: 8080, transport: 'http' } }
    template: {
      containers: [ {
        name: 'api'
        image: image
        resources: { cpu: json('1.0'), memory: '2Gi' }
        env: commonEnv
        probes: [
          { type: 'Liveness', httpGet: { path: '/api/v1/health/live', port: 8080 } }
          { type: 'Readiness', httpGet: { path: '/api/v1/health/ready', port: 8080 } }
        ]
      } ]
      scale: { minReplicas: 1, maxReplicas: 4 }
    }
  }
}

resource worker 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${name}-worker'
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identity.id}': {} } }
  properties: {
    managedEnvironmentId: caEnv.id
    template: {
      containers: [ {
        name: 'worker'
        image: image
        command: [ 'python', '-m', 'app.messaging.worker' ]
        resources: { cpu: json('1.0'), memory: '2Gi' }
        env: commonEnv
      } ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules: [ { name: 'analysis-queue', custom: { type: 'azure-servicebus', identity: identity.id,
          metadata: { queueName: 'payshield-analysis-requested', namespace: serviceBusNamespace, messageCount: '5' } } } ]
      }
    }
  }
}

output apiFqdn string = api.properties.configuration.ingress.fqdn
output identityClientId string = identity.properties.clientId
