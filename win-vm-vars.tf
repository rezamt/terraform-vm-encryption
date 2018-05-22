variable client_id                    { default = ""}
variable client_secret                { default = ""}
variable tenant_id                    { default = ""}
variable subscription_id              { default = ""}

variable "location"                   { default = "" }
variable "resourceGroupName"          { default = "" }

variable "volumemanager_file_url"    { default = "https://raw.githubusercontent.com/rezamt/azure-utilities/master/ManageVolumeDisk.ps1" }

variable "aadClientID"                { default = "" }
variable "aadClientSecret"            { default = "" }
variable "keyVaultName"               { default = ""}
variable "keyVaultResourceGroupName"  { default = ""}
variable "keyEncryptionKeyURL"        { default = "" }
variable "keyVaultSecretURL"          { default = ""}
variable "volumeType"                 { default = "All"}
variable "sequenceVersion"            { default = "1.0"} # Not usable by extension ?
variable "extensionName"              { default = "AzureDiskEncryption"}
variable "encryptionOperation"        { default = "EnableEncryption"}
variable "keyEncryptionAlgorithm"     { default = "RSA-OAEP"}
variable "keyVaultURL"                { default = ""}
variable "keyVaultResourceID"         { default =  "s"}
variable "useExistingKek"             { default = "kek"} # Check Microsoft Azure Example Link