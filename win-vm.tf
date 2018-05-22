provider "azurerm" {
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  subscription_id = "${var.subscription_id}"
}

resource "azurerm_resource_group" "test" {
  location = "${var.location}"
  name     = "${var.resourceGroupName}"
}

resource "azurerm_storage_account" "test" {
  name                     = "storageaccountname"
  resource_group_name      = "${azurerm_resource_group.test.name}"
  location                 = "${azurerm_resource_group.test.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_network_security_group" "test" {
  name                = "acceptanceTestSecurityGroup1"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"

  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "RDP"
    priority = 100
    protocol = "TCP"
  }

  security_rule {
    access = "Deny"
    direction = "Inbound"
    name = "Deny_Others"
    priority = 4096
    protocol = "*"
  }
}


resource "azurerm_virtual_network" "test" {
  name                = "vnet-test"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
}

resource "azurerm_subnet" "test" {
  name                 = "default"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "test" {
  name                = "inc-test"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_virtual_machine" "test" {
  name = "test"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location = "${azurerm_resource_group.test.location}"


  network_interface_ids = [
    "${azurerm_network_interface.test.id}"]

  vm_size = "Standard_DS2"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2016-Datacenter"
    version = "latest"
  }

  storage_os_disk {
    name = "disk-os"
    caching = "ReadWrite"
    create_option = "FromImage"
    os_type = "Windows"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name = "test"
    admin_username = "admin"     # change me
    admin_password = "!Pa$$W0RD" # change me
  }

  storage_data_disk {
    name = "disk-data"
    managed_disk_type = "Premium_LRS"
    create_option = "Empty"
    lun = 0
    disk_size_gb = "1"
  }

  os_profile_windows_config {
    winrm {
      protocol = "http"
    }
    provision_vm_agent = true
    enable_automatic_upgrades = true
  }

  boot_diagnostics {
    enabled = true
    storage_uri = "${azurerm_storage_account.test.primary_blob_endpoint}"
  }
}

resource "azurerm_virtual_machine_extension" "vm-test-extension" {

  name = "vm-test_ext"
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.7"
  settings = "{\"fileUris\":[\"${var.volumemanager_file_url}\"], \"commandToExecute\": \"powershell -ExecutionPolicy Unrestricted -file ManageVolumeDisk.ps1\"}"
  location = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  virtual_machine_name = "${azurerm_virtual_machine.test.name}"
}

