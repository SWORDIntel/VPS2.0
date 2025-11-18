# Mattermost Boards - Investigation Knowledge Base

## Overview

Mattermost Boards (Focalboard) provides a flexible knowledge management system for security investigations, vulnerability tracking, and threat intelligence. These board templates are designed to integrate with Playbooks for comprehensive incident response and investigation workflows.

## Available Templates

### 1. CVE Vulnerability Tracker (`cve-vulnerability-tracker.json`)

**Purpose**: Track and prioritize CVE analysis, patching, and remediation across VPS2.0 infrastructure.

**Features**:
- **Severity-based prioritization** (Critical, High, Medium, Low, Info)
- **CVSS score tracking** for quantitative risk assessment
- **Exploit status monitoring** (Active ITW, PoC Available, No Known Exploit)
- **System-specific tracking** (DNS Hub, Mattermost, HURRICANE, ARTICBASTION, etc.)
- **Patch status workflow** (Available, In Progress, Workaround Applied, No Patch)
- **Integration links** to GitLab issues, NVD database, Playbook runs

**Views**:
- **By Severity**: Kanban board grouped by severity level
- **By System**: See all vulnerabilities affecting each component
- **Active Exploits**: Filtered table view for ITW exploits requiring immediate action
- **Remediation Timeline**: Calendar view for patch deployment deadlines

**Workflow Example**:
1. New CVE discovered → Create card with CVE ID and CVSS score
2. Analyze affected systems → Tag relevant VPS2.0 components
3. Check exploit status → Monitor for PoC/ITW exploitation
4. Create GitLab issue → Link to tracking issue for patch deployment
5. Start playbook run → Use "Emergency Security Patch Deployment" playbook
6. Apply patch/workaround → Update patch status
7. Close card → Move to archive when remediation complete

---

### 2. Threat Intelligence Database (`threat-intelligence.json`)

**Purpose**: Maintain a living database of threat actors, campaigns, TTPs, and indicators of compromise relevant to VPS2.0 operations.

**Features**:
- **Threat categorization** (APT Groups, Ransomware, Malware, Phishing, Supply Chain, Insider)
- **Confidence levels** (Confirmed, Probable, Possible, Unconfirmed)
- **Targeting analysis** (Defense, Government, Tech, Finance, Healthcare, Infrastructure)
- **MITRE ATT&CK mapping** (All 11 tactics from Initial Access to Impact)
- **IOC tracking** (IPs, Domains, File Hashes, URLs, Email, Registry Keys)
- **VPS2.0 relevance flag** for quick filtering

**Views**:
- **By Threat Type**: Organize by threat category
- **APT Groups**: Dedicated view for advanced persistent threats
- **Relevant to VPS2.0**: Gallery view of threats directly applicable to infrastructure
- **Recent Activity**: Timeline of threat actor activity

**Workflow Example**:
1. Intel received from OSINT/feeds → Create card for threat actor/campaign
2. Analyze TTPs → Map to MITRE ATT&CK tactics
3. Extract IOCs → Document IP addresses, domains, file hashes
4. Assess relevance → Check if targeting matches VPS2.0 profile
5. Flag for action → If relevant, mark and assign analyst
6. Update regularly → Track last activity date and campaign evolution
7. Link to investigations → Connect to active investigation cases if detected

---

### 3. Investigation Case Tracker (`investigation-case-tracker.json`)

**Purpose**: Track security investigations, incident analysis, and forensic cases from initial detection through closure.

**Features**:
- **Case workflow** (New → Investigating → Evidence Collection → Analysis → Remediation → Closed)
- **Priority levels** (P0 Critical, P1 High, P2 Medium, P3 Low)
- **Case types** (Intrusion, Malware, Data Exfil, Insider, Policy Violation, Vulnerability, Threat Hunt)
- **Team coordination** (Lead Investigator, Team Members from SecOps/IR/Forensics/Legal/Engineering)
- **Asset tracking** (All VPS2.0 components)
- **Evidence checklist** (Preserved, Forensic Images, Timeline, Root Cause)
- **Integration** with Playbook runs and GitLab tracking issues

**Views**:
- **Active Cases**: Kanban workflow excluding closed cases
- **By Priority**: Group by P0/P1/P2/P3 for resource allocation
- **P0 Critical Cases**: Dedicated table for highest priority investigations
- **Evidence Checklist**: Track forensic evidence collection progress
- **Timeline View**: Calendar of incident timestamps
- **Closed Cases Archive**: Historical case repository

**Workflow Example**:
1. Alert/detection → Create new case card with Case ID
2. Assign lead investigator → Set priority (P0-P3)
3. Start playbook → Launch "P0 Incident Response" playbook
4. Collect evidence → Check off: Evidence preserved, Forensic images acquired
5. Build timeline → Document incident timeline, check "Timeline Complete"
6. Analyze → Identify root cause, check "Root Cause Identified"
7. Remediate → Execute fixes, move to Remediation status
8. Close case → Document closure date, move to Closed status
9. Archive → Case automatically appears in "Closed Cases Archive" view

