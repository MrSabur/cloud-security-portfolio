# Zero-Trust Architecture for Fintech

Production-grade zero-trust security architecture for a payment processing platform, demonstrating PCI-DSS compliance patterns.

## Scenario

**NovaPay** is a Series B fintech startup providing payment APIs to e-commerce platforms. Processing $50M monthly with a path to PCI-DSS Level 1 certification.

### Business Requirements

- Process credit card transactions via API
- Support 1,000+ merchant integrations
- Pass PCI-DSS Level 1 audit within 90 days
- Scale to $500M monthly transaction volume

### Security Requirements

- Zero-trust architecture (assume breach)
- Cardholder Data Environment (CDE) isolation
- API-first security model
- Service-to-service authentication
- Encryption everywhere (transit + rest)

## Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                     Public Internet                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway                                │
│            (WAF, Rate Limiting, API Key Validation)             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Application Layer                             │
│                   (Out of PCI Scope)                            │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  Merchant   │  │  Webhook    │  │      Reporting          │ │
│  │   Portal    │  │   Service   │  │       Service           │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│         Only tokens pass through this layer                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Cardholder Data Environment (CDE)                  │
│                      (PCI Scope)                                │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │Tokenization │  │  Payment    │  │       Card Vault        │ │
│  │  Service    │──│  Processor  │──│       (KMS/HSM)         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│    Mutual TLS │ Network Isolated │ Encrypted at Rest           │
└─────────────────────────────────────────────────────────────────┘
```

## Zero-Trust Pillars

| Pillar | Implementation |
|--------|----------------|
| **Identity** | IAM Identity Center, service accounts with short-lived credentials, API key management |
| **Network** | CDE isolation, private subnets, security groups with least-privilege |
| **Application** | API Gateway with WAF, mutual TLS between services, input validation |
| **Data** | Tokenization, KMS encryption, field-level encryption for PAN |
| **Visibility** | CloudTrail, VPC Flow Logs, API access logs, real-time alerting |

## Modules

| Module | Purpose |
|--------|---------|
| [cde-network](terraform/modules/cde-network/) | Isolated network for cardholder data environment |
| [api-gateway](terraform/modules/api-gateway/) | API security layer with WAF and rate limiting |
| [secrets-management](terraform/modules/secrets-management/) | Secrets Manager with rotation |
| [tokenization](terraform/modules/tokenization/) | Card tokenization service pattern |

## Design Decisions

- [ADR-001: Identity and Access Strategy](docs/decisions/001-identity-and-access.md)
- [ADR-002: Network Segmentation and CDE Isolation](docs/decisions/002-network-segmentation.md)
- [ADR-003: Data Protection and Tokenization](docs/decisions/003-data-protection.md)
- [ADR-004: API Security](docs/decisions/004-api-security.md)

## PCI-DSS Mapping

| PCI-DSS Requirement | Implementation |
|---------------------|----------------|
| **1.** Install and maintain network security controls | CDE network isolation, security groups, NACLs |
| **2.** Apply secure configurations | Hardened AMIs, no default credentials |
| **3.** Protect stored account data | Tokenization, KMS encryption, HSM for keys |
| **4.** Protect cardholder data during transmission | TLS 1.2+, mutual TLS within CDE |
| **5.** Protect against malicious software | GuardDuty, container scanning |
| **6.** Develop secure systems and software | CI/CD security gates, dependency scanning |
| **7.** Restrict access by business need-to-know | IAM least privilege, RBAC |
| **8.** Identify users and authenticate access | MFA, short-lived credentials, no shared accounts |
| **9.** Restrict physical access | AWS managed (inherited control) |
| **10.** Log and monitor access | CloudTrail, VPC Flow Logs, SIEM integration |
| **11.** Test security regularly | Automated scanning, penetration testing |
| **12.** Support information security with policies | Documented policies (out of scope for this repo) |

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| API Gateway | ~$50-200 (based on requests) |
| WAF | ~$25 + $1/million requests |
| Secrets Manager | ~$5-20 |
| KMS | ~$1-10 |
| VPC (NAT, endpoints) | ~$100 |
| **Total** | **~$200-350/month** |

*Excludes compute, database, and data transfer costs.*

## Author

**Sabur Ajao** — Cloud Security Architect

CISSP | CCSP | AWS Solutions Architect | Kellogg MBA