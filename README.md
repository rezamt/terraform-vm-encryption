### Encrypting Virtual Machines Disk in Azure using Terraform and Azure Resource Manager

The following TF scripts shows how to use Terraform `azurerm_template_deployment` in order to run MS Azure RM Template
and get the Disks encrypted.

I have tried to do this using VM Extensions but no chance . Always returns success but the Encryption is not there.

I am adding the sample code here if someone can fix it.


Microsoft Examples

- [Enable encryption on a running Linux VM](https://github.com/Azure/azure-quickstart-templates/tree/master/201-encrypt-running-linux-vm)
- [Enable encryption on a running Windows VM](https://github.com/Azure/azure-quickstart-templates/tree/master/201-encrypt-running-windows-vm)