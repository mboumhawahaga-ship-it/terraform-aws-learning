# Terraform AWS Learning

Premier projet d'apprentissage Terraform pour la préparation à la certification **AWS Solutions Architect Associate**.

Infrastructure AWS complète créée avec Infrastructure as Code (IaC).

> **Note :** Ce projet démontre l'automatisation complète du déploiement d'une infrastructure web sur AWS, du réseau jusqu'au serveur web opérationnel.

---

## 📋 Architecture

Cette infrastructure déploie une architecture web 3-tiers complète :

### 🌐 Couche Réseau
- **VPC** : Réseau virtuel privé isolé (10.0.0.0/16)
- **Subnets** :
  - **Subnet Public** (10.0.1.0/24) dans eu-west-3a - pour les ressources accessibles depuis Internet
  - **Subnet Privé** (10.0.2.0/24) dans eu-west-3b - pour les ressources internes (bases de données, etc.)
- **Internet Gateway** : Porte d'entrée/sortie vers Internet
- **Route Table** : Table de routage configurée pour diriger le trafic Internet (0.0.0.0/0) via l'IGW

### 🔒 Couche Sécurité
- **Security Group** (Firewall virtuel) :
  - Port 22 (SSH) : pour l'administration du serveur
  - Port 80 (HTTP) : pour l'accès web
  - Règle sortante : tout le trafic autorisé

### 💻 Couche Application
- **Instance EC2** : 
  - **Type** : t2.micro 
  - **OS** : Ubuntu Server
  - **Serveur web Nginx** : Installé et configuré **automatiquement** via un script user_data
  - **IP publique** : Automatiquement assignée pour l'accès web

---
Quand j’ai commencé ce projet, je ne savais même pas ce que signifiaient "user data" ou "Nginx". Ces termes me semblaient techniques, abstraits, presque réservés aux experts. Mais en réalité, leur configuration est bien plus simple qu’il n’y paraît.

Ci-dessous, vous trouverez une explication de ce système

## 🤖 

### Qu'est-ce que user_data ?

**user_data** est un script qui s'exécute automatiquement au premier démarrage de l'instance EC2. C'est comme donner une "liste de tâches" donner à votre serveur.

**Dans ce projet, le script user_data :**
1. Met à jour les packages système
2. Installe automatiquement Nginx (serveur web)
3. Crée une page HTML personnalisée
4. Démarre le serveur web

**Résultat :** En lançant simplement `terraform apply`, vous obtenez un serveur web **complètement opérationnel** en 2-3 minutes, sans aucune intervention manuelle !

### Pourquoi Nginx ?

**Nginx** est un serveur web populaire qui transforme votre serveur EC2 en site web accessible.

Une des raisons pour lesquelles j’ai choisi Nginx, c’est que je n’avais pas envie de me trop compliqué la création de mon infra, avec la récupération des clés SSH de l’instance EC2, ni de devoir uploader un site statique dans un bucket S3, configurer les permissions, le hosting, etc.

Avec Nginx, j’ai pu déployer mon site directement sur l’instance EC2 via Terraform, en utilisant les user data. Pas besoin de me connecter manuellement à l’instance, ni de gérer des clés : tout se fait automatiquement au démarrage.

C’est simple, rapide...



