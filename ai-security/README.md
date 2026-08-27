# AI Security Reference Architecture

Governance, data protection, and prompt injection defense for AI systems handling regulated data.

**Scenario:** MedAssist Health System, a regional healthcare organization (5 hospitals, 40 clinics, 8,000 employees) adopting AI across clinical, operational, and research domains under HIPAA. The board is asking what the AI risk exposure is and the CISO cannot answer.

## The Problem

Most AI governance fails in one of two directions. Blanket restriction stalls every project behind a six-month review, and teams route around it into shadow AI. Blanket permission ships a patient-facing chatbot with no security review and ends in an OCR investigation.

This architecture routes low-risk AI through a fast lane and applies real scrutiny only where the risk earns it.

## Architecture Decision Records

| ADR | Decision | Covers |
|-----|----------|--------|
| [ADR-001](docs/decisions/001-ai-governance-and-risk-tiering.md) | AI Governance and Risk Tiering | Three-tier risk model, approval authority per tier, intake and review process, NIST AI RMF mapping |
| [ADR-002](docs/decisions/002-data-protection-for-ai.md) | Data Protection for AI Systems | Five-layer data protection, PHI handling in training and inference, KMS and Macie controls |
| [ADR-003](docs/decisions/003-prompt-injection-defense.md) | Prompt Injection Defense and Output Security | Four-layer injection defense, WAF and Bedrock Guardrails, output validation, incident routing |

## Risk Tiering Model

| Tier | Examples | Approval | Target Review Time |
|------|----------|----------|--------------------|
| Tier 1 | Productivity tools, no sensitive data | Department head | 1 week |
| Tier 2 | Internal copilots, de-identified data | CISO plus Privacy | 2 to 4 weeks |
| Tier 3 | Clinical decision support, PHI access, patient-facing health guidance | Full governance board | 4 to 8 weeks |

The tier determines the controls. Tier 3 workloads get every layer in both Terraform modules below. Tier 1 workloads get the guardrail and the audit trail and nothing else.

## Terraform Modules

| Module | Implements | Key Resources |
|--------|-----------|---------------|
| [ai-data-protection](terraform/modules/ai-data-protection/) | ADR-002 | Bedrock guardrails with MRN regex and PHI filters, KMS CMK, tiered S3 with access logging and versioning, Macie classification job, CloudWatch metric filters and alarms |
| [prompt-security](terraform/modules/prompt-security/) | ADR-003 | WAFv2 WebACL with injection pattern rules and per-IP rate limiting, input analysis Lambda, output validation Lambda, contextual grounding thresholds, EventBridge incident routing |

Layer 2 of the prompt defense (hardened system prompt templates, user input sandboxing, RAG document sanitization) is application code, not infrastructure. ADR-003 specifies it; the Terraform does not deploy it.

## Framework Mapping

| Framework | Coverage |
|-----------|----------|
| NIST AI RMF | Govern (ADR-001 tiering and accountability), Map (use case inventory), Measure (metric filters and alarms), Manage (incident routing) |
| HIPAA Security Rule | 164.312(a)(1) access control per tier, 164.312(b) audit controls, 164.312(e)(1) transmission security |
| OWASP Top 10 for LLM Applications | LLM01 prompt injection, LLM02 insecure output handling, LLM06 sensitive information disclosure |

## Status

Three of five planned milestones are complete. Governance (ADR-001), data protection (ADR-002 plus module), and prompt injection defense (ADR-003 plus module) are published here.

Not yet published: a research AI governance ADR covering trial matching, de-identification and re-identification risk, and 21 CFR Part 11 audit requirements; and an environment configuration that composes both modules the way `zero-trust/terraform/environments/novapay-prod/` composes the fintech modules.

The modules are written and validate independently. They are not yet wired into a deployable environment.

## Related Work

- [AWS Landing Zone](../landing-zone/) sets the multi-account and network foundation these workloads run on.
- [Zero-Trust Architecture](../zero-trust/) applies the same isolation logic to cardholder data instead of PHI.
