# Projet pédagogique — Terraform : VPC + EC2 (Nginx) + RDS MySQL (IAM DB Auth)

Objectif 
------------------------
Déployer, de manière simple et répétable avec Terraform, une petite infrastructure AWS :
- une machine publique (EC2) qui héberge Nginx,
- une base de données MySQL privée (RDS) dans un subnet privé,
- des règles de sécurité (Security Groups) qui contrôlent l’accès,
- utilisation d’Authentication IAM pour se connecter à la base (IAM DB Auth).

Pourquoi ce projet ?
--------------------
- Comprendre les notions de réseau AWS (VPC / subnet public vs privé).  
- Voir comment séparer une application web publique (EC2) d’une base de données privée (RDS).  
- Découvrir une méthode plus sûre d’authentification à la base : IAM DB Auth (tokens IAM) au lieu d’un mot de passe permanent.

Architecture simplifiée
-----------------------
- VPC
  - Subnet public  -> EC2 (Nginx) — IP publique
  - Subnet privé   -> RDS MySQL — non public

Diagramme ASCII :
```
Internet
   |
 [IGW]
   |
Public subnet (EC2 - Nginx) ---> sg app_sg (SSH/HTTP)
   |
Private subnet (RDS MySQL) ---> sg rds_sg (MySQL uniquement depuis app_sg)
```

Fichiers principaux
-------------------
- `vpc-architecture.tf` — code principal : VPC, subnets, EC2, RDS, IAM, SGs.  
- `variables.tf` — variables modifiables (région, AMI, CIDR…).  
- `outputs.tf` — outputs pratiques (IP EC2, endpoint RDS, etc.).  

Prérequis (avant d’exécuter)
----------------------------
- Compte AWS avec permissions pour créer ressources (VPC, EC2, RDS, IAM...).  
- AWS CLI configuré localement ou variables d’environnement pour Terraform.  
- Terraform >= 1.0.  
- Vérifier/mettre une AMI valide dans `variables.tf` si nécessaire (AMI dépend de la région).

Pourquoi j’ai utilisé des variables ?
------------------------------------
Les variables permettent de :
- changer facilement la région, l’AMI ou les CIDR sans toucher au code,
- réutiliser la même configuration pour plusieurs environnements (dev, test, prod),
- rendre le projet compréhensible et configurable par d’autres.

Déploiement pas à pas (rapide)
------------------------------
1) Initialiser Terraform :
```bash
terraform init
```

2) Prévisualiser :
```bash
terraform plan -out=tfplan
```

3) Appliquer :
```bash
terraform apply "tfplan"
```

Après `apply` tu auras des outputs : IP publique de l’EC2 et endpoint du RDS.

Comprendre IAM DB Auth 
-------------------------------------------
- Au lieu d’un mot de passe statique, RDS peut accepter des "tokens" IAM.  
- L’EC2 possède un rôle IAM (instance profile) qui contient la permission `rds-db:connect`.  
- L’EC2 génère un token temporaire (via AWS CLI ou SDK) et l’utilise comme mot de passe pour MySQL.  
- Ce token expire rapidement → réduit le risque si quelqu’un l’intercepte.

Étapes pratiques pour IAM DB Auth (ce qu’il faut faire après le deploy)
--------------------------------------------------------------------
1) Le déploiement crée la base et un mot de passe "bootstrap" (généré par Terraform). Ce mot de passe sert pour la première connexion d’admin.  
2) Se connecter une première fois en admin pour créer un utilisateur MySQL pour IAM (exemples) :
```sql
-- se connecter avec admin (mot de passe bootstrap)
CREATE USER 'app_iam_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin as 'RDS';
GRANT ALL PRIVILEGES ON mydb.* TO 'app_iam_user'@'%';
FLUSH PRIVILEGES;
```
3) Dans IAM, la policy attachée à l’instance EC2 contient une Resource ARN de ce format :
```
arn:aws:rds-db:<region>:<account-id>:dbuser:<db-resource-id>/<db-username>
```
Assure-toi que `<db-username>` correspond au nom MySQL créé (`app_iam_user` ci‑dessus).

4) Exemple pour générer un token depuis l’EC2 et se connecter (exécuter sur l’EC2) :
```bash
# Générer token (AWS CLI)
TOKEN=$(aws rds generate-db-auth-token --hostname <RDS_ENDPOINT> --port 3306 --region <REGION> --username app_iam_user)

# Se connecter via mysql-client (plugin cleartext nécessaire)
mysql --host=<RDS_ENDPOINT> --port=3306 --enable-cleartext-plugin -u app_iam_user -p"$TOKEN" mydb
```

Note pédagogique : pourquoi garder un mot de passe bootstrap ?
- RDS demande un "master password" à la création. On l’utilise uniquement pour créer l’utilisateur IAM dans MySQL.  
- Ensuite l’application utilise IAM tokens. Tu peux conserver le mot de passe pour administration manuelle.

Sécurité et bonnes pratiques 
------------------------------------
- Restreins SSH à ton IP (au lieu de 0.0.0.0/0) ou utilise SSM Session Manager.  
- Ne laisse pas les secrets en clair dans le repo. Terraform stocke les secrets générés dans l’état : protège ton état (S3 + KMS, ou Terraform Cloud).  
- Garde RDS `publicly_accessible = false` (déjà configuré).  
- Préfère IAM Auth pour les connexions applicatives : tokens courts, moins d’exposition.

Dépannage fréquent (conseils rapides)
------------------------------------
- EC2 ne peut pas joindre RDS ? Vérifie les Security Groups (app_sg doit être source autorisée sur rds_sg).  
- Erreur `rds-db:connect` refusée ? Vérifie que la policy IAM référence bien la resource ARN correcte (compte, db resource id, username).  
- Impossible de se connecter avec token ? Assure-toi que `aws rds generate-db-auth-token` est appelé depuis une instance ayant le bon rôle IAM (instance profile).

Nettoyage
---------
Pour tout supprimer :
```bash
terraform destroy
```

Glossaire 
------------------------
- VPC : réseau privé dans AWS.  
- Subnet public : réseau où les instances peuvent avoir une IP publique et être accessibles depuis Internet.  
- Subnet privé : réseau sans IP publique — parfait pour les bases de données.  
- Security Group : pare-feu virtuel attaché aux instances.  
- IAM : gestion des permissions.  
- Instance profile : rôle IAM attaché à une instance EC2.  
- Token IAM (pour RDS) : mot de passe temporaire généré par AWS pour se connecter à la base.




