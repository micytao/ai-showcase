# Red Hat AI Showcase - Demo Platform

A comprehensive AI demonstration platform featuring multiple out-of-the-box demos showcasing various AI capabilities, all deployed on Red Hat OpenShift with GPU time-slicing support.

![Demo Screenshot](assets/demo.png)

## 🎯 Overview

This project is a **modular AI demo platform** designed to showcase production-ready AI implementations running on Red Hat AI Infrastructure Services (RHAIIS). The platform provides a unified interface for multiple AI demos, making it easy to demonstrate various AI capabilities in one place.

### Platform Features

- **Multi-Demo Architecture**: Host and manage multiple AI demonstrations in a single platform
- **Unified Interface**: Modern, responsive web UI for browsing and accessing demos
- **GPU Optimization**: GPU time-slicing configuration for efficient resource utilization
- **Enterprise Ready**: Containerized deployment on OpenShift with comprehensive monitoring
- **Extensible Design**: Easy to add new demos following the established patterns

### Available Demos

✅ **Vision Language Model** - Real-time vision AI with Qwen2-VL-2B-Instruct model
✅ **Smart Retail Analytics** - Customer behavior heatmap analysis for retail optimization
✅ **Vision Gaming** - Interactive AI-powered game with vision capabilities
✅ **Video Search & Analysis** - Intelligent video content search and scene understanding
🔄 **AI Guardrails** - Content safety monitoring with Llama-Guard-3-1B (Coming Soon)
📋 **Conversational AI** - Intelligent chatbot with enterprise security (Planned)
📋 **RAG Application** - Document processing with vector search (Planned)
📋 **Manufacturing QC** - Computer vision for defect detection (Planned)

## 🏗️ Architecture

### Platform Architecture

```
┌───────────────────────────────────────────────────────────────┐
│              Web Application Platform                          │
│         (Nginx + Multi-Page Demo Interface)                   │
│                                                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   VLM    │  │  Retail  │  │  Gaming  │  │  Video   │    │
│  │   Demo   │  │Analytics │  │   Demo   │  │  Search  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│                    Port: 8000                                 │
└────────────────┬─────────────────────────┬───────────────────┘
                 │                         │
                 ▼                         ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   vLLM Service           │  │   Llama Guard Service    │
│   (Vision Model)         │  │   (Safety Guardrails)    │
│   Qwen2-VL-2B-Instruct   │  │   Llama-Guard-3-1B       │
│   Namespace: rhaiis      │  │   Namespace: llama-guard │
│   Port: 8000             │  │   Port: 8000             │
└────────────┬─────────────┘  └──────────────┬───────────┘
             │                               │
             └───────────┬───────────────────┘
                         ▼
              ┌──────────────────────┐
              │   GPU Time-Slicing   │
              │   (NVIDIA Operator)  │
              │   2 Virtual GPUs     │
              └──────────────────────┘
```

The platform uses a **modular architecture** where:
- Each demo is a standalone HTML page with its own functionality
- All demos share common backend services (vLLM, Llama Guard)
- A unified landing page provides navigation and demo discovery
- GPU resources are efficiently shared across all demos via time-slicing

### Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Web Server**: Nginx on Red Hat UBI 9 Minimal
- **ML Models**: 
  - Qwen2-VL-2B-Instruct (Vision Language Model)
  - Llama-Guard-3-1B (Content Safety)
- **ML Framework**: vLLM (High-performance inference)
- **Container Platform**: Red Hat OpenShift
- **GPU Management**: NVIDIA GPU Operator with Time-Slicing
- **Infrastructure**: AWS EC2 (g6.8xlarge instances)

## 🚀 Quick Start

### Prerequisites

- OpenShift cluster (4.10+)
- NVIDIA GPU Operator installed
- `oc` CLI tool
- `kubectl` CLI tool
- GPU-enabled nodes (recommended: AWS g6.8xlarge)

### Local Development

For quick local testing:

```bash
# Start the local development server
./start-server.sh

# Access at http://localhost:8000
```

