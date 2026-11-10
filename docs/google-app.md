# The install's Google app

Each install has its own Google sign-in app (doc-003 D1): a Google Cloud project with an OAuth app of type
External, published ("In production") but not submitted for Google's verification. The agent uses it to work
with a user's Gmail, Calendar, Drive, Docs and Sheets (decision-016), and in m-6 the web page's Google
sign-in will use it too (decision-012). Setting it up takes about 15 minutes in the Google Cloud console, once
per install, by whoever installs the stack. Tested on the home install in TASK-043 (project `local-ai-home`).

The console's labels below are the English ones; the Italian console shows the same pages in the same order.

## One-time setup

1. **Project.** At https://console.cloud.google.com, sign in with the account that will own the app (its
   address can appear on the consent screen). Open the project picker, choose **New project**, name it (for
   example `local-ai-home`) and select it.
2. **APIs.** **APIs & Services → Library**: enable **Gmail API**, **Google Calendar API**, **Google Drive
   API**, **Google Docs API** and **Google Sheets API**.
3. **App.** **Google Auth Platform → Get started**: app name `Local AI`, user support email (shown to users
   on the consent screen), audience **External**, developer contact email. Accept the policy and create.
4. **Branding.** Google publishes the app only with these filled in:
   - Application home page: `https://lucacaputo.github.io/local-ai-privacy-pages/`
   - Privacy policy: `https://lucacaputo.github.io/local-ai-privacy-pages/privacy.html`
   - Authorized domains: `lucacaputo.github.io`
   - **No logo.** A logo makes Google require verification before the app can be used.

   The pages (repo `lucacaputo/local-ai-privacy-pages`) are shared by every install. They say that each
   install is run by whoever installed it and that its contact is the address on the consent screen.
5. **Scopes.** **Data access → Add or remove scopes**, under "Manually add scopes":
   ```
   https://www.googleapis.com/auth/gmail.modify
   https://www.googleapis.com/auth/gmail.settings.basic
   https://www.googleapis.com/auth/calendar
   https://www.googleapis.com/auth/drive
   https://www.googleapis.com/auth/documents
   https://www.googleapis.com/auth/spreadsheets
   ```
   Then **Update** and **Save**. Not `https://mail.google.com/`: it allows deleting mail for good, which the
   agent never needs. Sign-in's own scopes (openid, email, profile) need no listing.
6. **Publish.** **Audience → Publish app → Confirm**: the status becomes **In production**. Do not submit the
   app for verification. No test users are needed once it is published.
7. **Client.** **Clients → Create client**, type **Desktop app**, name `local-ai-agent` → **Create** →
   **Download JSON**. Leave the `client_secret_*.json` file in the Windows Downloads folder.
   In m-6 the web page will add a **Web application** client for sign-in from any device; the Desktop client
   only signs in from the PC itself.

## Connecting a user's Google account

Until the web page exists (m-6), this is done on the PC, for the owner:

```powershell
spike\task-043\google-consent.ps1 -Account you@gmail.com   # opens the browser on this PC
```

It takes the newest client file from Downloads, asks for the scopes above, and keeps the client and the
user's refresh token in Credential Manager only (`local-ai/google-client`, `local-ai/google-<user>-refresh`).
`spike\task-043\trial.ps1` then hands them to that user's Google containers (decision-016).

What the user sees:

1. Google's account picker, then **"Google hasn't verified this app"**: click **Advanced → Go to Local AI
   (unsafe)**. Every user sees this once per consent; it is the price of not verifying the app (D1).
2. The list of permissions: mail (read, organise, drafts; not deleting for good), calendar, Drive, Docs,
   Sheets. **Continue.**
3. A page from the PC: "Signed in. You can close this tab."

A user can remove the access at any time at https://myaccount.google.com/permissions.

## Limits

- **100 users per app, for its whole life**, while it is unverified. Each install has its own app, so this is
  far above what one install needs.
- **Sign-ins of a published app do not expire after 7 days**, unlike an app left in Testing (D1). Checked
  from 2026-11-18 on the home install (TASK-043). If that fails, the fallback is that users work with Google
  through the sandbox's browser.
- **Company domain.** On a Google Workspace domain, the admin marks the app as trusted, so domain users can
  grant the Gmail and Drive scopes (D1; not tried yet).
