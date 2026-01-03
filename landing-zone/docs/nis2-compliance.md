# NIS2 Compliance Mapping

This document maps the AWS Landing Zone architecture to the EU NIS2 Directive (Directive 2022/2555) requirements. NIS2 applies to essential and important entities across the EU, with member state transposition completed October 2024.

## Applicability

This architecture supports organizations classified as:
- **Essential Entities**: Healthcare, energy, transport, banking, financial market infrastructure, digital infrastructure
- **Important Entities**: Postal services, waste management, chemicals, food, manufacturing, digital providers

## Article 21 — Cybersecurity Risk Management Measures

NIS2 Article 21 mandates "appropriate and proportionate technical, operational and organisational measures" across 10 domains:

| NIS2 Requirement | Article | Implementation | Module |
|------------------|---------|----------------|--------|
| **Risk analysis and information system security policies** | 21(2)(a) | Security Hub compliance dashboard, AWS Config rules, continuous configuration assessment | `security-baseline` |
| **Incident handling** | 21(2)(b) | GuardDuty threat detection, CloudWatch alarms, Security Hub automated findings aggregation | `security-baseline` |
| **Business continuity and crisis management** | 21(2)(c) | Multi-AZ deployment, Transit Gateway redundancy, automated failover via Route 53 | `vpc`, `transit-gateway` |
| **Supply chain security** | 21(2)(d) | AWS shared responsibility model, Terraform module versioning, GitHub Actions CI/CD with dependency scanning | `.github/workflows` |
| **Security in network and information systems acquisition** | 21(2)(e) | Infrastructure as Code review process, module documentation, input validation | All modules |
| **Policies for assessing effectiveness** | 21(2)(f) | Security Hub security scores, AWS Config compliance percentage, scheduled assessments | `security-baseline` |
| **Cybersecurity hygiene and training** | 21(2)(g) | IAM permission boundaries, least-privilege enforcement, MFA requirements | `security-baseline` |
| **Cryptography and encryption** | 21(2)(h) | KMS encryption at rest, TLS 1.2+ in transit, S3 bucket encryption policies | `security-baseline`, `vpc` |
| **Human resources security and access control** | 21(2)(i) | IAM roles with permission boundaries, no long-lived credentials, Config rules for MFA | `security-baseline` |
| **Multi-factor authentication** | 21(2)(j) | AWS Config rule `iam-user-mfa-enabled`, root account MFA enforcement | `security-baseline` |

## Article 23 — Reporting Obligations

NIS2 requires incident notification to competent authorities within defined timeframes:

| Requirement | Timeframe | Implementation |
|-------------|-----------|----------------|
| Early warning | 24 hours | GuardDuty findings → SNS → alerting pipeline |
| Incident notification | 72 hours | Security Hub aggregation with severity classification |
| Intermediate report | Upon request | CloudTrail logs with 7-year retention, queryable via Athena |
| Final report | 1 month | Comprehensive audit trail in S3 with integrity validation |

### Logging Architecture for NIS2 Reporting
```
┌─────────────────────────────────────────────────────────────────┐
│                    INCIDENT REPORTING FLOW                      │
│                                                                 │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐              │
│  │ GuardDuty │───▶│  Security │───▶│    SNS    │──▶ Alerting  │
│  │ Findings  │    │    Hub    │    │   Topic   │   (24hr)     │
│  └───────────┘    └───────────┘    └───────────┘              │
│                          │                                      │
│                          ▼                                      │
│                   ┌───────────┐                                │
│                   │  S3 +     │──▶ Athena queries for          │
│                   │CloudTrail │    regulatory reports          │
│                   └───────────┘                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Article 24 — Use of European Cybersecurity Certification Schemes

| Consideration | Implementation |
|---------------|----------------|
| AWS certifications | AWS holds ISO 27001, SOC 2, C5 (Germany), ENS (Spain), HDS (France) |
| Customer responsibility | Terraform modules follow CIS AWS Foundations Benchmark |
| Audit evidence | Security Hub exports, Config snapshots, CloudTrail logs |

## Network Segmentation (Article 21(2)(a))

The landing zone implements defense-in-depth aligned with NIS2's risk-based approach:

| Layer | Control | NIS2 Alignment |
|-------|---------|----------------|
| Account isolation | AWS Organizations with SCPs | Blast radius containment |
| Network isolation | Transit Gateway route table separation | Prod/Dev segregation |
| Subnet isolation | Three-tier VPC (Public/Private/Data) | Data tier has no internet route |
| Traffic filtering | Security Groups, NACLs | Default-deny posture |
| Traffic visibility | VPC Flow Logs (365-day retention) | Article 21(2)(b) incident handling |

## Data Protection (Article 21(2)(h))

| Data State | Control | Implementation |
|------------|---------|----------------|
| At rest | AES-256 encryption | S3 default encryption, EBS encryption, RDS encryption |
| In transit | TLS 1.2+ | ALB HTTPS listeners, VPC endpoints for AWS services |
| Key management | AWS KMS | Customer-managed keys with rotation |
| Data residency | Region selection | Deploy in eu-west-1, eu-central-1 for EU data residency |

## Access Control (Article 21(2)(i)(j))

| Control | Implementation | Evidence |
|---------|----------------|----------|
| Least privilege | IAM permission boundaries | Terraform `iam_permission_boundary_arn` variable |
| No standing access | IAM roles, no IAM users with console access | Config rule `iam-user-no-policies-check` |
| MFA enforcement | Required for all human access | Config rule `iam-user-mfa-enabled` |
| Credential rotation | Secrets Manager automatic rotation | 30-day rotation policy |
| Access logging | CloudTrail | All API calls logged with integrity validation |

## Deployment Considerations for EU

### Region Selection
```hcl
# For NIS2 compliance, deploy in EU regions
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"  # Ireland

  validation {
    condition     = can(regex("^eu-", var.aws_region))
    error_message = "NIS2 compliance requires EU region deployment."
  }
}
```

### Data Residency

| Requirement | Implementation |
|-------------|----------------|
| EU data stays in EU | S3 bucket region lock, no cross-region replication outside EU |
| Backup location | Same region or EU region only |
| Log storage | CloudTrail and Config buckets in same EU region |

## Audit Checklist

Use this checklist during NIS2 compliance assessments:

- [ ] All infrastructure deployed in EU region
- [ ] CloudTrail enabled with log file validation
- [ ] GuardDuty enabled in all accounts
- [ ] Security Hub enabled with findings aggregation
- [ ] AWS Config recording with HIPAA/NIS2 rules
- [ ] VPC Flow Logs enabled (365-day retention minimum)
- [ ] S3 buckets encrypted and not public
- [ ] EBS volumes encrypted
- [ ] RDS instances encrypted
- [ ] MFA enabled for all IAM users
- [ ] No IAM users with console passwords (use SSO)
- [ ] Permission boundaries applied to all roles
- [ ] Incident response runbook documented
- [ ] 24-hour alerting pipeline tested

## Related Documentation

- [ADR-001: Multi-Account Strategy](decisions/001-multi-account-strategy.md)
- [ADR-002: Network Topology](decisions/002-network-topology.md)

## References

- [NIS2 Directive Full Text (EUR-Lex)](https://eur-lex.europa.eu/eli/dir/2022/2555)
- [ENISA NIS2 Guidance](https://www.enisa.europa.eu/topics/nis-directive)
- [AWS Compliance Programs](https://aws.amazon.com/compliance/programs/)