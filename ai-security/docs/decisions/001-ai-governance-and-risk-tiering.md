# ADR-001: AI Governance and Risk Tiering

## Status
Accepted

## Context

MedAssist Health System is a regional healthcare organization (5 hospitals, 40 clinics, 8,000 employees) undergoing rapid AI adoption. Multiple business units are pursuing AI initiatives simultaneously:

| Domain | Use Cases | Requesting Teams |
|--------|-----------|------------------|
| Clinical | Decision support, patient chatbot | CMO, Digital Health |
| Operations | Revenue cycle, internal copilot | CFO, HR, IT |
| Research | Trial matching, evidence generation | Research, Partnerships |

Current state problems:
- No centralized visibility into AI projects (shadow AI emerging)
- Each team evaluating vendors independently (duplicated effort, inconsistent security)
- Legal and Compliance reviewing AI contracts ad-hoc (bottleneck)
- Board asking "what's our AI risk exposure?" — CISO cannot answer
- No framework to differentiate a low-risk FAQ bot from a high-risk diagnostic assistant

The organization needs a governance structure that:
1. Enables innovation (not a "Department of No")
2. Provides risk-appropriate oversight (not one-size-fits-all)
3. Creates accountability without bureaucracy
4. Satisfies regulatory expectations (HIPAA, state AI laws, future federal requirements)
5. Gives the board a defensible answer on AI risk

### The Real Problem

Without governance, MedAssist faces two failure modes:

**Failure Mode 1: Move too fast**
- Team deploys patient-facing chatbot without security review
- Chatbot leaks PHI or hallucinates medical advice
- OCR investigation, class action, board terminations

**Failure Mode 2: Move too slow**
- Every AI project requires 6-month legal review
- Competitors deploy AI-assisted scheduling, billing, clinical tools
- MedAssist loses physicians, patients, and market position

**The goal:** A governance framework that routes low-risk projects through fast lanes while applying rigorous oversight to high-risk deployments.

## Decision

### Establish Three-Tier AI Risk Classification

Not all AI is equal. A chatbot answering "what are your visiting hours?" is not the same as an AI suggesting a cancer diagnosis.
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI RISK TIERING MODEL                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 3: CRITICAL RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Clinical decision support (diagnosis, treatment)                         │
│  • AI accessing/generating PHI                                              │
│  • Patient-facing with health implications                                  │
│  • Research affecting FDA submissions                                       │
│                                                                             │
│  Approval: AI Governance Board + CISO + CMO + Legal                        │
│  Review cycle: Quarterly                                                    │
│  Time to approve: 4-8 weeks                                                 │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 2: ELEVATED RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Internal copilots with access to sensitive data                         │
│  • Revenue cycle / billing automation                                       │
│  • Patient-facing without health implications (scheduling, FAQs)           │
│  • Research on de-identified data                                          │
│                                                                             │
│  Approval: CISO + Data Privacy Officer                                     │
│  Review cycle: Semi-annual                                                  │
│  Time to approve: 2-4 weeks                                                 │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 1: STANDARD RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Internal productivity tools (no sensitive data)                         │
│  • Code assistants for IT                                                   │
│  • Marketing content generation                                            │
│  • Training material development                                           │
│                                                                             │
│  Approval: Department head + Security checklist                            │
│  Review cycle: Annual attestation                                          │
│  Time to approve: 1 week                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Risk Scoring Matrix

Tier assignment is based on two dimensions:

| | Low Data Sensitivity | Medium Data Sensitivity | High Data Sensitivity (PHI) |
|---|---|---|---|
| **High Decision Impact** (clinical, financial) | Tier 2 | Tier 3 | Tier 3 |
| **Medium Decision Impact** (operational) | Tier 1 | Tier 2 | Tier 3 |
| **Low Decision Impact** (productivity) | Tier 1 | Tier 1 | Tier 2 |

**Data Sensitivity:**
- Low: Public information, general business data
- Medium: Internal policies, non-PHI employee data, de-identified datasets
- High: PHI, PII, research data with re-identification risk

**Decision Impact:**
- Low: Affects individual productivity, easily reversible
- Medium: Affects business operations, financial implications
- High: Affects patient care, clinical decisions, regulatory submissions

