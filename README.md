
# India Engineering Workshop
This repository aims to help the developer community become familiar with the HashiStack. The workshop is structured into several phases, each introducing a HashiCorp product designed to address specific challenges in distributed systems. These phases are organized sequentially within the repository, with each phase contained in its own folder. Every phase includes a README.md file that outlines the problem being addressed and highlights the remaining challenges to be tackled in subsequent phases.

The primary goal of this workshop is to equip developers with the knowledge of when and how to effectively use these tools.

## Prerequisites

1. **AWS Sandbox account**

    If you don't have it already, request it using Doormat. `Accounts`>`AWS`>`Individual Sandbox Account`

1. **Export AWS Credentials**

    Keep the AWS credentials handy for this exercise. You can get one from homepage of doormat.
    
    :books: Since the tokens are short lived and IP bound, it is recommnded to get it during the workshop. 
   
2. **HCP Service Pricipal**:

   **Steps to Create an HCP Service Principal at the Project Level**

    1. Access the HCP Portal
    - Go to the [HashiCorp Cloud Platform (HCP) portal](https://portal.cloud.hashicorp.com/).
    - If you don’t already have an account:
    - Click on **Sign Up** and follow the instructions to create an account.
    - Verify your email address and log in to the portal.

    2. Select Your Organization and Project
    - Once logged in, select your **Organization** from the dropdown menu at the top-left of the portal.
    - Navigate to the **Projects** tab and select the project where you want to create the Service Principal.

    3. Open the Service Principals Section
    - In the project view, find and open the **Access control (IAM)** tab.
    - Select the tab `Service principals`.      
    - Create a new Service Principal using blue button on top right `+ Create service principal`.
    - Fill the form `Service principal name`= `workshop`,  `Select service`= `Project` and `Select role`= `Contributor`
    - Submit the form by clickig the blue button `Create service principal`

    4. Create keys
    - Select the SP `workshop` if not already selected.
    - Select the `Keys` tab and create a new one.
    - Save the `Client-ID` and `Client-Secret` along with `Org-ID` and `Project-ID`

3. **Bash Terminal**:
   - A terminal with Bash support to execute the setup script.

4. **Terraform, Packer and other CLI**

    - The activity has dependency on below CLI tools, make sure you should have one installed.
    ```bash
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    brew install hashicorp/tap/packer
    brew install jq
    ```
5. **DockerHub account**
    - Ensure you are able to authorize yourself to dockerhub using CLI

    ```bash
    docker login
    ```
    Make sure you recieve this message `Login Succeeded`

---
