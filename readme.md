## APISIX Harbor Deployment Project

Automated deployment project for building, packaging, and deploying APISIX and related components to Harbor private repository.

### 📁 Project Structure

- **charts/** - Helm Chart source code
  - `apisix/` - APISIX Helm Chart
  - `etcd/` - etcd Helm Chart  
  - `common/` - Common Chart template library
- **containers/** - Docker image build scripts
  - `apisix/` - APISIX image
  - `apisix-ingress-controller/` - APISIX ingress controller
  - `etcd/` - etcd image
  - `os-shell/` - Base shell image
- **build/** - Automated build scripts
  - `docker/` - Docker image build tools
  - `helm/` - Helm Chart packaging tools
- **dep_resources/** - Deployment resource configuration files

### 🚀 Quick Start

#### Prerequisites

- Docker and Docker Buildx
- Helm 3.0+
- Harbor private repository
- Linux/macOS environment

#### 1. Docker Image Build and Push

```bash
cd build/docker

# Copy configuration template
cp config.env.example config.env

# Edit configuration file and fill in Harbor information
vim config.env
```

**Configuration file example (config.env):**
```bash
HARBOR_URL="harbor.example.com:443"
HARBOR_PROJECT="library"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"
PLATFORMS="linux/amd64"
USE_BUILDX=true
PUSH_LATEST=false
```

**Build images:**
```bash
# Build single image
./build-image.sh etcd 3.6.5 3.6/debian-12 

```

**Push to Harbor:**
```bash
# Push image to Harbor
./push-image.sh etcd 3.5.18
```

#### 2. Helm Chart Packaging and Push

```bash
cd build/helm

# Copy configuration template
cp config.env.example config.env

# Edit configuration file
vim config.env
```

**Package Chart:**
```bash
# Package single Chart
./package-chart.sh apisix

# Push to Harbor Chart Repository
./push-chart.sh apisix
```

#### 3. Deploy Applications

**Deploy etcd:**
```bash
helm repo add myrepo http://harbor.example.com/chartrepo/library
helm repo update

helm install my-etcd myrepo/etcd \
  --namespace apisix \
  --create-namespace \
  -f dep_resources/harbor-values.yaml
```

**Deploy APISIX:**
```bash
helm install my-apisix myrepo/apisix \
  --namespace apisix \
  --create-namespace \
  -f dep_resources/apisix-values.yaml
```

### 📋 Deployment Resources

`dep_resources/` directory contains deployment configurations:

- **apisix-values.yaml** - APISIX deployment configuration
- **harbor-values.yaml** - Harbor deployment configuration
- **harbor.yaml** - Harbor installation configuration

### 🔧 Common Configurations

**Docker image build:** See `build/docker/README.md`

**Helm Chart packaging:** See scripts in `build/helm/`

### 📚 Related Issues

- [APISIX Issue #12705](https://github.com/apache/apisix/issues/12705)

### 📝 Version Information

- Harbor: 2.31.1
- APISIX: Latest version
- etcd: 3.5+

---

## 🔨 Complete Environment Deployment Guide

This section provides step-by-step instructions to build and deploy the entire stack on Kubernetes.

### Phase 1: Build Docker Images and Helm Charts

#### Step 1.1: Build Docker Images from Containers

Navigate to the containers directory and build the required Docker images:

```bash
cd containers

# Build etcd image
cd etcd/3.6
docker build -t etcd:3.6.5 .

# Build APISIX image
cd ../../apisix/3
docker build -t apisix:latest .

# Build APISIX Ingress Controller image
cd ../../apisix-ingress-controller/1
docker build -t apisix-ingress-controller:latest .
```

Or use the automated build scripts:

```bash
cd build/docker

# Configure Harbor credentials
cp config.env.example config.env
# Edit config.env with your Harbor details
vim config.env

# Build and push images
./build-image.sh etcd 3.6.5
./build-image.sh apisix latest
./build-image.sh apisix-ingress-controller latest
```

#### Step 1.2: Package Helm Charts

Navigate to the charts directory and package the Helm charts in the correct dependency order:

```bash
cd build/helm

# Configure Harbor Chart Repository credentials
cp config.env.example config.env
vim config.env

# Package charts in dependency order:
# 1. common - base chart library (dependency for others)
./package-chart.sh common

# 2. etcd - dependency chart for APISIX
./package-chart.sh etcd

# 3. apisix - depends on common and etcd charts
./package-chart.sh apisix

# Push to Harbor Chart Repository (in same order)
./push-chart.sh common 1.0.0
./push-chart.sh etcd 3.5.0
./push-chart.sh apisix 2.0.0
```

**Important:** Always package charts in this order to ensure all dependencies are satisfied:
1. `common` - Base chart library (no dependencies)
2. `etcd` - Dependency chart (no standalone deployment needed)
3. `apisix` - Main deployment (includes etcd as a dependency)

### Phase 2: Deploy Harbor on Kubernetes

#### Step 2.1: Prerequisites

Ensure you have:

- Kubernetes cluster 1.10+
- Helm 3.0+
- Persistent storage class supporting ReadWriteMany
- External PostgreSQL database (optional for HA)
- External Redis instance (optional for HA)

#### Step 2.2: Create Namespace

```bash
kubectl create namespace harbor
kubectl create namespace apisix
```

#### Step 2.3: Configure Storage

Create a persistent volume claim for Harbor storage:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-pvc
  namespace: harbor
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
```

#### Step 2.4: Deploy Harbor via Helm

```bash
# Add Harbor Helm repository
helm repo add harbor https://helm.goharbor.io
helm repo update

# Install Harbor using values from dep_resources
helm install harbor harbor/harbor \
  --namespace harbor \
  --values dep_resources/harbor-values.yaml
```

The deployment uses pre-configured values from `dep_resources/harbor-values.yaml`. You can customize these values by editing the file or using `--set` flag:

```bash
# Example: Override external URL
helm install harbor harbor/harbor \
  --namespace harbor \
  --values dep_resources/harbor-values.yaml \
  --set externalURL=https://harbor.example.com
```

#### Step 2.5: Configure Local DNS/Hosts

Add Harbor to your local hosts file:

```bash
# On macOS/Linux
echo "127.0.0.1 harbor.example.local" >> /etc/hosts

# Or if using port-forward
kubectl port-forward -n harbor svc/harbor 80:80 &
```

#### Step 2.6: Verify Harbor Deployment

```bash
# Check Harbor pod status
kubectl get pods -n harbor

# Access Harbor UI
# Browser: http://harbor.example.local
# Default credentials: admin / Harbor12345
```

### Phase 3: Deploy APISIX on Kubernetes

#### Step 3.1: Add Harbor Chart Repository to Helm

```bash
# Add custom Harbor Chart repository
helm repo add harbor-repo http://harbor.example.local/chartrepo/library
helm repo update
```

#### Step 3.2: Deploy APISIX (with etcd as dependency)

```bash
# Deploy APISIX using pre-configured values
# etcd will be automatically deployed as a dependency
helm install apisix harbor-repo/apisix \
  --namespace apisix \
  --create-namespace \
  -f dep_resources/apisix-values.yaml
```

Alternatively, deploy with custom values overrides:

```bash
helm install apisix harbor-repo/apisix \
  --namespace apisix \
  --create-namespace \
  -f dep_resources/apisix-values.yaml \
  --set serviceType=NodePort
```

#### Step 3.3: Verify APISIX and etcd Deployment

```bash
# Check pod status - both APISIX and etcd pods should be running
kubectl get pods -n apisix

# Check services
kubectl get svc -n apisix

# Port-forward APISIX admin API (optional)
kubectl port-forward -n apisix svc/apisix-admin 9180:9180 &

# Port-forward APISIX gateway (optional)
kubectl port-forward -n apisix svc/apisix-gateway 9080:9080 &
```

### Phase 4: Configure APISIX to Proxy to Harbor

#### Step 4.1: Create Upstream for Harbor

```bash
curl -X PUT http://localhost:9180/apisix/admin/upstreams/harbor \
  -H 'X-API-Key: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "roundrobin",
    "nodes": {
      "harbor.example.local:80": 1
    }
}'
```

#### Step 4.2: Create Route to Harbor

```bash
curl -X PUT http://localhost:9180/apisix/admin/routes/harbor_route \
  -H 'X-API-Key: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "methods": ["GET", "POST", "PUT", "DELETE", "PATCH"],
    "upstream_id": "harbor",
    "uri": "/*",
    "strip_uri": false,
    "host": "harbor.proxy.local"
}'
```

### Phase 5: Build Test Image and Push via APISIX Proxy

#### Step 5.1: Create Test Dockerfile

```bash
mkdir -p test-image
cat > test-image/Dockerfile <<EOF
FROM alpine:latest

RUN apk add --no-cache curl wget

CMD ["echo", "Test image pushed through APISIX proxy to Harbor"]
EOF
```

#### Step 5.2: Build Test Image

```bash
cd test-image

# Build with tag pointing to Harbor via APISIX proxy
docker build -t harbor.proxy.local/library/test-app:1.0 .
```

#### Step 5.3: Configure Docker to Accept APISIX Proxy Address

Add your local host mapping:

```bash
# Add to /etc/hosts
echo "127.0.0.1 harbor.proxy.local" >> /etc/hosts
```

If Harbor uses self-signed HTTPS, configure Docker daemon:

```bash
# Create/edit ~/.docker/config.json
{
  "insecure-registries": ["harbor.proxy.local"]
}
```

#### Step 5.4: Log in to Harbor via APISIX Proxy

```bash
docker login harbor.proxy.local -u admin -p Harbor12345
```

#### Step 5.5: Push Test Image

```bash
docker push harbor.proxy.local/library/test-app:1.0
```

#### Step 5.6: Verify Push

```bash
# Check Harbor UI
# Navigate to: http://harbor.example.local
# Project: library
# Repository: test-app
# Tag: 1.0

# Or use curl to verify
curl -u admin:Harbor12345 http://harbor.example.local/api/v2.0/projects/library/repositories/test-app/artifacts
```

### Phase 6: Test the Complete Flow

#### Step 6.1: Verify Image via APISIX

```bash
# Pull image from APISIX proxy
docker pull harbor.proxy.local/library/test-app:1.0

# Create container from pulled image
docker run harbor.proxy.local/library/test-app:1.0
```

#### Step 6.2: Monitor APISIX Logs

```bash
kubectl logs -n apisix -l app=apisix -f
```

#### Step 6.3: Monitor Harbor Logs

```bash
kubectl logs -n harbor -l app=harbor -f
```

### 🐛 Troubleshooting

**Issue: Cannot connect to Harbor from APISIX**

```bash
# Check Harbor service DNS within Kubernetes
kubectl exec -it -n apisix <apisix-pod> -- nslookup harbor.harbor.svc.cluster.local

# Check network connectivity
kubectl exec -it -n apisix <apisix-pod> -- curl -v http://harbor.harbor.svc.cluster.local
```

**Issue: Image push fails**

```bash
# Check APISIX logs
kubectl logs -n apisix <apisix-pod> --tail=100

# Check route configuration
curl http://localhost:9180/apisix/admin/routes

# Test routing manually
curl -H "Host: harbor.proxy.local" http://localhost:9080/
```

**Issue: Docker login fails**

```bash
# Verify Docker can resolve the hostname
nslookup harbor.proxy.local

# Check /etc/hosts configuration
cat /etc/hosts | grep harbor

# Test direct connection
curl -u admin:Harbor12345 http://harbor.proxy.local/api/v2.0/users/current
```

### 📚 References

- [Harbor HA Deployment](https://goharbor.io/docs/2.13.0/install-config/harbor-ha-helm/)
- [APISIX Documentation](https://apisix.apache.org/docs/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Helm Documentation](https://helm.sh/docs/)



 