### Deploy the Platform

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ai-showcase
   ```

2. **Configure GPU Time-Slicing** (if not already configured)
   ```bash
   ./scripts/enable-gpu-timeslicing.sh
   ```

3. **Deploy to OpenShift**
   ```bash
   ./scripts/deploy-to-openshift.sh
   ```

4. **Access the platform**
   ```bash
   # Get the route URL
   oc get route vlm-demo-route -n vlm-demo -o jsonpath='{.spec.host}'
   ```

The deployment script will automatically:
- Create the `vlm-demo` namespace
- Deploy the web application platform with all demos
- Configure networking and routes
- Set up health checks
- Connect to vLLM and Llama Guard services

### Undeploy

```bash
./scripts/undeploy-from-openshift.sh
```

## 📁 Project Structure

```
rh126-demo/
├── assets/                          # Media assets
│   ├── demo.png                    # Platform screenshot
│   ├── henrique.png                # Team photo
│   ├── michael.png                 # Team photo
│   ├── redhat.png                  # Red Hat logo
│   ├── vllm.png                    # vLLM logo
│   ├── retail.mp4                  # Retail analytics demo video
│   └── traffic_camera.mp4          # Traffic camera demo video
├── docs/                           # Comprehensive documentation
│   ├── EC2-MANAGEMENT-README.md    # AWS EC2 instance management
│   ├── GPU-SETUP-README.md         # GPU configuration guide
│   ├── GPU-TIMESLICING-SETUP.md    # GPU time-slicing setup
│   ├── NVIDIA-GPU-OPERATOR-INSTALL-GUIDE.md  # GPU operator installation
│   ├── OPENSHIFT-MACHINESET-SYNC.md # OpenShift MachineSet synchronization
│   ├── GAME-ARCHITECTURE.md        # Gaming demo architecture
│   ├── RETAIL-ANALYTICS-ARCHITECTURE.md # Retail demo architecture
│   ├── VIDEO-SEARCH-ARCHITECTURE.md # Video search architecture
│   └── VLM-ARCHITECTURE.md         # Vision Language Model architecture
├── openshift/                      # Kubernetes/OpenShift manifests
│   ├── gpu-time-slicing-config.yaml           # GPU time-slicing ConfigMap
│   ├── nvidia-gpu-operator-with-timeslicing.yaml  # GPU operator setup
│   └── web-app-deployment.yml      # Web application deployment
├── scripts/                        # Automation scripts
│   ├── check-current-gpu-status.sh # GPU status checker
│   ├── convert-ec2-instance.sh     # EC2 instance type converter
│   ├── deploy-to-openshift.sh      # Deployment automation
│   ├── enable-gpu-timeslicing.sh   # Enable GPU sharing
│   ├── sync-openshift-machineset.sh # MachineSet sync utility
│   ├── undeploy-from-openshift.sh  # Remove deployment
│   └── verify-gpu-timeslicing.sh   # Verify GPU configuration
├── web/                            # Web application platform
│   ├── Containerfile               # Container build specification
│   ├── index.html                  # Platform landing page
│   ├── vlm.html                    # Vision Language Model demo
│   ├── retail-analytics.html       # Smart Retail Analytics demo
│   ├── game.html                   # Vision Gaming demo
│   └── video-search.html           # Video Search & Analysis demo
├── start-server.sh                 # Local development server script
├── hf_token.txt                    # Hugging Face token (add your own)
├── LICENSE                         # Project license
└── README.md                       # This file
```

## 🔧 Configuration

### Environment Variables

The web application supports the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_NAMESPACE` | `rhaiis` | Namespace for vLLM service |
| `VLLM_SERVICE` | `rhaiis-service` | vLLM service name |
| `VLLM_PORT` | `8000` | vLLM service port |
| `LLAMA_GUARD_NAMESPACE` | `llama-guard` | Namespace for Llama Guard |
| `LLAMA_GUARD_SERVICE` | `llama-guard-service` | Llama Guard service name |
| `LLAMA_GUARD_PORT` | `8000` | Llama Guard service port |

### GPU Time-Slicing

GPU time-slicing allows multiple workloads to share a single GPU. Configuration:

```yaml
replicas: 2  # Number of virtual GPUs per physical GPU
```

**Benefits:**
- Efficient GPU utilization for inference workloads
- Lower infrastructure costs
- Simplified resource management

**Considerations:**
- Shared GPU memory (reduce per-workload memory if needed)
- Time-shared compute (expect some latency increase)
- Best for inference workloads with < 100% GPU utilization

See `docs/GPU-TIMESLICING-SETUP.md` for detailed configuration.

## 📚 Documentation

### Demo Architecture Guides

- **[Vision Language Model Architecture](docs/VLM-ARCHITECTURE.md)**: VLM demo technical details
- **[Retail Analytics Architecture](docs/RETAIL-ANALYTICS-ARCHITECTURE.md)**: Retail heatmap implementation
- **[Video Search Architecture](docs/VIDEO-SEARCH-ARCHITECTURE.md)**: Video analysis system design
- **[Gaming Demo Architecture](docs/GAME-ARCHITECTURE.md)**: Vision gaming implementation

