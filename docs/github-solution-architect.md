# GitHub Solutions Architect Role — Quentin Halsey

## Overview

Quentin (@qhalsey) has **write** access across all ACTO-LLC repositories. This gives him full contributor capabilities (issues, PRs, projects, wiki, push) without any destructive admin powers (no repo deletion, no settings changes, no billing, no member management).

## What was done

1. **Removed the org-level "All-repository admin" role** from Quentin via GitHub org settings
2. **Granted per-repo write access** to @qhalsey on all 29 ACTO-LLC repositories using the GitHub API
3. **Created a "Solutions Architect" team** in the org with write access on all repos (Quentin is a member)

### Why not a custom role?

Custom repository roles require a **GitHub Enterprise** plan. ACTO-LLC is on the **Free** plan, so the built-in `write` role was used instead. The write role covers all requested permissions.

### Why not team-based permissions alone?

On the GitHub Free plan, teams can only grant **read** access to private repos. Write/admin via teams requires the GitHub Team plan ($4/user/month). Per-repo direct collaborator access was used as the primary mechanism.

## Permissions Summary

| Capability | Allowed |
|------------|---------|
| Create, close, reopen, edit, label, assign issues | Yes |
| Create, move cards, manage project board columns | Yes |
| Create, review, merge pull requests | Yes |
| Clone, push, create branches | Yes |
| Edit wiki | Yes |
| Delete repositories | **No** |
| Change repo settings | **No** |
| Manage org members/billing | **No** |
| Transfer repo ownership | **No** |

## Repositories

Write access was applied to all active repos. Two archived repos (`audit-history-archive`, `www-acto-com-backup`) could not be modified and remain read-only.

`Dataverse-Credit-Card-and-Hidden-Picking-Fee` required an invitation — Quentin must accept it to gain write access there.

## Verification

```bash
gh api repos/ACTO-LLC/acto-infra/collaborators/qhalsey/permission --jq '.role_name'
# Expected: write
```

## Future Considerations

If ACTO-LLC upgrades to GitHub Team ($4/user/month), the "Solutions Architect" team already exists with write access on all repos — team-based permissions would take effect automatically, and per-repo collaborator entries could be cleaned up.
