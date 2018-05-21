resource "azurerm_resource_group" "test" {
  name     = "test-vm"
  location = "australiaeast"
}

resource "azurerm_virtual_machine" "test" {
  location = ""
  name = ""
  network_interface_ids = []
  resource_group_name = ""
  "storage_os_disk" {
    create_option = ""
    name = ""
  }
  vm_size = ""
}

resource "azurerm_template_deployment" "windows_vm" {
  name = "encrypt-disks"

  resource_group_name = "${azurerm_resource_group.test.name}"
  deployment_mode     = "Incremental"
  depends_on          = ["azurerm_virtual_machine.test"]

  template_body = <<DEPLOY

{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "vmName": {
      "type": "string",
      "defaultValue" : "${azurerm_virtual_machine.test.name}
      "metadata": {
        "description": "Name of the virtual machine"
      }
    },
    "aadClientID": {
      "type": "string",
      "defaultValue": "${var.aad_client_id}",
      "metadata": {
        "description": "Client ID of AAD app which has permissions to KeyVault"
      }
    },
    "aadClientSecret": {
      "type": "securestring",
      "defaultValue": "${var.aad_client_secret}",
      "metadata": {
        "description": "Client Secret of AAD app which has permissions to KeyVault"
      }
    },
    "keyVaultName": {
      "type": "string",
      "defaultValue": "${var.key_vault_name}",
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
      "defaultValue": "${var.use_kek}",
      "allowedValues": [ "nokek", "kek" ],
      "metadata": {
        "description": "Select kek if the secret should be encrypted with a key encryption key and pass explicit keyEncryptionKeyURL. For nokek, you can keep keyEncryptionKeyURL empty."
      }
    },
    "keyEncryptionKeyURL": {
      "type": "string",
      "defaultValue": "${var.key_encryption_key_url}",
      "metadata": {
        "description": "URL of the KeyEncryptionKey used to encrypt the volume encryption key"
      }
    },
    "volumeType": {
      "type": "string",
      "defaultValue": "${var.volume_type}",
      "allowedValues": [ "OS", "Data", "All" ],
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
      "defaultValue": "[resourceGroup().location]",
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
    "updateVmUrl": "[concat('https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-encrypt-running-windows-vm/updatevm-',parameters('useExistingKek'),'.json')]",
    "keyVaultURL": "[concat('https://', parameters('keyVaultName'), '.vault.azure.net/')]",
    "keyVaultResourceID": "[concat(subscription().id,'/resourceGroups/',parameters('keyVaultResourceGroup'),'/providers/Microsoft.KeyVault/vaults/', parameters('keyVaultName'))]"
  },
  "resources": [
    {
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