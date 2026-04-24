**To:** Quentin Halsey
**From:** Eric Halsey
**Date:** 2026-04-23
**Subject:** Re: Apollo — third-party app revoked; we found Apollo cold mail is going out as @a-cto.com

Quentin,

### TL;DR

- The "Apollo.io (Dev - Chemi)" app is **revoked, done** — no action needed on your side, no reconnect needed.
- But while looking into it, I found that **some of Apollo's cold outreach is being sent as `@a-cto.com`**, not `@a-cto.co`. That's the opposite of what we set up `.co` to do.
- I need you to check one thing in Apollo's settings (below) so we can figure out whether to fix it on Apollo's side or on our DNS side.

### What I need you to do in Apollo

Open Apollo and go to **Settings → Email → Sending Profiles** (some accounts call this **Verified Domains** or **Email Sending Domains**).

1. Look at the list of **verified sending domains**. Tell me whether `a-cto.com` is listed there (alongside or instead of `a-cto.co`).
2. If `a-cto.com` IS listed, look at any **sequences** or **sender identities** that are tied to it — is anything actively sending from `@a-cto.com` (e.g., `quentin@a-cto.com`, `quentin.halsey@a-cto.com`, or something else)?
3. Let me know what you find. Most likely it's a leftover from before we set up `.co` and we just need to delete the `a-cto.com` verified domain in Apollo and switch any sender identities to `@a-cto.co`.

Once I hear back, I'll clean up the matching DNS records on our side so Apollo can no longer send under `@a-cto.com` even by accident.

### Background — what we saw

When you set up Apollo to send cold outreach from a custom domain, Apollo gives you some DNS records to add. Those records prove to email providers (Gmail, Outlook, etc.) that Apollo is allowed to send mail "as" your domain.

Those records currently exist for **a-cto.com**, not **a-cto.co**. So when Apollo's servers send a cold email and stamp it `From: @a-cto.com`, Gmail and Outlook accept it as legitimate — and any spam complaints, bounces, or low-engagement signals land on **a-cto.com's** sender reputation, which is exactly what we created `.co` to avoid.

Looking at the last few days of delivery data, I can see at least 3 examples of Apollo sending from `@a-cto.com` via Apollo's own infrastructure (not through your Outlook). Volume is small so far, but we should fix it before you ramp up further.

The most likely scenarios are:
- **(A) Stale leftover.** The `a-cto.com` setup in Apollo predates the `.co` move, was never deleted, and is being picked up automatically. Easy fix: delete it in Apollo, I remove the matching DNS records.
- **(B) Intentional dual-domain setup.** You're sending some sequences from each domain on purpose. In that case we leave it alone — but I'd want to know that's the design.

### #2 — Dev-Chemi revoked, details

The `user_impersonation` permission on that "Apollo.io (Dev - Chemi)" app was for **Dataverse** (Microsoft's Power Platform / Dynamics database), not your mailbox — so revoking it doesn't touch your Apollo → Outlook integration at all. No reconnect, no resync needed.

What I did:
- Disabled the app
- Deleted both permission grants
- Removed your user assignment
- Left the app object in place (not deleted) in case it ever turns out to be something we want back

Your real Apollo integration (the one that connects to your `quentin@a-cto.co` mailbox) is a totally separate app, owned by Apollo.io's actual company tenant, and is untouched.

Logged in GitHub issue #5 for the record.

Eric
