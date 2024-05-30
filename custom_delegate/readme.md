| Key          | Value                   |
|--------------|-------------------------|
| Category     | Platform                 |
| Name         | Custom Delegate          |
| ShortDescription | Create a custom delegate image stored in your internal container registry |


## Overview
This Terraform configuration sets up a pipeline on the Harness Platform to build and push a custom delegate image into a local repository. The pipeline includes stages to fetch the latest delegate version, build the delegate image, and perform a security scan.