resource "azurerm_template_deployment" "windows_vm" {
  provider            = "azurerm.svc"
  name                = "encrypt-disks"
  resource_group_name = "${azurerm_resource_group.test.name}"
  deployment_mode     = "Incremental"
  depends_on          = ["azurerm_virtual_machine.vm-test"]

  template_body = <<DEPLOY
{
	"$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"vmName": {
			"type": "string",
			"defaultValue": "${azurerm_virtual_machine.test.name}",
			"metadata": {
				"description": "Name of the virtual machine"
			}
		},
		"aadClientID": {
			"type": "string",
			"defaultValue": "${var.aadClientID}",
			"metadata": {
				"description": "Client ID of AAD app which has permissions to KeyVault"
			}
		},
		"aadClientSecret": {
			"type": "securestring",
			"defaultValue": "${var.aadClientSecret}",
			"metadata": {
				"description": "Client Secret of AAD app which has permissions to KeyVault"
			}
		},
		"keyVaultName": {
			"type": "string",
			"defaultValue": "${var.keyVaultName}",
			"metadata": {
				"description": "Name of the KeyVault to place the volume encryption key"
			}
		},
		"keyVaultResourceGroup": {
			"type": "string",
			"defaultValue": "${azurerm_resource_group.test.name}",
			"metadata": {
				"description": "Resource group of the KeyVault"
			}
		},
		"useExistingKek": {
			"type": "string",
			"defaultValue": "${var.useExistingKek}",
			"allowedValues": ["nokek", "kek"],
			"metadata": {
				"description": "Select kek if the secret should be encrypted with a key encryption key and pass explicit keyEncryptionKeyURL. For nokek, you can keep keyEncryptionKeyURL empty."
			}
		},
		"keyEncryptionKeyURL": {
			"type": "string",
			"defaultValue": "${var.keyEncryptionKeyURL}",
			"metadata": {
				"description": "URL of the KeyEncryptionKey used to encrypt the volume encryption key"
			}
		},
		"volumeType": {
			"type": "string",
			"defaultValue": "${var.volumeType}",
			"allowedValues": ["OS", "Data", "All"],
			"metadata": {
				"description": "Type of the volume OS or Data to perform encryption operation"
			}
		},
		"sequenceVersion": {
			"type": "string",
			"defaultValue": "1.0",
			"metadata": {
				"description": "Pass in an unique value like a GUID everytime the operation needs to be force run"
			}
		},
		"location": {
			"type": "string",
			"defaultValue": "${azurerm_resource_group.test.location}",
			"metadata": {
				"description": "Location for all resources."
			}
		}
	},
	"variables": {
		"extensionName": "AzureDiskEncryption",
		"extensionVersion": "1.1",
		"encryptionOperation": "EnableEncryption",
		"keyEncryptionAlgorithm": "RSA-OAEP",
		"updateVmUrl": "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-encrypt-running-windows-vm/updatevm-${var.useExistingKek}.json",
		"keyVaultURL": "https://${var.keyVaultName}.vault.azure.net/",
		"keyVaultResourceID": "${var.keyVaultResourceID}"
	},
	"resources": [{
			"type": "Microsoft.Compute/virtualMachines/extensions",
			"name": "[concat(parameters('vmName'),'/', variables('extensionName'))]",
			"apiVersion": "2016-04-30-preview",
			"location": "[parameters('location')]",
			"properties": {
				"publisher": "Microsoft.Azure.Security",
				"type": "AzureDiskEncryption",
				"typeHandlerVersion": "[variables('extensionVersion')]",
				"autoUpgradeMinorVersion": true,
				"forceUpdateTag": "[parameters('sequenceVersion')]",
				"settings": {
					"AADClientID": "[parameters('aadClientID')]",
					"KeyVaultURL": "[variables('keyVaultURL')]",
					"KeyEncryptionKeyURL": "[parameters('keyEncryptionKeyURL')]",
					"KeyEncryptionAlgorithm": "[variables('keyEncryptionAlgorithm')]",
					"VolumeType": "[parameters('volumeType')]",
					"EncryptionOperation": "[variables('encryptionOperation')]"
				},
				"protectedSettings": {
					"AADClientSecret": "[parameters('aadClientSecret')]"
				}
			}
		},
		{
			"name": "updatevm",
			"type": "Microsoft.Resources/deployments",
			"apiVersion": "2015-01-01",
			"dependsOn": [
				"[resourceId('Microsoft.Compute/virtualMachines/extensions',  parameters('vmName'), variables('extensionName'))]"
			],
			"properties": {
				"mode": "Incremental",
				"templateLink": {
					"uri": "[variables('updateVmUrl')]",
					"contentVersion": "1.0.0.0"
				},
				"parameters": {
					"vmName": {
						"value": "[parameters('vmName')]"
					},
					"keyVaultResourceID": {
						"value": "[variables('keyVaultResourceID')]"
					},
					"keyVaultSecretUrl": {
						"value": "[reference(resourceId('Microsoft.Compute/virtualMachines/extensions',  parameters('vmName'), variables('extensionName'))).instanceView.statuses[0].message]"
					},
					"keyEncryptionKeyURL": {
						"value": "[parameters('keyEncryptionKeyURL')]"
					}
				}
			}
		}
	],
	"outputs": {
		"BitLockerKey": {
			"type": "string",
			"value": "[reference(resourceId('Microsoft.Compute/virtualMachines/extensions',  parameters('vmName'), variables('extensionName'))).instanceView.statuses[0].message]"
		}
	}
}
DEPLOY
}
