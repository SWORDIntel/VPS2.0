# GitLab Integration Setup for Mattermost

Complete guide to integrate GitLab with Mattermost for MR notifications, issue tracking, and CI/CD alerts.

---

## Prerequisites

- GitLab instance accessible (gitlab.{DOMAIN})
- Mattermost GitLab plugin installed and enabled
- Admin access to both systems

---

## 1. Configure OAuth Application in GitLab

### Create OAuth App

1. **Go to GitLab:**
   - Navigate to: `https://gitlab.${DOMAIN}/admin/applications`
   - Or: User Settings → Applications

2. **Create New Application:**
   - Name: `Mattermost`
   - Redirect URI: `https://mattermost.swordintelligence.airforce/plugins/com.github.manland.mattermost-plugin-gitlab/oauth/complete`
   - Scopes:
     - [x] `api` - Full API access
     - [x] `read_user` - Read user information
     - [x] `read_repository` - Read repository
     - [x] `write_repository` - Write repository (for slash commands)

3. **Save Application:**
   - Copy `Application ID`
   - Copy `Secret`

---

## 2. Configure Mattermost GitLab Plugin

### Plugin Settings

1. **Go to Mattermost System Console:**
   - Navigate to: Plugins → GitLab

2. **Enter GitLab Details:**
   - GitLab URL: `https://gitlab.${DOMAIN}`
   - GitLab OAuth Client ID: `<Application ID from step 1>`
   - GitLab OAuth Client Secret: `<Secret from step 1>`

3. **Configure Webhook:**
   - Webhook Secret: `<generate random 32-char string>`
   - Copy webhook URL for next step

4. **Save Settings**

---

## 3. Create GitLab Webhook

### Project-Level Webhook

For each repository you want to monitor:

1. **Go to GitLab Project:**
   - Settings → Webhooks

2. **Add Webhook:**
   - URL: `https://mattermost.swordintelligence.airforce/plugins/com.github.manland.mattermost-plugin-gitlab/webhook`
   - Secret Token: `<Webhook secret from step 2>`
   - Trigger Events:
     - [x] Push events
     - [x] Tag push events
     - [x] Comments
     - [x] Confidential comments
     - [x] Issues events
     - [x] Confidential issues events
     - [x] Merge request events
     - [x] Pipeline events
     - [x] Wiki page events

3. **SSL Verification:** Enable
4. **Add Webhook**

### Group-Level Webhook (Optional)

To monitor all projects in a group:

1. **Go to GitLab Group:**
   - Settings → Webhooks
   - Same configuration as above

---

## 4. Connect Users

### Per-User Setup

Each Mattermost user must connect their GitLab account:

1. **In Mattermost, run:**
   ```
   /gitlab connect
   ```

2. **Authorize:**
   - Click the link provided
   - Authorize Mattermost to access GitLab
   - You'll be redirected back to Mattermost

3. **Verify Connection:**
   ```
   /gitlab me
   ```

---

## 5. Subscribe Channels to Repositories

### Subscribe to Events

In any Mattermost channel:

```bash
# Subscribe to all events from a repository
/gitlab subscribe owner/repo

# Subscribe to specific events only
/gitlab subscribe owner/repo --flags=issues,merges,pushes

# Available flags:
# - issues: Issue created, updated, closed
# - merges: Merge request opened, updated, merged, closed
# - pushes: Code pushed to branches
# - issue_comments: Comments on issues
# - merge_request_comments: Comments on MRs
# - pipeline: CI/CD pipeline status
# - tag: Tag created
# - pull_reviews: MR reviews
# - label:"labelname": Filter by label

# Example: Only critical issues and failed pipelines
/gitlab subscribe swordintel/vps2.0 --flags=issues,pipeline label:"critical"
```

### Unsubscribe

```bash
/gitlab unsubscribe owner/repo
```

### List Subscriptions

```bash
/gitlab subscriptions
```

---

## 6. Slash Commands

### Available Commands

```bash
# Connect your GitLab account
/gitlab connect

# Disconnect your GitLab account
/gitlab disconnect

# Show your GitLab account info
/gitlab me

# Subscribe channel to repo
/gitlab subscribe owner/repo

# Unsubscribe channel from repo
/gitlab unsubscribe owner/repo

# List all subscriptions in this channel
/gitlab subscriptions

# Create an issue
/gitlab issue create owner/repo "Issue title" "Issue description"

# Show issue
/gitlab issue show owner/repo 123

# Show merge request
/gitlab mr show owner/repo 456

# List your open MRs
/gitlab mrs

# List your assigned issues
/gitlab issues

# Search for issues
/gitlab search owner/repo "search query"

# Show help
/gitlab help
```

