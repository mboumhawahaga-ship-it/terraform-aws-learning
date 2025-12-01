# Projet Terraform : Infrastructure AWS avec VPC, EC2 et RDS (IAM DB Auth)

## Objectif

Déployer une infrastructure AWS complète avec Terraform :
- Une instance EC2 publique hébergeant Nginx
- Une base de données RDS MySQL dans un subnet privé
- Des Security Groups pour contrôler les accès
- Authentification IAM pour la connexion à la base (sans mot de passe permanent)

## Pourquoi ce projet ?

Ce projet permet de comprendre :
- Les concepts de réseau AWS (VPC, subnets publics vs privés)
- La séparation entre une application web publique et une base de données privée
- L'authentification IAM pour RDS : plus sécurisée que les mots de passe statiques

## Architecture

```
Internet
   |
 [IGW]
   |
Public subnet (10.0.1.0/24)
   |
   +-- EC2 (Nginx) --> Security Group: app_sg (ports 22, 80)
   |
Private subnet (10.0.2.0/24)
   |
   +-- RDS MySQL --> Security Group: rds_sg (port 3306, source: app_sg uniquement)
```

## Structure du projet

```
.
├── vpc-architecture.tf    # Infrastructure principale
├── variables.tf           # Variables configurables
├── outputs.tf             # Outputs (IP EC2, endpoint RDS, etc.)
└── README.md
```

## Prérequis

- **Compte AWS** avec les permissions nécessaires (VPC, EC2, RDS, IAM)
- **AWS CLI** configuré localement (`aws configure`)
- **Terraform** >= 1.0
- Vérifier l'AMI dans `variables.tf` (selon votre région)

**⚠️ Coûts estimés** : Environ $20-30/mois si vous laissez tourner (principalement RDS). Pensez à détruire l'infrastructure après vos tests.

## Déploiement

### 1. Initialiser Terraform

```bash
terraform init
```

### 2. Prévisualiser les changements

```bash
terraform plan -out=tfplan
```

### 3. Appliquer la configuration

```bash
terraform apply "tfplan"
```

### 4. Récupérer les outputs

Terraform affichera :
- `ec2_public_ip` : IP publique de l'instance EC2
- `rds_endpoint` : Endpoint de la base RDS
- `db_name` : Nom de la base de données

## Configuration IAM DB Auth

### Principe

Au lieu d'utiliser un mot de passe fixe, RDS accepte des tokens IAM temporaires :
- L'instance EC2 possède un rôle IAM avec la permission `rds-db:connect`
- Un token est généré dynamiquement (valide 15 minutes)
- Ce token sert de mot de passe temporaire

### Étapes de configuration

#### 1. Première connexion en admin

Terraform génère un mot de passe bootstrap pour l'admin. Utilisez-le pour créer un utilisateur IAM dans MySQL :

```bash
# Se connecter à l'instance EC2
ssh -i votre-clé.pem ec2-user@<EC2_PUBLIC_IP>

# Installer le client MySQL si nécessaire
sudo yum install mysql -y

# Se connecter en admin (utilisez le mot de passe des outputs Terraform)
mysql -h <RDS_ENDPOINT> -u admin -p
```

#### 2. Créer l'utilisateur IAM dans MySQL

```sql
CREATE USER 'app_iam_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT ALL PRIVILEGES ON mydb.* TO 'app_iam_user'@'%';
FLUSH PRIVILEGES;
EXIT;
```

#### 3. Vérifier la policy IAM

La policy attachée à l'instance EC2 doit contenir :

```json
{
  "Effect": "Allow",
  "Action": "rds-db:connect",
  "Resource": "arn:aws:rds-db:<region>:<account-id>:dbuser:<db-resource-id>/app_iam_user"
}
```

⚠️ Assurez-vous que le username correspond exactement à celui créé dans MySQL.

#### 4. Se connecter avec un token IAM

```bash
# Générer le token
TOKEN=$(aws rds generate-db-auth-token \
  --hostname <RDS_ENDPOINT> \
  --port 3306 \
  --region <REGION> \
  --username app_iam_user)

# Se connecter
mysql --host=<RDS_ENDPOINT> \
  --port=3306 \
  --enable-cleartext-plugin \
  -u app_iam_user \
  -p"$TOKEN" \
  mydb
```

Si la connexion fonctionne, vous êtes prêt !

## Sécurité et bonnes pratiques

- **Restreindre SSH** : Limitez l'accès SSH à votre IP au lieu de `0.0.0.0/0`
- **Protéger l'état Terraform** : Utilisez un backend S3 avec chiffrement KMS
- **RDS privé** : `publicly_accessible = false` (déjà configuré)
- **Rotation des tokens** : Les tokens IAM expirent automatiquement (15 min)
- **Secrets** : Ne commitez jamais les secrets dans Git

## Dépannage

### L'EC2 ne peut pas joindre le RDS

Vérifiez que le Security Group `app_sg` est bien autorisé comme source dans `rds_sg` :

```bash
# Tester depuis l'EC2
telnet <RDS_ENDPOINT> 3306
```

### Erreur "Access denied" avec le token IAM

- Vérifiez que l'utilisateur MySQL existe et utilise `AWSAuthenticationPlugin`
- Vérifiez que la policy IAM contient le bon `db-resource-id` et `username`
- Vérifiez que l'instance EC2 a bien le rôle IAM attaché :

```bash
aws sts get-caller-identity
```

### Le token ne fonctionne pas

- Les tokens IAM expirent après 15 minutes, régénérez-en un
- Utilisez l'option `--enable-cleartext-plugin` avec le client MySQL

## Nettoyage

Pour détruire toute l'infrastructure :

```bash
terraform destroy
```

Confirmez avec `yes`. Toutes les ressources seront supprimées (VPC, EC2, RDS, IAM roles, etc.).

## Variables disponibles

Les principales variables modifiables dans `variables.tf` :

| Variable | Description | Défaut |
|----------|-------------|--------|
| `aws_region` | Région AWS | `eu-west-1` |
| `vpc_cidr` | CIDR du VPC | `10.0.0.0/16` |
| `ami_id` | AMI pour l'EC2 | (dépend de la région) |
| `db_username` | Username admin RDS | `admin` |

## Glossaire

- **VPC** : Virtual Private Cloud, réseau privé isolé dans AWS
- **Subnet public** : Sous-réseau avec accès Internet via une Internet Gateway
- **Subnet privé** : Sous-réseau sans accès direct à Internet
- **Security Group** : Pare-feu virtuel au niveau des instances
- **IAM** : Identity and Access Management, gestion des permissions AWS
- **Instance Profile** : Rôle IAM attaché à une instance EC2
- **Token IAM** : Mot de passe temporaire généré via AWS pour RDS

## Ressources utiles

- [Documentation Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [IAM Database Authentication pour RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

---




