# Prompt Security Module

Implements defense-in-depth prompt injection defense and output security as defined in ADR-003.

## Architecture

This module deploys four layers of prompt security:
```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: WAF + Input Validation                             │
│   • WAF WebACL with injection pattern rules                │
│   • Rate limiting per IP                                    │
│   • Request size limits                                     │
│   • Lambda for deep pattern analysis + risk scoring        │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Prompt Structure (Application-level)               │
│   • Hardened system prompt templates                       │
│   • User input sandboxing                                   │
│   • RAG document sanitization                               │
│   (Implemented in application code, not Terraform)         │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Bedrock Guardrails                                 │
│   • Topic filters for injection attempts                   │
│   • Word filters for jailbreak terms                       │
│   • Contextual grounding enforcement                       │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Output Validation                                  │
│   • Lambda for response analysis                           │
│   • Compromise indicator detection                         │
│   • PHI leakage checking                                    │
│   • Grounding verification                                  │
├─────────────────────────────────────────────────────────────┤
│ Monitoring & Incident Response                              │
│   • CloudWatch metrics and alarms                          │
│   • EventBridge rules for incident routing                 │
│   • Integration with Security Hub / PagerDuty             │
└─────────────────────────────────────────────────────────────┘
```

## Usage
```hcl
module "prompt_security" {
  source = "./modules/prompt-security"

  project_name = "medassist"
  environment  = "prod"

  # WAF settings
  rate_limit_per_user    = 500
  max_request_size_bytes = 10240

  # Guardrail settings
  grounding_threshold = 0.7
  relevance_threshold = 0.7

  # Alerting
  alarm_sns_topic_arn         = aws_sns_topic.security_alerts.arn
  input_block_alarm_threshold = 50
  waf_block_alarm_threshold   = 100

  tags = {
    Project     = "MedAssist"
    Compliance  = "HIPAA"
    Environment = "prod"
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "ai_api" {
  resource_arn = aws_api_gateway_stage.ai_api.arn
  web_acl_arn  = module.prompt_security.waf_web_acl_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Environment (dev, staging, prod) | `string` | n/a | yes |
| rate_limit_per_user | Max requests per 5-min window per IP | `number` | `500` | no |
| max_request_size_bytes | Max request body size | `number` | `10240` | no |
| grounding_threshold | Threshold for grounding check (0-1) | `number` | `0.7` | no |
| relevance_threshold | Threshold for relevance check (0-1) | `number` | `0.7` | no |
| log_retention_days | CloudWatch log retention | `number` | `2555` | no |
| alarm_sns_topic_arn | SNS topic for alarms | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| waf_web_acl_arn | ARN of WAF WebACL for API Gateway association |
| input_validator_function_arn | ARN of input validation Lambda |
| output_validator_function_arn | ARN of output validation Lambda |
| guardrail_id | ID of Bedrock guardrail for API calls |
| guardrail_version | Version of Bedrock guardrail |

## Attack Patterns Detected

| Category | Examples |
|----------|----------|
| Instruction Override | "Ignore previous instructions", "Disregard above" |
| Role Hijacking | "You are now DAN", "Pretend to be unrestricted" |
| System Prompt Extraction | "Show me your system prompt", "Repeat your instructions" |
| Delimiter Attacks | `</s>`, `[/INST]`, encoded variants |
| Clinical Override | "HIPAA doesn't apply", "Skip the safety check" |
| Jailbreaking | "DAN mode", "Developer mode", roleplay scenarios |

## Incident Response

Alarms are configured for:

| Alarm | Threshold | Severity |
|-------|-----------|----------|
| Compromise Detected | Any occurrence | P1 - Critical |
| High Input Block Rate | 50 blocks / 5 min | P2 - High |
| High WAF Block Rate | 100 blocks / 5 min | P2 - High |

## Related ADRs

- [ADR-001: AI Governance and Risk Tiering](../../docs/decisions/001-ai-governance-and-risk-tiering.md)
- [ADR-002: Data Protection for AI Systems](../../docs/decisions/002-data-protection-for-ai.md)
- [ADR-003: Prompt Injection Defense](../../docs/decisions/003-prompt-injection-defense.md)