---

## 7. Recommended Channel Subscriptions

### For Incident Response Team

**#alerts channel:**
```bash
/gitlab subscribe swordintel/vps2.0 --flags=pipeline label:"critical"
/gitlab subscribe swordintel/infrastructure --flags=issues,pipeline label:"security"
```

**#p0-incidents channel:**
```bash
/gitlab subscribe swordintel/incident-response --flags=issues,merges,issue_comments
```

**#devops channel:**
```bash
/gitlab subscribe swordintel/vps2.0 --flags=merges,pipeline,pushes
/gitlab subscribe swordintel/automation --flags=merges,pipeline
```

### For Security Team

**#security channel:**
```bash
/gitlab subscribe swordintel/* --flags=issues label:"CVE"
/gitlab subscribe swordintel/* --flags=issues label:"vulnerability"
```

---

## 8. Example Workflow

### CVE Triage Workflow

1. **Security team receives CVE alert**
2. **Create GitLab issue from Mattermost:**
   ```bash
   /gitlab issue create swordintel/vps2.0 "CVE-2024-1234: RCE in Component X" "Details: ..."
   ```

3. **Issue notification appears in #security channel**
4. **Assign to engineer, add label "critical"**
5. **Engineer creates MR with fix**
6. **MR notification appears in channel**
7. **CI pipeline status updates in channel**
8. **Merge when tests pass**
9. **Issue auto-closes, notification in channel**

### Incident Response Workflow

1. **P0 incident declared in #p0-incidents**
2. **Create incident issue:**
   ```bash
   /gitlab issue create swordintel/incident-response "P0: Database breach 2024-01-15"
   ```

3. **Incident investigation tracked in issue comments**
4. **Comments appear in Mattermost channel**
5. **Create MR with remediation**
6. **Emergency merge after review**
7. **Pipeline deploys patch automatically**
8. **Close incident issue when resolved**

---

## 9. Troubleshooting

### Webhook Not Working

**Check webhook delivery:**
1. GitLab: Settings → Webhooks → Edit → Recent Deliveries
2. Look for HTTP 200 responses
3. If errors, check:
   - Webhook secret matches
   - URL is correct
   - SSL certificate is valid

**Test webhook:**
```bash
curl -X POST \
  -H "X-Gitlab-Token: YOUR_WEBHOOK_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"object_kind":"test"}' \
  https://mattermost.swordintelligence.airforce/plugins/com.github.manland.mattermost-plugin-gitlab/webhook
```

### User Can't Connect

**Check OAuth settings:**
1. System Console → Plugins → GitLab
2. Verify Client ID and Secret
3. Verify Redirect URI matches exactly

**User troubleshooting:**
```bash
# Disconnect and reconnect
/gitlab disconnect
/gitlab connect
```

### Notifications Not Appearing

**Check subscription:**
```bash
/gitlab subscriptions
```

**Check webhook events:**
- Ensure relevant events are enabled in GitLab webhook settings

**Check plugin logs:**
```bash
docker logs mattermost | grep gitlab
```

---

## 10. Security Considerations

### Access Control

- Only subscribe public channels to public repos
- Use private channels for confidential repos
- Review OAuth scopes periodically
- Rotate webhook secrets quarterly

### Audit

- Monitor which repos are subscribed to which channels
- Review user GitLab connections
- Check webhook delivery logs for suspicious activity

### Rate Limiting

- GitLab API: 600 requests/minute per user
- Webhook: No limit, but excessive events may impact performance

---

## Summary

You now have full GitLab integration with Mattermost for:
- ✅ Real-time MR/issue notifications
- ✅ CI/CD pipeline status updates
- ✅ Issue/MR creation from chat
- ✅ Channel subscriptions for repo activity
- ✅ Incident tracking workflow integration

**Next Steps:**
1. Connect all team members: `/gitlab connect`
2. Subscribe relevant channels to critical repos
3. Test workflow with a test issue/MR
4. Create incident response playbook that uses GitLab integration
