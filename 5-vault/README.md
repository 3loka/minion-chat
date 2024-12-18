
# Part 5: Vault Integration

In this part, we integrate HashiCorp Vault to manage secrets securely. A good use case for Vault in the context of HelloService and ResponseService is dynamic database credentials. Vault will:

1. Generate dynamic credentials for a hypothetical database.
2. Provide these credentials securely to HelloService and ResponseService.
3. Auto-rotate automatically

---

## Use Case

**Scenario**:

- HelloService and ResponseService need access to a database (e.g., PostgreSQL) for storing and retrieving messages.
- Instead of hardcoding database credentials, credentials are stored in Vault.

---

## Steps for Vault Integration

### 1. Add Vault Deployment

Update the Terraform configuration to deploy Vault on an EC2 instance alongside Consul for the storage backend.

---

### 2. Vault Setup

**Initialize Vault and configure a PostgreSQL Secrets Engine for dynamic credentials.**

#### Commands to Run

SSH into the Vault instance and execute the following commands:

```bash
# Enable the database secrets engine
vault secrets enable database

# Configure the PostgreSQL connection
vault write database/config/my-postgres-database \
    plugin_name=postgresql-database-plugin \
    allowed_roles="my-role" \
    connection_url="postgresql://{{username}}:{{password}}@<db_host>:5432/postgres?sslmode=disable" \
    username="admin" \
    password="password"

# Create a role for dynamic credentials
vault write database/roles/my-role \
    db_name=my-postgres-database \
    creation_statements="CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1m"
```

---

### 3. Update HelloService and ResponseService

Modify the services to request credentials from Vault dynamically. Update the `main.go` files for each service to fetch credentials and use them to connect to the database.

---

## Demo Steps

### 1. Deploy the updated Terraform configuration for Vault:
```bash
terraform apply
```

### 2. Initialize Vault and enable the database secrets engine:
- SSH into the Vault instance.
- Run the commands to configure the secrets engine and roles.

### 3. Set the Vault environment variables in both HelloService and ResponseService:
```bash
export VAULT_ADDR=http://<vault-instance-public-ip>:8200
export VAULT_TOKEN=root
```

### 4. Test HelloService and ResponseService:

**Test HelloService**:
```bash
curl http://<hello_service_public_ip>:5000/hello_vault
```

**Test ResponseService**:
```bash
curl http://<response_service_public_ip>:5001/response_vault
```

### 5. Observe the dynamically generated database credentials in the response.

---

## Benefits of Vault Integration

- **Dynamic Credentials**: Credentials are generated on-demand and have a short lifespan.
- **Centralized Secrets Management**: Vault handles secret distribution securely.
- **Automatic Rotation**: No manual credential rotation is needed.

---
