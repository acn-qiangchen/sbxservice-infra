# Kong Documentation Structure

Consolidated Kong Gateway documentation for the sbxservice-infra project.

## Documents (4 Total)

### 1. [Kong Gateway Guide](kong_gateway_guide.md) 📘
**Complete setup and management guide**

- Quick Start (5-minute setup)
- Architecture Overview
- Components (CP, DP, Database, Certificates)
- Deployment Steps
- Database Options (RDS vs ECS PostgreSQL)
- Configuration Examples
- Scaling Guide
- Monitoring

**Use this for**: Initial setup, understanding architecture, deployment procedures

---

### 2. [Kong Admin API Reference](kong_admin_api_reference.md) 📖
**Complete Admin API command reference**

- Creating Services, Routes, Upstreams
- Managing Targets and Load Balancing
- Health Check Configuration
- Plugin Management (rate-limiting, CORS, auth, etc.)
- Advanced Routing (path, host, method, header-based)
- Complete examples with JSON payloads

**Use this for**: Day-to-day Kong management via Admin API

---

### 3. [Kong Troubleshooting Guide](kong_troubleshooting.md) 🔧
**Comprehensive troubleshooting and debugging**

- Quick Diagnostics Scripts
- Common Issues (CP not starting, DP not connecting, routes not working)
- Health Check Issues (Hybrid Mode limitations, configuration)
- Database Issues (connection, migrations)
- Network and Connectivity Problems
- Performance Tuning
- Debugging Commands

**Use this for**: When something goes wrong, debugging, understanding limitations

---

### 4. [Kong Testing Guide](kong_testing_guide.md) 🧪
**Comprehensive testing procedures**

- Basic Functionality Tests
- Performance Testing
- Security Testing
- Plugin Testing
- Load Balancing Validation
- Integration Testing

**Use this for**: Validating Kong setup, performance testing, QA

---

## Quick Navigation

### Common Tasks

| Task | Document | Section |
|------|----------|---------|
| **Deploy Kong for the first time** | [Gateway Guide](kong_gateway_guide.md) | Quick Start |
| **Add a new service/route** | [Admin API Reference](kong_admin_api_reference.md) | Managing Services |
| **Configure health checks** | [Admin API Reference](kong_admin_api_reference.md) | Advanced Upstream Configuration |
| **Data Planes not connecting** | [Troubleshooting Guide](kong_troubleshooting.md) | Issue 2 |
| **Routes not working** | [Troubleshooting Guide](kong_troubleshooting.md) | Issue 3 |
| **Can't see health check status** | [Troubleshooting Guide](kong_troubleshooting.md) | Issue 4 |
| **Test Kong setup** | [Testing Guide](kong_testing_guide.md) | Basic Tests |
| **Add plugins (rate-limiting, CORS)** | [Admin API Reference](kong_admin_api_reference.md) | Adding Plugins |

---

## What Was Consolidated

### Before (10 documents) → After (4 documents)

#### ✅ Merged into **Kong Gateway Guide**:
- ~~kong_gateway_demo.md~~ (architecture, components)
- ~~kong_quick_start.md~~ (quick start section)
- ~~kong_implementation_summary.md~~ (implementation details)
- ~~kong_rds_guide.md~~ (database options section)

#### ✅ Renamed:
- ~~kong_admin_api_command_book.md~~ → **kong_admin_api_reference.md**

#### ✅ Merged into **Kong Troubleshooting Guide**:
- ~~kong_hybrid_mode_troubleshooting.md~~ (hybrid mode issues)
- ~~kong_healthcheck_validation_guide.md~~ (health check validation)
- ~~kong_health_check_quick_fix.md~~ (health check quick fixes)
- ~~kong_hybrid_mode_health_check_limitation.md~~ (hybrid mode health check limitations)

#### ✅ Kept as-is:
- **kong_testing_guide.md** (comprehensive testing procedures)

---

## Document Sizes

| Document | Lines | Primary Focus |
|----------|-------|---------------|
| **Kong Gateway Guide** | ~800 | Setup, Architecture, Deployment |
| **Kong Admin API Reference** | ~760 | API Commands, Configuration |
| **Kong Troubleshooting Guide** | ~600 | Debugging, Problem Solving |
| **Kong Testing Guide** | ~580 | Testing, Validation |

**Total**: ~2,740 lines (down from 5,154 lines - 47% reduction!)

---

## External References

### Kong Official Documentation
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Hybrid Mode](https://docs.konghq.com/gateway/latest/production/deployment-topologies/hybrid-mode/)
- [Kong Admin API](https://docs.konghq.com/gateway/latest/admin-api/)
- [Kong Plugins Hub](https://docs.konghq.com/hub/)

### Known Limitations
- [Health Check in Hybrid Mode](https://surf-ocarina-381.notion.site/Health-Check-in-Hybrid-Mode-2dbf18557a31807cade5c06c24b0928e) - Explains why health checks aren't visible via Control Plane Admin API

---

## Contributing

When updating Kong documentation:
1. Keep it in the appropriate consolidated document
2. Update this README if you add new sections
3. Maintain cross-references between documents
4. Test all commands before documenting

---

Last updated: 2025-01-01