---

## Installation & Import

### 1. Enable Boards Plugin

The Boards plugin is installed automatically via `scripts/mattermost/install-plugins.sh`:

```bash
./scripts/mattermost/install-plugins.sh
```

This will:
- Check if Boards/Focalboard is already installed
- Enable the plugin if present
- Install from marketplace if needed

### 2. Import Templates

**Via Mattermost UI**:

1. Navigate to **Boards** in left sidebar
2. Click **+ New Board**
3. Select **Use a template** → **Import**
4. Upload one of the JSON files from this directory
5. Customize board name and permissions

**Via API** (for automation):

```bash
#!/usr/bin/env bash

MATTERMOST_URL="https://mattermost.swordintelligence.airforce"
ADMIN_TOKEN="your-admin-token"
TEAM_ID="your-team-id"

# Import CVE Vulnerability Tracker
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @cve-vulnerability-tracker.json \
  "$MATTERMOST_URL/plugins/focalboard/api/v2/teams/$TEAM_ID/boards"

# Import Threat Intelligence Database
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @threat-intelligence.json \
  "$MATTERMOST_URL/plugins/focalboard/api/v2/teams/$TEAM_ID/boards"

# Import Investigation Case Tracker
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @investigation-case-tracker.json \
  "$MATTERMOST_URL/plugins/focalboard/api/v2/teams/$TEAM_ID/boards"
```

---

## Recommended Workflows

### Integrated Incident Response Workflow

Combine **Boards + Playbooks + GitLab** for comprehensive incident management:

1. **Detection** → Create Investigation Case card (Investigation Case Tracker)
2. **Initiate Response** → Start P0 Incident Response Playbook
3. **Track Work** → Create GitLab issue for remediation tasks
4. **Knowledge Base** → Link relevant threat intel from Threat Intelligence Database
5. **Vulnerability Context** → Link related CVE cards if patch-related
6. **Evidence** → Check off evidence collection in Investigation Case
7. **Timeline** → Use Calendar view to build incident timeline
8. **Close** → Mark playbook complete, close GitLab issue, archive case

### CVE Response Workflow

1. **CVE Published** → Create card in CVE Vulnerability Tracker
2. **Analyze** → Determine affected VPS2.0 systems
3. **Prioritize** → Set severity based on CVSS + exploit status
4. **Track** → Create GitLab issue for patch deployment
5. **Execute** → Start "Emergency Security Patch Deployment" playbook
6. **Deploy** → Apply patch, update status to "Patch Applied"
7. **Verify** → Confirm remediation
8. **Archive** → Close card when complete

### Threat Hunting Workflow

1. **Intelligence** → Review Threat Intelligence Database for relevant threats
2. **Hypothesis** → Create Investigation Case (Type: Threat Hunt)
3. **Hunt** → Search logs, network traffic for IOCs
4. **Document** → Update case with findings
5. **Escalate** → If threat detected, elevate to P0/P1 and start incident playbook
6. **Close** → Document as False Positive or successful detection

---

## Board Permissions & Teams

### Recommended Setup

Create dedicated teams/channels for each board type:

```bash
# Investigation Response Team (already created by install-plugins.sh)
# Boards:
#   - Investigation Case Tracker (Private to IR team)
#   - CVE Vulnerability Tracker (Shared with Engineering)

# Threat Intelligence Team
# Boards:
#   - Threat Intelligence Database (Shared read-only with all teams)
#   - Investigation Case Tracker (Link to active cases)

# Security Operations Team
# Boards:
#   - All three boards (Read/Write access)
```

### Permission Levels

- **Private**: Only team members can view/edit (default for Investigation Cases)
- **Team**: All team members can view, selected can edit (recommended for CVE Tracker)
- **Public**: Anyone can view, team can edit (recommended for Threat Intel - read-only)

---

## Integration with Other VPS2.0 Components

### GitLab Integration

Link board cards to GitLab issues:

```markdown
# In board card:
**GitLab Issue**: https://gitlab.swordintelligence.airforce/vps2.0/issues/123

# In GitLab issue:
**Tracking Board**: [CVE-2024-1234](https://mattermost.swordintelligence.airforce/boards/...)
```

### Playbook Integration

Link investigation cases to active playbook runs:

```markdown
# In Investigation Case card:
**Playbook Run**: https://mattermost.swordintelligence.airforce/playbooks/runs/abc123

# Playbook checklist item:
- [ ] Update Investigation Case Tracker (Case ID: INV-2024-042)
```

### Prometheus/AlertManager Integration

Create investigation cases from alerts:

