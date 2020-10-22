# Francais
English version below


## But du projet
Le but de ce projet est de démontrer les différentes façons de se connecter à une instance AWS EC2 (sans outil tiers autre que SSH).  
C'est un projet lié à l'article de blog suivant : TOBECOMPLETED

## Utilisation
Tous ces modules peuvent être utilisés avec Terraform.  
Ils ont été écrits avec Terraform 0.13.4 mais sont probablement compatibles avec des versions antérieures (il faudra peut-être changer la version des providers utilisés)

### ec2-creation-key-access
Ce module a pour but de créer tout le nécessaire à la connexion à une instance EC2 avec la clé utilisée pour sa création

```shell script
terraform apply --var="key_path=/path/to/key.pub" --var="vpc_id=<yourVPCID>"
```

### ec2-key-provision
Ce module a pour but de créer tout le nécessaire à la connexion à une instance EC2 avec une clé SSH différente de celle qui est utilisée pour sa création.  
Cette clé sera ajoutée dynamiquement au démarrage de l'instance.  
`key_path` est la clé à ajouter au démarrage de l'instance  
`creation_key_name` est la clé utilisée pour créer l'instance. Cette clé doit exister au préalable sur votre compte AWS.

```shell script
terraform apply --var="key_path=/path/to/key.pub" --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
```

### ec2-instance-connect
Ce module a pour but de créer le nécessaire à la connexion à une instance EC2 sans avoir à gérer l'ajout de clés personnelles au préalable.
 
```shell script
terraform apply --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
```

### ec2-session-manager
Ce module a pour but de créer le nécessaire à la connexion à une instance EC2 sans avoir besoin d'utiliser une quelconque clé SSH

```shell script
terraform apply --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
``` 


# English

## Purpose
Purpose of this project is to demonstrate the different ways we can use to connect to ec2 instances (with no more external tool than SSH).  
It is linked with the following blog post : TOBECOMPLETED 

## Usage
All these modules can be run with terraform.  
It has been developped with terraform 0.13.4 but it may be compatible with previous version (downgrade of providers version may be needed)

### ec2-creation-key-access
This module aims to create all necessary stuffs for an EC2 instance to be reached with the key used to provision it.

```shell script
terraform apply --var="key_path=/path/to/key.pub" --var="vpc_id=<yourVPCID>"
```

### ec2-key-provision
This module aims to create all necessary stuffs for an EC2 instance to be reached with a different key than the creation one by provisionning it dynamically during instance startup.    
`key_path` is the key to be provisionned dynamically    
`creation_key_name` is the key to be used to create the ec2 instance.  

Hence you should provide another parameter referencing a key pair that is already created in your aws account.

```shell script
terraform apply --var="key_path=/path/to/key.pub" --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
```

### ec2-instance-connect
This module aims to create all necessary stuffs for an EC2 instance to be reached without having to first provision a personnal public key. 
 
```shell script
terraform apply --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
```

### ec2-session-manager
This modules aims to create all necessary stuffs for an EC2 instance to be reached privately without having to use any SSH key.

```shell script
terraform apply --var="vpc_id=<yourVPCID>" --var="creation_key_name=<alreadyExistingKeyPairName>"
``` 