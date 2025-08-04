# System Architecture Diagram

## Dual Gateway Architecture - Mermaid Diagram

Below is the Mermaid diagram code for the sbxservice dual-gateway architecture:

```mermaid
graph TD
    A[Internet] --> B[Route 53 DNS]
    B --> C[CloudFront CDN]
    C --> D[AWS WAF]
    D --> E[Application Load Balancer<br/>ALB]
    
    E --> F{Header-Based<br/>Routing}
    
    F -->|X-Gateway: kong| G[Kong NLB<br/>Internal]
    F -->|X-Gateway: gloo| H[Gloo NLB<br/>Internal]
    F -->|No header/other| I[Hello Service<br/>Direct]
    
    G --> J[Kong Gateway<br/>ECS Fargate]
    H --> K[Gloo Gateway<br/>EKS Fargate]
    
    J --> L[Hello Service<br/>ECS Fargate]
    K --> L
    I --> L
    
    L --> M[Cloud Map<br/>Service Discovery]
    
    N[VPC] -.-> O[Private Subnets]
    O -.-> P[Public Subnets]
    
    subgraph "ECS Cluster"
        J
        L
    end
    
    subgraph "EKS Cluster"
        K
    end
    
    subgraph "AWS Services"
        Q[ACM Certificate]
        R[CloudWatch Logs]
        S[IAM Roles]
        T[Security Groups]
    end
    
    E -.-> Q
    J -.-> R
    K -.-> R
    L -.-> R
    
    style A fill:#e1f5fe
    style E fill:#fff3e0
    style F fill:#f3e5f5
    style G fill:#e8f5e8
    style H fill:#e8f5e8
    style J fill:#fff8e1
    style K fill:#fff8e1
    style L fill:#e3f2fd
```

## Usage

You can use this Mermaid diagram in:

1. **GitHub/GitLab README files** - Just paste the code block in markdown
2. **Mermaid Live Editor** - Copy the code to [mermaid.live](https://mermaid.live) to edit and export
3. **Documentation tools** - Most modern documentation platforms support Mermaid
4. **Draw.io/Diagrams.net** - Import as Mermaid diagram
5. **VS Code** - Use Mermaid preview extensions

## Diagram Components

### Traffic Flow
- **Internet → Route 53 → CloudFront → WAF → ALB**: External traffic ingress
- **ALB Header Routing**: Distributes traffic based on `X-Gateway` header
- **Gateway Processing**: Kong or Gloo processes requests
- **Backend Connection**: Both gateways connect to shared hello-service

### Infrastructure Layers
- **Public Layer**: ALB, CloudFront, Route 53
- **Gateway Layer**: Kong (ECS) and Gloo (EKS) with their respective NLBs
- **Application Layer**: Hello Service (ECS) with Cloud Map service discovery
- **Support Services**: ACM, CloudWatch, IAM, Security Groups

### Color Coding
- **Blue tones**: Entry points and load balancers
- **Orange tones**: Core routing and decision points  
- **Purple tones**: Routing logic
- **Green tones**: Network load balancers
- **Yellow tones**: Gateway services
- **Light blue**: Backend services