### AI Governance Board Structure
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI GOVERNANCE BOARD                                  │
│                                                                             │
│  Chair: Chief AI Officer (or CIO if no CAIO)                               │
│                                                                             │
│  Standing Members:                                                          │
│  ├── CISO — Security and technical risk                                    │
│  ├── Chief Medical Officer — Clinical safety and efficacy                  │
│  ├── Chief Privacy Officer — HIPAA, state privacy laws                     │
│  ├── General Counsel — Liability, contracts, regulatory                    │
│  ├── Chief Research Officer — Research integrity, FDA compliance           │
│  └── CFO or delegate — Budget, ROI validation                              │
│                                                                             │
│  Meeting Cadence: Monthly (or ad-hoc for urgent Tier 3 requests)           │
│                                                                             │
│  Quorum: Chair + 4 members (must include CISO and CMO for clinical AI)     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Use Case Intake Process

Every AI initiative must complete an intake form before procurement or development:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI USE CASE INTAKE                                   │
│                                                                             │
│  1. REQUESTOR SUBMITS INTAKE FORM                                          │
│     • Business problem and proposed AI solution                            │
│     • Data inputs (what data will the AI access?)                          │
│     • Outputs and decisions (what will the AI produce?)                    │
│     • Users (who interacts with it? patients? clinicians?)                 │
│     • Vendor or build (if vendor, which one?)                              │
│                                                                             │
│  2. SECURITY TEAM ASSIGNS TIER (48 hours)                                  │
│     • Applies risk scoring matrix                                          │
│     • Flags edge cases for Governance Board                                │
│                                                                             │
│  3. TIER-APPROPRIATE REVIEW                                                │
│     • Tier 1: Security checklist → Department head approval                │
│     • Tier 2: Security assessment → CISO + Privacy approval                │
│     • Tier 3: Full assessment → Governance Board approval                  │
│                                                                             │
│  4. CONDITIONAL APPROVAL                                                   │
│     • Technical controls required before deployment                        │
│     • Monitoring requirements documented                                    │
│     • Review schedule set                                                   │
│                                                                             │
│  5. DEPLOYMENT + REGISTRY                                                  │
│     • Added to AI inventory                                                │
│     • Owner accountable for ongoing compliance                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### AI Inventory Requirements

Every approved AI system must be registered with:

| Field | Purpose |
|-------|---------|
| System name | Identification |
| Business owner | Accountability |
| Technical owner | Operational contact |
| Tier classification | Risk level |
| Data inputs | What data it accesses |
| Data outputs | What it produces |
| Users | Who interacts with it |
| Vendor (if applicable) | Third-party risk tracking |
| Model type | LLM, ML, rule-based |
| Deployment date | Timeline tracking |
| Last review date | Compliance tracking |
| Next review date | Triggers re-assessment |
| Status | Active, pilot, deprecated |

### Ongoing Monitoring Ownership

| Responsibility | Owner | Cadence |
|----------------|-------|---------|
| Model performance monitoring | Technical owner | Continuous |
| Output quality sampling | Business owner | Weekly (Tier 3), Monthly (Tier 2) |
| Security control validation | Security team | Quarterly |
| Compliance attestation | Business owner + Legal | Annual |
| Incident response | CISO + relevant stakeholders | As needed |
| Re-tiering assessment | Security team | Triggered by material change |

**Material changes requiring re-assessment:**
- New data sources added
- New user populations
- Scope expansion (e.g., pilot → production)
- Vendor model updates
- Regulatory changes

## Consequences

### Positive

- **Board-ready answer:** CISO can report AI inventory, risk distribution, and control status
- **Speed for low-risk:** Tier 1 projects deploy in days, not months
- **Rigor for high-risk:** Tier 3 projects get appropriate scrutiny without blocking Tier 1
- **Shadow AI prevention:** Clear intake process beats "just use ChatGPT"
- **Regulatory defensibility:** Documented governance satisfies auditors
- **Accountability:** Every AI system has an owner

### Negative

- **Process overhead:** Intake form adds friction (mitigated by fast-track for Tier 1)
- **Governance Board time:** Monthly meetings require executive commitment
- **Tier disputes:** Some teams will argue for lower tiers (escalation path needed)

