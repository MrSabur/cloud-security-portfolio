# AI Data Protection Module

Implements defense-in-depth data protection for AI systems as defined in ADR-002.

## Architecture

This module deploys five layers of AI data protection:
```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Data Classification & Access Control               │
│   • S3 bucket with tiered folder structure                 │
│   • IAM roles per tier (Standard/Elevated/Critical)        │
│   • KMS encryption for all AI data                         │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Training Data Controls                             │
│   • Bucket structure enforces data segregation             │
│   • Access logging for audit trail                         │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Input Controls (Pre-Inference)                     │
│   • Bedrock Guardrails for PII/PHI detection               │
│   • Prompt injection detection via topic filters           │
│   • Custom regex for MRN patterns                          │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Output Controls (Post-Inference)                   │
│   • Bedrock Guardrails output filtering                    │
│   • Content policy enforcement                             │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: Audit & Monitoring                                 │
│   • CloudWatch log group (7-year retention)                │
│   • Metric filters for security events                     │
│   • Alarms for PHI leakage and prompt injection            │
│   • Optional Macie for PHI discovery                       │
└─────────────────────────────────────────────────────────────┘
```

## Usage
```hcl
module "ai_data_protection" {
  source = "./modules/ai-data-protection"

  project_name = "medassist"
  environment  = "prod"

  # Custom MRN pattern for your organization
  mrn_regex_pattern = "^MRN-[0-9]{8}$"

  # PHI handling: BLOCK for Tier 1-2, ANONYMIZE for Tier 3
  phi_filter_action = "ANONYMIZE"

  # Enable Macie for PHI scanning
  enable_macie = true

  # Alert notifications
  alarm_sns_topic_arn = aws_sns_topic.security_alerts.arn

  tags = {
    Project     = "MedAssist"
    Compliance  = "HIPAA"
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Environment (dev, staging, prod) | `string` | n/a | yes |
| phi_filter_action | Action for PHI filters: BLOCK or ANONYMIZE | `string` | `"ANONYMIZE"` | no |
| mrn_regex_pattern | Regex pattern for Medical Record Number | `string` | `null` | no |
| log_retention_days | CloudWatch log retention (min 2555 for HIPAA) | `number` | `2555` | no |
| enable_macie | Enable Macie for PHI discovery | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| guardrail_id | ID of the Bedrock guardrail for API calls |
| guardrail_version | Version of the Bedrock guardrail |
| ai_data_bucket_name | S3 bucket for tiered AI data |
| tier1_role_arn | IAM role for Tier 1 (Standard) AI |
| tier2_role_arn | IAM role for Tier 2 (Elevated) AI |
| tier3_role_arn | IAM role for Tier 3 (Critical) AI |
| audit_log_group_name | CloudWatch log group for AI audit trail |

## Bedrock API Integration

When invoking Bedrock models, include the guardrail:
```python
import boto3

client = boto3.client('bedrock-runtime')

response = client.invoke_model(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 1024
    }),
    guardrailIdentifier="<guardrail_id>",
    guardrailVersion="<guardrail_version>"
)
```

## HIPAA Compliance

This module addresses the following HIPAA requirements:

- §164.312(a)(1) - Access controls via tiered IAM roles
- §164.312(b) - Audit controls via CloudWatch logging
- §164.312(c)(1) - Integrity via input/output filtering
- §164.312(e)(1) - Transmission security via KMS encryption
- §164.502(b) - Minimum necessary via data classification

## Related ADRs

- [ADR-001: AI Governance Structure](../../docs/decisions/001-ai-governance-structure.md)
- [ADR-002: Data Protection for AI Systems](../../docs/decisions/002-data-protection-for-ai.md)