1. AlertManager fires critical alert → #alerts channel
2. Analyst triages → Creates Investigation Case card
3. Links alert to case → Documents initial detection vector
4. Starts playbook → P0 Incident Response
5. Updates case → Tracks evidence collection and remediation

### Grafana Dashboards

Link to relevant dashboards in Investigation Cases:

```markdown
# In Investigation Case card:
**Monitoring Dashboard**: https://grafana.swordintelligence.airforce/d/incident-metrics
```

---

## Best Practices

### Consistent Naming

- **Case IDs**: `INV-YYYY-NNN` (e.g., INV-2024-042)
- **CVE Cards**: Use official CVE ID as card title (e.g., "CVE-2024-1234")
- **Threat Actors**: Use MITRE/industry naming (e.g., "APT28", "Lazarus Group")

### Regular Updates

- **Daily**: Update active investigation cases with progress
- **Weekly**: Review CVE Vulnerability Tracker, check for new patches
- **Monthly**: Audit Threat Intelligence Database, archive stale threats

### Evidence Chain of Custody

For Investigation Cases:

1. **Preserve immediately** → Check "Evidence Preserved" within 1 hour
2. **Document collection** → Note forensic image acquisition timestamp
3. **Secure storage** → Store images in encrypted, access-controlled location
4. **Track access** → Log who accessed evidence in card comments
5. **Maintain integrity** → Verify checksums before analysis

### Cross-Linking

Maximize knowledge graph by linking related cards:

- CVE cards → Link to Investigation Cases if exploited
- Investigation Cases → Link to Threat Intel cards for attribution
- Threat Intel → Link to CVE cards for known exploited vulnerabilities
- All cards → Link to GitLab issues and Playbook runs

---

## Customization

### Adding Custom Properties

Edit JSON templates to add VPS2.0-specific properties:

```json
{
  "id": "custom_property",
  "name": "Custom Property Name",
  "type": "select",  // or "text", "number", "date", "checkbox", "url", "person", "multiSelect"
  "options": [
    {
      "id": "option1",
      "value": "Option 1",
      "color": "propColorBlue"
    }
  ]
}
```

### Creating New Views

Add specialized views for your workflow:

```json
{
  "title": "High CVSS + Active Exploit",
  "viewType": "table",
  "sortOptions": [
    {
      "propertyId": "cvss_score",
      "reversed": true
    }
  ],
  "filter": {
    "filters": [
      {
        "propertyId": "cvss_score",
        "condition": "greaterThan",
        "values": ["7.0"]
      },
      {
        "propertyId": "exploit_status",
        "condition": "includes",
        "values": ["active_exploit"]
      }
    ]
  }
}
```

---

## Backup & Export

### Automated Backup

Boards are backed up automatically via `scripts/mattermost/backup.sh`:

```bash
# Backup includes:
#   - Database (includes boards data)
#   - Mattermost data directory (includes uploaded files)
#   - MinIO object storage (includes board attachments)

./scripts/mattermost/backup.sh
```

### Manual Export

Export individual boards for archival:

1. Open board
2. Click **...** menu → **Export**
3. Choose format: **JSON** (for re-import), **CSV** (for spreadsheets), **Archive** (with attachments)

---

## Troubleshooting

### Boards Plugin Not Showing

```bash
# Check plugin status
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://mattermost.swordintelligence.airforce/api/v4/plugins | jq '.active[] | select(.id | contains("focalboard"))'

# Enable manually
docker exec mattermost mmctl plugin enable focalboard --local
```

### Import Fails

- **Issue**: JSON parse error
- **Fix**: Validate JSON with `jq . < template.json`

- **Issue**: Permission denied
- **Fix**: Ensure admin token has `manage_system` permission

### Board Not Syncing

- **Issue**: Changes not appearing for other users
- **Fix**: Check WebSocket connection (Caddy configuration at mattermost.swordintelligence.airforce:443)

---

## Support & Documentation

- **Mattermost Boards Docs**: https://docs.mattermost.com/boards/overview.html
- **Focalboard GitHub**: https://github.com/mattermost/focalboard
- **VPS2.0 Mattermost Docs**: `docs/MATTERMOST.md`

---

## Future Enhancements

Planned improvements for investigation knowledge base:

- [ ] **Automated CVE ingestion** from NVD feeds → Creates CVE cards automatically
- [ ] **MITRE ATT&CK matrix view** for threat intelligence
- [ ] **IOC auto-enrichment** via VirusTotal/AbuseIPDB APIs
- [ ] **Evidence upload** directly to board cards (forensic artifacts)
- [ ] **Timeline visualization** for investigation cases (integrated with logs)
- [ ] **Threat actor relationship graph** showing connections between APTs
- [ ] **Automated board reports** sent to #alerts channel daily
- [ ] **Integration with SIEM** for automatic case creation from high-severity alerts