### Cost

| Component | Effort |
|-----------|--------|
| Governance Board meetings | 2 hours/month per member |
| Security tier assessment | 2-4 hours per intake |
| Full Tier 3 assessment | 20-40 hours |
| Inventory maintenance | 0.25 FTE ongoing |

**vs. Risk:** One PHI breach from unvetted AI: $1M+ in fines, legal fees, remediation. One clinical AI error reaching a patient: incalculable.

## NIST AI RMF Mapping

| NIST AI RMF Function | This ADR Addresses |
|----------------------|-------------------|
| **GOVERN 1.1** — Legal and regulatory requirements identified | Compliance mapping in tier definitions |
| **GOVERN 1.2** — Trustworthy AI characteristics integrated | Risk scoring includes safety, privacy, fairness considerations |
| **GOVERN 2.1** — Roles and responsibilities defined | Governance Board, owners, reviewers |
| **GOVERN 2.2** — Training and awareness | Intake process educates requestors |
| **GOVERN 3.1** — Decision-making processes documented | Tier-based approval matrix |
| **GOVERN 4.1** — Organizational practices documented | This ADR + intake process |
| **GOVERN 5.1** — Policies for third-party AI | Vendor assessment in intake |
| **MAP 1.1** — Intended purpose documented | Intake form captures use case |
| **MAP 2.1** — Users identified | Intake form captures users |
| **MAP 3.1** — AI benefits and costs assessed | ROI validation in Tier 3 |
| **MEASURE 2.1** — AI system monitored | Ongoing monitoring ownership |
| **MANAGE 1.1** — AI risks prioritized | Tier classification |
| **MANAGE 2.1** — Strategies to maximize benefits | Fast-track for low-risk enables innovation |

## HIPAA Considerations

| HIPAA Requirement | Governance Implication |
|-------------------|----------------------|
| §164.308(a)(1) — Risk analysis | Tier assessment = AI-specific risk analysis |
| §164.308(a)(2) — Assigned responsibility | Business and technical owners documented |
| §164.308(a)(8) — Evaluation | Ongoing monitoring + periodic reviews |
| §164.312(a)(1) — Access controls | Data inputs documented; controls required before deployment |
| §164.312(b) — Audit controls | Inventory enables audit trail |
| §164.314(a) — Business associate contracts | Vendor AI requires BAA review |

## MedAssist AI Use Case Tier Assignments

| Use Case | Data Sensitivity | Decision Impact | Tier |
|----------|------------------|-----------------|------|
| Clinical decision support | High (PHI) | High (clinical) | **3** |
| Patient chatbot (scheduling) | Medium (appointments) | Medium (operational) | **2** |
| Revenue cycle automation | High (PHI + financial) | High (financial) | **3** |
| Internal HR/IT copilot | Medium (employee data) | Low (productivity) | **1** |
| Clinical trial matching | High (PHI) | High (research/FDA) | **3** |
| Research copilot (de-identified) | Medium (de-identified) | Medium (research) | **2** |
| Real-world evidence generation | High (re-identification risk) | High (regulatory) | **3** |

## Alternatives Considered

### Alternative 1: No Tiering (All AI Through Governance Board)

**Rejected because:**
- Creates bottleneck for low-risk projects
- Board time wasted on trivial decisions
- Slows innovation, pushes teams to shadow AI

### Alternative 2: Security Team Owns All Decisions

**Rejected because:**
- Clinical and research AI need domain expertise
- Security team lacks authority over business decisions
- Creates adversarial dynamic

### Alternative 3: Department-Level Governance Only

**Rejected because:**
- Inconsistent standards across organization
- No visibility for board/executives
- Compliance gaps when projects span departments

## References

- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [HHS HIPAA and AI Guidance](https://www.hhs.gov/hipaa/index.html)
- [FDA Guidance on AI/ML in Medical Devices](https://www.fda.gov/medical-devices/software-medical-device-samd/artificial-intelligence-and-machine-learning-software-medical-device)
- [White House Executive Order on AI Safety (Oct 2023)](https://www.whitehouse.gov/briefing-room/presidential-actions/2023/10/30/executive-order-on-the-safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence/)
EOFcat > ai-security/docs/decisions/001-ai-governance-and-risk-tiering.md << 'EOF'
# ADR-001: AI Governance and Risk Tiering

## Status
Accepted

## Context

MedAssist Health System is a regional healthcare organization (5 hospitals, 40 clinics, 8,000 employees) undergoing rapid AI adoption. Multiple business units are pursuing AI initiatives simultaneously:

| Domain | Use Cases | Requesting Teams |
|--------|-----------|------------------|
| Clinical | Decision support, patient chatbot | CMO, Digital Health |
| Operations | Revenue cycle, internal copilot | CFO, HR, IT |
| Research | Trial matching, evidence generation | Research, Partnerships |

Current state problems:
- No centralized visibility into AI projects (shadow AI emerging)
- Each team evaluating vendors independently (duplicated effort, inconsistent security)
- Legal and Compliance reviewing AI contracts ad-hoc (bottleneck)
- Board asking "what's our AI risk exposure?" — CISO cannot answer
- No framework to differentiate a low-risk FAQ bot from a high-risk diagnostic assistant

The organization needs a governance structure that:
1. Enables innovation (not a "Department of No")
2. Provides risk-appropriate oversight (not one-size-fits-all)
3. Creates accountability without bureaucracy
4. Satisfies regulatory expectations (HIPAA, state AI laws, future federal requirements)
5. Gives the board a defensible answer on AI risk

### The Real Problem

Without governance, MedAssist faces two failure modes:

**Failure Mode 1: Move too fast**
- Team deploys patient-facing chatbot without security review
- Chatbot leaks PHI or hallucinates medical advice
- OCR investigation, class action, board terminations

**Failure Mode 2: Move too slow**
- Every AI project requires 6-month legal review
- Competitors deploy AI-assisted scheduling, billing, clinical tools
- MedAssist loses physicians, patients, and market position

**The goal:** A governance framework that routes low-risk projects through fast lanes while applying rigorous oversight to high-risk deployments.

## Decision

### Establish Three-Tier AI Risk Classification

Not all AI is equal. A chatbot answering "what are your visiting hours?" is not the same as an AI suggesting a cancer diagnosis.
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI RISK TIERING MODEL                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 3: CRITICAL RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Clinical decision support (diagnosis, treatment)                         │
│  • AI accessing/generating PHI                                              │
│  • Patient-facing with health implications                                  │
│  • Research affecting FDA submissions                                       │
│                                                                             │
│  Approval: AI Governance Board + CISO + CMO + Legal                        │
│  Review cycle: Quarterly                                                    │
│  Time to approve: 4-8 weeks                                                 │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 2: ELEVATED RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Internal copilots with access to sensitive data                         │
│  • Revenue cycle / billing automation                                       │
│  • Patient-facing without health implications (scheduling, FAQs)           │
│  • Research on de-identified data                                          │
│                                                                             │
│  Approval: CISO + Data Privacy Officer                                     │
│  Review cycle: Semi-annual                                                  │
│  Time to approve: 2-4 weeks                                                 │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 1: STANDARD RISK                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━                                                      │
│  • Internal productivity tools (no sensitive data)                         │
│  • Code assistants for IT                                                   │
│  • Marketing content generation                                            │
│  • Training material development                                           │
│                                                                             │
│  Approval: Department head + Security checklist                            │
│  Review cycle: Annual attestation                                          │
│  Time to approve: 1 week                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Risk Scoring Matrix

Tier assignment is based on two dimensions:

| | Low Data Sensitivity | Medium Data Sensitivity | High Data Sensitivity (PHI) |
|---|---|---|---|
| **High Decision Impact** (clinical, financial) | Tier 2 | Tier 3 | Tier 3 |
| **Medium Decision Impact** (operational) | Tier 1 | Tier 2 | Tier 3 |
| **Low Decision Impact** (productivity) | Tier 1 | Tier 1 | Tier 2 |

**Data Sensitivity:**
- Low: Public information, general business data
- Medium: Internal policies, non-PHI employee data, de-identified datasets
- High: PHI, PII, research data with re-identification risk

**Decision Impact:**
- Low: Affects individual productivity, easily reversible
- Medium: Affects business operations, financial implications
- High: Affects patient care, clinical decisions, regulatory submissions

### AI Governance Board Structure
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI GOVERNANCE BOARD                                  │
│                                                                             │
│  Chair: Chief AI Officer (or CIO if no CAIO)                               │
│                                                                             │
│  Standing Members:                                                          │
│  ├── CISO — Security and technical risk                                    │
│  ├── Chief Medical Officer — Clinical safety and efficacy                  │
│  ├── Chief Privacy Officer — HIPAA, state privacy laws                     │
│  ├── General Counsel — Liability, contracts, regulatory                    │
│  ├── Chief Research Officer — Research integrity, FDA compliance           │
│  └── CFO or delegate — Budget, ROI validation                              │
│                                                                             │
│  Meeting Cadence: Monthly (or ad-hoc for urgent Tier 3 requests)           │
│                                                                             │
│  Quorum: Chair + 4 members (must include CISO and CMO for clinical AI)     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Use Case Intake Process

Every AI initiative must complete an intake form before procurement or development:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI USE CASE INTAKE                                   │
│                                                                             │
│  1. REQUESTOR SUBMITS INTAKE FORM                                          │
│     • Business problem and proposed AI solution                            │
│     • Data inputs (what data will the AI access?)                          │
│     • Outputs and decisions (what will the AI produce?)                    │
│     • Users (who interacts with it? patients? clinicians?)                 │
│     • Vendor or build (if vendor, which one?)                              │
│                                                                             │
│  2. SECURITY TEAM ASSIGNS TIER (48 hours)                                  │
│     • Applies risk scoring matrix                                          │
│     • Flags edge cases for Governance Board                                │
│                                                                             │
│  3. TIER-APPROPRIATE REVIEW                                                │
│     • Tier 1: Security checklist → Department head approval                │
│     • Tier 2: Security assessment → CISO + Privacy approval                │
│     • Tier 3: Full assessment → Governance Board approval                  │
│                                                                             │
│  4. CONDITIONAL APPROVAL                                                   │
│     • Technical controls required before deployment                        │
│     • Monitoring requirements documented                                    │
│     • Review schedule set                                                   │
│                                                                             │
│  5. DEPLOYMENT + REGISTRY                                                  │
│     • Added to AI inventory                                                │
│     • Owner accountable for ongoing compliance                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### AI Inventory Requirements

Every approved AI system must be registered with:

| Field | Purpose |
|-------|---------|
| System name | Identification |
| Business owner | Accountability |
| Technical owner | Operational contact |
| Tier classification | Risk level |
| Data inputs | What data it accesses |
| Data outputs | What it produces |
| Users | Who interacts with it |
| Vendor (if applicable) | Third-party risk tracking |
| Model type | LLM, ML, rule-based |
| Deployment date | Timeline tracking |
| Last review date | Compliance tracking |
| Next review date | Triggers re-assessment |
| Status | Active, pilot, deprecated |

### Ongoing Monitoring Ownership

| Responsibility | Owner | Cadence |
|----------------|-------|---------|
| Model performance monitoring | Technical owner | Continuous |
| Output quality sampling | Business owner | Weekly (Tier 3), Monthly (Tier 2) |
| Security control validation | Security team | Quarterly |
| Compliance attestation | Business owner + Legal | Annual |
| Incident response | CISO + relevant stakeholders | As needed |
| Re-tiering assessment | Security team | Triggered by material change |

**Material changes requiring re-assessment:**
- New data sources added
- New user populations
- Scope expansion (e.g., pilot → production)
- Vendor model updates
- Regulatory changes

## Consequences

### Positive

- **Board-ready answer:** CISO can report AI inventory, risk distribution, and control status
- **Speed for low-risk:** Tier 1 projects deploy in days, not months
- **Rigor for high-risk:** Tier 3 projects get appropriate scrutiny without blocking Tier 1
- **Shadow AI prevention:** Clear intake process beats "just use ChatGPT"
- **Regulatory defensibility:** Documented governance satisfies auditors
- **Accountability:** Every AI system has an owner

### Negative

- **Process overhead:** Intake form adds friction (mitigated by fast-track for Tier 1)
- **Governance Board time:** Monthly meetings require executive commitment
- **Tier disputes:** Some teams will argue for lower tiers (escalation path needed)

### Cost

| Component | Effort |
|-----------|--------|
| Governance Board meetings | 2 hours/month per member |
| Security tier assessment | 2-4 hours per intake |
| Full Tier 3 assessment | 20-40 hours |
| Inventory maintenance | 0.25 FTE ongoing |

**vs. Risk:** One PHI breach from unvetted AI: $1M+ in fines, legal fees, remediation. One clinical AI error reaching a patient: incalculable.

## NIST AI RMF Mapping

| NIST AI RMF Function | This ADR Addresses |
|----------------------|-------------------|
| **GOVERN 1.1** — Legal and regulatory requirements identified | Compliance mapping in tier definitions |
| **GOVERN 1.2** — Trustworthy AI characteristics integrated | Risk scoring includes safety, privacy, fairness considerations |
| **GOVERN 2.1** — Roles and responsibilities defined | Governance Board, owners, reviewers |
| **GOVERN 2.2** — Training and awareness | Intake process educates requestors |
| **GOVERN 3.1** — Decision-making processes documented | Tier-based approval matrix |
| **GOVERN 4.1** — Organizational practices documented | This ADR + intake process |
| **GOVERN 5.1** — Policies for third-party AI | Vendor assessment in intake |
| **MAP 1.1** — Intended purpose documented | Intake form captures use case |
| **MAP 2.1** — Users identified | Intake form captures users |
| **MAP 3.1** — AI benefits and costs assessed | ROI validation in Tier 3 |
| **MEASURE 2.1** — AI system monitored | Ongoing monitoring ownership |
| **MANAGE 1.1** — AI risks prioritized | Tier classification |
| **MANAGE 2.1** — Strategies to maximize benefits | Fast-track for low-risk enables innovation |

## HIPAA Considerations

| HIPAA Requirement | Governance Implication |
|-------------------|----------------------|
| §164.308(a)(1) — Risk analysis | Tier assessment = AI-specific risk analysis |
| §164.308(a)(2) — Assigned responsibility | Business and technical owners documented |
| §164.308(a)(8) — Evaluation | Ongoing monitoring + periodic reviews |
| §164.312(a)(1) — Access controls | Data inputs documented; controls required before deployment |
| §164.312(b) — Audit controls | Inventory enables audit trail |
| §164.314(a) — Business associate contracts | Vendor AI requires BAA review |

## MedAssist AI Use Case Tier Assignments

| Use Case | Data Sensitivity | Decision Impact | Tier |
|----------|------------------|-----------------|------|
| Clinical decision support | High (PHI) | High (clinical) | **3** |
| Patient chatbot (scheduling) | Medium (appointments) | Medium (operational) | **2** |
| Revenue cycle automation | High (PHI + financial) | High (financial) | **3** |
| Internal HR/IT copilot | Medium (employee data) | Low (productivity) | **1** |
| Clinical trial matching | High (PHI) | High (research/FDA) | **3** |
| Research copilot (de-identified) | Medium (de-identified) | Medium (research) | **2** |
| Real-world evidence generation | High (re-identification risk) | High (regulatory) | **3** |

## Alternatives Considered

### Alternative 1: No Tiering (All AI Through Governance Board)

**Rejected because:**
- Creates bottleneck for low-risk projects
- Board time wasted on trivial decisions
- Slows innovation, pushes teams to shadow AI

### Alternative 2: Security Team Owns All Decisions

**Rejected because:**
- Clinical and research AI need domain expertise
- Security team lacks authority over business decisions
- Creates adversarial dynamic

### Alternative 3: Department-Level Governance Only

**Rejected because:**
- Inconsistent standards across organization
- No visibility for board/executives
- Compliance gaps when projects span departments

## References

- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [HHS HIPAA and AI Guidance](https://www.hhs.gov/hipaa/index.html)
- [FDA Guidance on AI/ML in Medical Devices](https://www.fda.gov/medical-devices/software-medical-device-samd/artificial-intelligence-and-machine-learning-software-medical-device)
- [White House Executive Order on AI Safety (Oct 2023)](https://www.whitehouse.gov/briefing-room/presidential-actions/2023/10/30/executive-order-on-the-safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence/)
