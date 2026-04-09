# Lern Kalender — Legal Website

This directory contains the legal pages for the **Lern Kalender** iOS app, served as a static site via **GitHub Pages**.

## Structure

```
docs/legal/
├── index.html          German landing page
├── index-en.html       English landing page
├── privacy-de.html     Datenschutzerklärung (DE)
├── privacy-en.html     Privacy Policy (EN)
├── terms-de.html       Nutzungsbedingungen (DE)
├── terms-en.html       Terms of Use (EN)
├── imprint.html        Impressum (DE only — German legal requirement)
├── style.css           Shared stylesheet (light + dark mode)
└── README.md           This file
```

## How to host on GitHub Pages

1. Push this repository to GitHub.
2. Open the GitHub repository → **Settings** → **Pages**.
3. Under "Build and deployment", set:
   - **Source:** Deploy from a branch
   - **Branch:** `main` (or whatever your default branch is)
   - **Folder:** `/docs`
4. Click **Save**.
5. After about a minute, GitHub publishes the site at:
   `https://<your-github-username>.github.io/<repo-name>/legal/`
6. Take that URL and put it into:
   - **App Store Connect → App Privacy → Privacy Policy URL** → use `privacy-en.html`
   - **App Store Connect → App Information → Marketing URL** (optional) → use `index-en.html`
   - The Lern Kalender Settings screen — link to the German `index.html`

## URLs you'll need

After hosting, the canonical URLs are:

- Landing (DE): `…/legal/index.html`
- Landing (EN): `…/legal/index-en.html`
- Privacy DE: `…/legal/privacy-de.html`
- Privacy EN: `…/legal/privacy-en.html` ← **submit this one to App Store Connect**
- Terms DE: `…/legal/terms-de.html`
- Terms EN: `…/legal/terms-en.html`
- Impressum: `…/legal/imprint.html`

## Updating content

Edit the HTML files directly. There is no build step. After committing and pushing, GitHub Pages rebuilds within ~1 minute.

The Markdown source documents under `docs/release/` (`privacy-policy.md`, `privacy-policy-en.md`, `imprint.md`, `terms-de.md`, `terms-en.md`) hold the same content for easier review and version control diffs.

## Disclaimer

These documents are templates that fit the typical use case of the Lern Kalender app (German developer, EU users, optional AI via Groq, CloudKit family sync, no tracking, no monetization). They should be reviewed by a German lawyer before being used in production, especially if the app starts collecting payments, adds analytics, or significantly changes its data flow.