### Setup Guides

- **[GPU Setup](docs/GPU-SETUP-README.md)**: Initial GPU configuration
- **[GPU Time-Slicing Setup](docs/GPU-TIMESLICING-SETUP.md)**: Enable GPU sharing
- **[NVIDIA GPU Operator Installation](docs/NVIDIA-GPU-OPERATOR-INSTALL-GUIDE.md)**: Complete operator setup

### Infrastructure Management

- **[EC2 Management](docs/EC2-MANAGEMENT-README.md)**: AWS EC2 instance automation
- **[OpenShift MachineSet Sync](docs/OPENSHIFT-MACHINESET-SYNC.md)**: MachineSet management

### Scripts Reference

All scripts include `--help` flag for detailed usage:

```bash
./scripts/deploy-to-openshift.sh --help
./scripts/enable-gpu-timeslicing.sh --help
./scripts/convert-ec2-instance.sh --help
```

## 🎨 Features

### Platform Features

- **Multi-Demo Hub**: Browse and access multiple AI demos from a unified interface
- **Modern UI**: Sleek, responsive design with Red Hat branding
- **Demo Discovery**: Search, filter, and vote for your favorite demos
- **Dark/Light Mode**: Adaptive UI theme across all demos
- **Mobile Responsive**: Works seamlessly on desktop, tablet, and mobile

### Demo-Specific Features

#### Vision Language Model
- Real-time camera feed processing
- Multi-modal input (camera, images, text)
- Customizable prompts with conversation history

#### Smart Retail Analytics
- Customer behavior heatmap visualization
- Real-time video analytics
- Zone-based insights and metrics

#### Vision Gaming
- Interactive AI-powered gameplay
- Vision-based game mechanics
- Real-time AI opponent

#### Video Search & Analysis
- Intelligent video content search
- Scene understanding and analysis
- Frame-by-frame navigation

### Enterprise Features

- **AI Guardrails**: Real-time content moderation via Llama Guard (integrated across demos)
- **Health Checks**: Built-in liveness and readiness probes
- **Comprehensive Logging**: Detailed logs for debugging
- **Metrics Export**: GPU and application metrics
- **Easy Deployment**: One-command deployment scripts

## ➕ Adding New Demos

The platform is designed to be easily extensible. To add a new demo:

### 1. Create Demo HTML File

