### How to run this module

1. export DOCKER_USER and DOCKER_PASSWORD as environment variables.
2. Login to DockerHub - `docker login -u $DOCKER_USER -p $DOCKER_PASSWORD`.
3. Folders `HelloService` and `ResponseService` contain code and Dockerfile, make sure you have the linux image ready and pushed in DockerHub.
4. Once the above setup is complete, move to `terraform` folder - `cd terraform`.
5. This folder will deploy all the necessary Infra, Hashi Products and Apps for this demo.
6. Login to Doormat and copy the AWS CLI credentials. Copy them in either `~/.aws/credentials` file or just paste them in the terminal.
7. Do `terraform init`
8. Do `terraform apply -var docker_user=$DOCKER_USER -var docker_password=$DOCKER_PASSWORD`. This will deploy the following:
    - 1 Postgres Server.
    - 1 Vault Server with locally running Consul agent.
    - 1 Nomad Server and 1 Consul Server on the same EC2 instance.
    - 2 Nomad Clients with locally running Consul agent.
    - Enable Database Secret Engine for secret rotation in Vault.
    - Vault Policy for Nomad jobs to access Database Secrets.
9. The output will print all the necessary URLs to interact with the above deployment.
10. Do `terraform output vault_token` to get the token which will be used to login on Vault server.
11. Check whether Database Secret Engine is created on the Vault server via UI.
12. Check whether Nomad and Consul is up and running
13. Once everything is validated do `terraform apply -var docker_user=$DOCKER_USER -var docker_password=$DOCKER_PASSWORD -var deploy_apps=true`
14. This will deploy both HelloService and ResponseService on Nomad.
15. Validate whether both are up and running.
16. Look at the definitions of Nomad jobs for both apps, you'll see no template for HelloService while DB creds are fetched in a template in ResponseService. (The key difference)
17. HelloService - Fetches DB secrets directly by hitting Vault API to fetch secrets.
18. ResponseService - Fetches DB secrets from ENV variables, we set those ENV variables via Nomad job template. We configure Nomad server with address of Vault server and hence enable Nomad to manager secrets which is a much better way
     - You don't have to build the app binary again and release it in case either the Vault path changes OR the secret provider changes, you just need to update the Nomad job and restart.
     - You don't have to worry about writing login to fetch new credentials once the secret has rotated and new connections start failing, Nomad listens to changes and rotates it for you.
     - Refresh Endpoints for both HelloService and ResponseService, you will see every refresh gets a new credential in HelloService because whenever there is an API call to fetch the secret, the credentials are re-created leading to uncessary wastage.
     - While ResponseService's credentials are rotated only after TTL of 1 minute has expired. Much better solution.


### What are Vault Seal Keys?
When a Vault server first starts, it starts in a sealed state. In this state:

1. The data is encrypted
2. No operations can be performed
3. No data can be read or written
4. The encryption key needed to decrypt the data is also encrypted

The process of "unsealing" involves:

1. Reconstructing the master key that is used to decrypt the encryption key
2. The master key is split into several shares using Shamir's Secret Sharing algorithm
3. A certain threshold of these shares must be provided to reconstruct the master key

For example, if you have 5 key shares with a threshold of 3:

1. You need any 3 of the 5 shares to unseal Vault
2. This means no single person has complete control
3. Even if 2 shares are compromised, Vault remains secure

Common scenarios for sealing/unsealing:

1. Server startup: Vault starts sealed
2. Maintenance: You might seal Vault for maintenance
3. Security breach: Vault can be manually sealed to protect data
4. Power outage: Vault seals itself if the server restarts


### How does Database Secret Engine work in Vault?
1. It needs a running Postgres instance along with its root credentials.
2. It connects to the Postgres instance and whenever there is request of credentials, it creates a random username and password.
3. It then adds this generated username and password to the valid set of users in Postgres.
4. Returns the username and password as a response to the client.
5. Sets a TTL, on expiry of which it removes the corresponding username and password from active Postgres users.


curl --location 'http://98.84.123.161:8200/v1/database/creds/app-role' \
--header 'X-Vault-Token: iXKDQd2N1D'

{
"request_id": "f97db4d5-0781-7aea-7d02-bc897dd41be1",
"lease_id": "database/creds/app-role/aki3Ts36VeCawmIa7x9bDhbs",
"renewable": true,
"lease_duration": 60,
"data": {
"password": "SnLuGIHyz-chiEyypQM7",
"username": "v-token-app-role-oAJrl3rotx6gzqORQ7LJ-1734442960"
},
"wrap_info": null,
"warnings": null,
"auth": null
}
