#!/bin/bash

# Deploy AI Showcase to OpenShift with vLLM
# This script automates the deployment process using container image

set -e

# Configuration
NAMESPACE="${NAMESPACE:-ai-showcase}"
VLLM_NAMESPACE="${VLLM_NAMESPACE:-rhaiis}"
VLLM_SERVICE="${VLLM_SERVICE:-rhaiis-service}"
VLLM_PORT="${VLLM_PORT:-8000}"
LLAMA_GUARD_NAMESPACE="${LLAMA_GUARD_NAMESPACE:-llama-guard}"
LLAMA_GUARD_SERVICE="${LLAMA_GUARD_SERVICE:-llama-guard-service}"
LLAMA_GUARD_PORT="${LLAMA_GUARD_PORT:-8000}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-quay.io/rh_ee_micyang/ai-showcase-amd:0.2}"

echo "================================================"
echo "AI Showcase - OpenShift Deployment"
echo "================================================"
echo ""
echo "Configuration:"
echo "  App Namespace:           $NAMESPACE"
echo "  Container Image:         $CONTAINER_IMAGE"
echo "  vLLM Namespace:          $VLLM_NAMESPACE"
echo "  vLLM Service:            $VLLM_SERVICE"
echo "  vLLM Port:               $VLLM_PORT"
echo "  vLLM Model:              Qwen/Qwen2-VL-2B-Instruct"
echo "  Guardrail Namespace:     $LLAMA_GUARD_NAMESPACE"
echo "  Guardrail Service:       $LLAMA_GUARD_SERVICE"
echo "  Guardrail Port:          $LLAMA_GUARD_PORT"
echo "  Guardrail Model:         Llama-Guard-3-1B"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v oc &> /dev/null; then
    echo "❌ Error: 'oc' CLI not found. Please install OpenShift CLI."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: 'kubectl' CLI not found. Please install kubectl."
    exit 1
fi

echo "✅ CLI tools found"

# Check if logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Error: Not logged into OpenShift cluster."
    echo "   Please run: oc login <cluster-url>"
    exit 1
fi

echo "✅ Logged into OpenShift as: $(oc whoami)"

# Verify vLLM service exists
echo ""
echo "Verifying vLLM service..."
if ! kubectl get svc $VLLM_SERVICE -n $VLLM_NAMESPACE &> /dev/null; then
    echo "⚠️  Warning: vLLM service '$VLLM_SERVICE' not found in namespace '$VLLM_NAMESPACE'"
    echo "   Make sure vLLM is deployed before proceeding."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ vLLM service found: $VLLM_SERVICE.$VLLM_NAMESPACE"
fi

# Verify llama-guard service exists
echo ""
echo "Verifying Llama Guard service..."
if ! kubectl get svc $LLAMA_GUARD_SERVICE -n $LLAMA_GUARD_NAMESPACE &> /dev/null; then
    echo "⚠️  Warning: Llama Guard service '$LLAMA_GUARD_SERVICE' not found in namespace '$LLAMA_GUARD_NAMESPACE'"
    echo "   Make sure Llama Guard is deployed before proceeding."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Llama Guard service found: $LLAMA_GUARD_SERVICE.$LLAMA_GUARD_NAMESPACE"
fi

# Create namespace
echo ""
echo "Creating namespace '$NAMESPACE'..."
oc create namespace $NAMESPACE 2>/dev/null || echo "  Namespace already exists"

# Deploy application using container image
echo ""
echo "Deploying application from container image..."
echo "Image: $CONTAINER_IMAGE"
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-showcase-app
  namespace: $NAMESPACE
  labels:
    app: ai-showcase
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-showcase
  template:
    metadata:
      labels:
        app: ai-showcase
    spec:
      containers:
      - name: web
        image: $CONTAINER_IMAGE
        imagePullPolicy: Always
        ports:
        - containerPort: 8000
          name: http
          protocol: TCP
        env:
        - name: VLLM_NAMESPACE
          value: "$VLLM_NAMESPACE"
        - name: VLLM_SERVICE
          value: "$VLLM_SERVICE"
        - name: VLLM_PORT
          value: "$VLLM_PORT"
        - name: LLAMA_GUARD_NAMESPACE
          value: "$LLAMA_GUARD_NAMESPACE"
        - name: LLAMA_GUARD_SERVICE
          value: "$LLAMA_GUARD_SERVICE"
        - name: LLAMA_GUARD_PORT
          value: "$LLAMA_GUARD_PORT"
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: ai-showcase-service
  namespace: $NAMESPACE
  labels:
    app: ai-showcase
spec:
  selector:
    app: ai-showcase
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  type: ClusterIP
EOF

echo "✅ Deployment created"

# Create route
echo ""
echo "Creating route..."
oc create route edge ai-showcase-route \
  --service=ai-showcase-service \
  --port=8000 \
  --namespace=$NAMESPACE \
  --insecure-policy=Redirect \
  2>/dev/null || echo "  Route already exists, updating..."

oc patch route ai-showcase-route -n $NAMESPACE -p '{"spec":{"port":{"targetPort":"http"},"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'

echo "✅ Route created"

# Wait for deployment
echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/ai-showcase-app -n $NAMESPACE

# Force rollout to pull latest image
echo ""
echo "Forcing rollout to pull latest image..."
oc rollout restart deployment/ai-showcase-app -n $NAMESPACE
sleep 5
kubectl wait --for=condition=available --timeout=120s deployment/ai-showcase-app -n $NAMESPACE

# Get route URL
echo ""
echo "================================================"
echo "Deployment Successful! 🎉"
echo "================================================"
echo ""
ROUTE_URL=$(oc get route ai-showcase-route -n $NAMESPACE -o jsonpath='{.spec.host}')
echo "Application URL: https://$ROUTE_URL"
echo ""
echo "Next Steps:"
echo "1. Open the URL in your browser"
echo "2. Allow camera access when prompted"
echo "3. Test the VLM connection (Qwen2-VL)"
echo "4. Test the Guardrail connection (Llama-Guard)"
echo "5. Enable guardrails and start using the demo!"
echo ""
echo "Backend Services:"
echo "  vLLM (Vision):    $VLLM_SERVICE.$VLLM_NAMESPACE:$VLLM_PORT"
echo "  Llama Guard:      $LLAMA_GUARD_SERVICE.$LLAMA_GUARD_NAMESPACE:$LLAMA_GUARD_PORT"
echo ""
echo "Troubleshooting:"
echo "  View web logs:        oc logs -f deployment/ai-showcase-app -n $NAMESPACE"
echo "  View vLLM logs:       oc logs -f deployment/rhaiis -n $VLLM_NAMESPACE"
echo "  View guardrail logs:  oc logs -f deployment/llama-guard -n $LLAMA_GUARD_NAMESPACE"
echo "  Check pods:           oc get pods -n $NAMESPACE"
echo "  Describe:             oc describe deployment ai-showcase-app -n $NAMESPACE"
echo ""

# Optional: Open in browser
if command -v xdg-open &> /dev/null; then
    read -p "Open in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "https://$ROUTE_URL"
    fi
elif command -v open &> /dev/null; then
    read -p "Open in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "https://$ROUTE_URL"
    fi
fi

echo "Deployment complete! ✅"