Create a new HTML file in the `web/` directory (e.g., `web/my-new-demo.html`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <title>My New Demo</title>
    <!-- Include styles and scripts -->
</head>
<body>
    <!-- Your demo content -->
</body>
</html>
```

### 2. Add Demo Card to Landing Page

Edit `web/index.html` and add a new demo card in the demos grid:

```javascript
<div class="demo-card" data-status="available" onclick="window.location.href='my-new-demo.html'">
    <div class="demo-card-header">
        <span class="demo-status available">Available</span>
        <span class="demo-tag">Your Category</span>
    </div>
    <i class="fas fa-your-icon demo-icon"></i>
    <div class="demo-card-title">My New Demo</div>
    <div class="demo-card-description">
        Brief description of your demo
    </div>
</div>
```

### 3. Create Architecture Documentation

Add a new architecture document in `docs/` (e.g., `docs/MY-NEW-DEMO-ARCHITECTURE.md`) describing:
- Demo overview and purpose
- Technical architecture
- Required services and dependencies
- Configuration details

### 4. Update Container Build

The Containerfile automatically includes all HTML files. Simply rebuild:

```bash
podman build -f web/Containerfile -t my-platform:latest .
```

### 5. Test and Deploy

```bash
# Test locally
./start-server.sh

# Deploy to OpenShift
./scripts/deploy-to-openshift.sh
```

## 🛠️ Building the Container Image

### Build locally

```bash
podman build -f web/Containerfile -t ai-demo-platform:latest .
```

### Build and push to registry

```bash
# Build
podman build -f web/Containerfile -t quay.io/your-org/ai-demo-platform:latest .

# Push
podman push quay.io/your-org/ai-demo-platform:latest
```

### Update deployment

```bash
# Update image in deployment script
export CONTAINER_IMAGE=quay.io/your-org/ai-demo-platform:latest
./scripts/deploy-to-openshift.sh
```

## 🔍 Monitoring and Troubleshooting

### Check Application Status

```bash
# View all pods
oc get pods -n vlm-demo

# View web application logs
oc logs -f deployment/vlm-demo-app -n vlm-demo

# View vLLM logs
oc logs -f deployment/rhaiis -n rhaiis

# View Llama Guard logs
oc logs -f deployment/llama-guard -n llama-guard
```

### Verify GPU Status

```bash
# Check GPU time-slicing
./scripts/verify-gpu-timeslicing.sh

# Check current GPU status
./scripts/check-current-gpu-status.sh

# View GPU allocation
oc describe node | grep -A 10 "Allocated resources"
```

### Common Issues

**Issue: Pods stuck in Pending**
```bash
# Check GPU allocation
oc describe pod <pod-name> -n <namespace>

# Verify GPU capacity
oc get nodes -o json | jq '.items[] | select(.status.capacity["nvidia.com/gpu"] != null)'
```

**Issue: vLLM service not responding**
```bash
# Check service endpoints
oc get endpoints -n rhaiis

# Test service connectivity
oc run test --rm -it --image=curlimages/curl -- curl http://rhaiis-service.rhaiis:8000/health
```

**Issue: Camera not working**
- Ensure browser has camera permissions
- Use HTTPS (required for camera access)
- Check browser console for errors

## 🔮 Platform Vision & Roadmap

### Vision

This platform aims to become a comprehensive AI demonstration hub that makes it easy to:
- **Showcase** various AI capabilities in a unified, professional interface
- **Educate** stakeholders about AI potential through hands-on experiences
- **Accelerate** AI adoption by providing working reference implementations
- **Simplify** demo deployment and management on OpenShift

### Roadmap

**Phase 1: Foundation** ✅ (Complete)
- Multi-demo platform architecture
- Core demos (VLM, Retail, Gaming, Video Search)
- GPU time-slicing optimization
- Production-ready deployment

**Phase 2: Expansion** 🔄 (In Progress)
- AI Guardrails standalone demo
- Conversational AI assistant
- RAG application demo
- Manufacturing quality control demo

**Phase 3: Enhancement** 📋 (Planned)
- Demo analytics and usage tracking
- User authentication and personalization
- Demo voting and feedback system
- Multi-language support
- Advanced GPU resource management

**Phase 4: Community** 📋 (Future)
- Demo marketplace for community contributions
- Plugin architecture for easy demo integration
- Automated demo testing framework
- Performance benchmarking suite

### Contributing

Contributions are welcome! We're especially interested in:
- New demo implementations
- UI/UX improvements
- Performance optimizations
- Documentation enhancements
- Bug fixes and testing

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Requirements

### Minimum Requirements

- **OpenShift**: 4.10 or later
- **GPU**: NVIDIA GPU with CUDA support
- **Memory**: 256Mi per web pod, varies for ML models
- **CPU**: 500m (web), varies for ML workloads

### Recommended Production Setup

- **Instance Type**: AWS g6.8xlarge (1x NVIDIA L4 GPU)
- **GPU Replicas**: 2 virtual GPUs per physical GPU
- **High Availability**: Multiple GPU nodes with pod anti-affinity
- **Monitoring**: Prometheus + Grafana for metrics
- **Storage**: Persistent volumes for model caching

## 🌟 Use Cases

### Business & Sales
- **Customer Demonstrations**: Showcase multiple AI capabilities in one platform
- **Trade Shows & Events**: Interactive booth demonstrations
- **Executive Briefings**: High-level AI capability overview
- **Sales Enablement**: Ready-to-use demos for customer meetings

### Technical & Development
- **Proof of Concept**: Validate AI capabilities for specific use cases
- **Architecture Reference**: Example implementations for production systems
- **Training & Education**: Hands-on AI learning platform
- **Development Template**: Starting point for custom AI applications

### Industry-Specific Demos
- **Retail**: Customer behavior analysis and store optimization
- **Manufacturing**: Quality control and defect detection
- **Media**: Video content analysis and search
- **Gaming**: AI-powered interactive experiences

## 📝 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## 👥 Authors

- **Michael Yang** - Red Hat
- **Henrique** - Red Hat

## 🙏 Acknowledgments

- Red Hat AI Infrastructure Services team for platform architecture and support
- NVIDIA for GPU operator and drivers enabling efficient GPU sharing
- vLLM project for high-performance inference capabilities
- Qwen team for the vision language model powering multiple demos
- Meta AI for Llama Guard content safety framework
- Open source community for inspiration and best practices

## 📞 Support

For issues and questions:
- Open an issue in the repository
- Contact the Red Hat AI team
- Review the comprehensive documentation in `docs/`

## 🔗 Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Qwen2-VL Model](https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct)
- [Llama Guard](https://huggingface.co/meta-llama/Llama-Guard-3-1B)

---

**Built with ❤️ of AI*

