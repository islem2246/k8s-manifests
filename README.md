# Plateforme Électronique de Paiement — Kubernetes Manifests

## Architecture

Microservices Spring Boot déployés sur Kubernetes (k3d / Minikube).  
**Eureka a été supprimé** et remplacé par le **DNS natif Kubernetes**.

### Composants

| Composant | Image | Port |
|-----------|-------|------|
| PostgreSQL 15 | `postgres:15-alpine` | 5432 |
| Redis 7 | `redis:7-alpine` | 6379 |
| Keycloak 22 | `quay.io/keycloak/keycloak:22.0` | 8080 |
| API Gateway | `yassmineg/api-gateway:latest` | 8080 |
| Invoice Service | `yassmineg/invoice-service:latest` | 8080 |
| Payment Service | `yassmineg/payment-service:latest` | 8080 |
| Subscription Service | `yassmineg/subscription-service:latest` | 8080 |
| Notification Service | `yassmineg/notification-service:latest` | 8080 |
| Signature Service | `yassmineg/signature-service:latest` | 8080 |
| User Auth Service | `yassmineg/user-auth-service:latest` | 8080 |
| Frontend React | `yassmineg/frontend:latest` | 80 |

### Structure des fichiers

```
k8s-manifests/
├── 00-namespace/          # Namespace dédié
├── 01-secrets-configmaps/ # Secrets + ConfigMaps (DB, Redis, SMTP, routes)
├── 02-infrastructure/     # PostgreSQL, Redis, Keycloak
├── 03-gateway/            # API Gateway (routes DNS K8s)
├── 04-services/           # 6 microservices métier
├── 05-frontend/           # React SPA + Nginx config
├── 06-ingress/            # Ingress + NodePort
├── deploy.sh              # Script de déploiement
├── destroy.sh             # Script de suppression
└── README.md
```

## Prérequis

- **k3d** ou **Minikube** installé et fonctionnel
- `kubectl` configuré
- Images Docker pushées sur `yassmineg/*` DockerHub

## Déploiement rapide

### Option 1 — k3d

```bash
# Créer le cluster avec ports exposés
k3d cluster create plateforme \
  --port 30080:30080@server:0 \
  --port 30880:30880@server:0 \
  --port 30881:30881@server:0

# Déployer
chmod +x deploy.sh
./deploy.sh
```

### Option 2 — Minikube

```bash
minikube start --memory=6144 --cpus=4
minikube addons enable ingress

chmod +x deploy.sh
./deploy.sh
```

## Accès

| Service | NodePort | Ingress |
|---------|----------|---------|
| Frontend | `http://localhost:30080` | `http://plateforme.local` |
| API Gateway | `http://localhost:30880` | `http://plateforme.local/api` |
| Keycloak | `http://localhost:30881` | `http://plateforme.local/auth` |

Pour l'ingress, ajouter dans `/etc/hosts` :
```
127.0.0.1 plateforme.local
```

## Changements par rapport au Docker Compose

| Avant (Docker) | Après (Kubernetes) |
|---|---|
| Eureka Server pour service discovery | DNS Kubernetes natif (`<service>.<namespace>.svc.cluster.local`) |
| `depends_on` Docker Compose | `initContainers` avec `busybox` (wait-for-*) |
| Docker volumes | PersistentVolumeClaims |
| Docker bridge network | Kubernetes ClusterIP Services |
| Ports exposés sur le host | NodePort + Ingress |
| Variables en dur / .env | Secrets + ConfigMaps |
| Single instance | HPA sur Payment Service (scalable ×N) |

## Configuration requise dans le code Spring Boot

Pour que les services fonctionnent sans Eureka, les applications Spring Boot doivent respecter :

1. **Désactiver Eureka** dans `application.yml` ou via variables d'env :
   ```yaml
   eureka:
     client:
       enabled: false
   ```

2. **Utiliser les URLs directes** (déjà injectées via ConfigMap) au lieu de `lb://service-name`

3. **Activer les actuator endpoints** pour les probes K8s :
   ```yaml
   management:
     endpoints:
       web:
         exposure:
           include: health,info
     health:
       probes:
         enabled: true
   ```

## Suppression

```bash
chmod +x destroy.sh
./destroy.sh
```

## Push vers un repo Git (pour ArgoCD)

```bash
cd k8s-manifests
git init
git add .
git commit -m "feat: K8s manifests - Eureka replaced by K8s DNS"
git remote add origin https://github.com/yassmineg/plateforme-k8s-manifests.git
git push -u origin main
```
