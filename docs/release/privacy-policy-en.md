# Privacy Policy — Lern Kalender

**Last updated:** 2026-04-09
**Provider:** Ralf Lohrmann

This Privacy Policy explains what data the **Lern Kalender** app processes, where it is stored, and who has access.

---

## 1. Data controller

Ralf Lohrmann
Heilbronner Straße 9
73728 Esslingen
Germany

Email: geldtracker.contact@gmail.com

---

## 2. What data does the app process?

### 2.1 Local data (on your device)

The following data is stored exclusively on your iPhone/iPad in the standard storage areas iOS provides for apps (`UserDefaults`, `iCloud Key-Value Store`, local file system):

- **Calendar entries** (study days, exams, reminders)
- **Subjects** and school years
- **Study sessions** and statistics
- **Grades**
- **Flashcards** and quiz results
- **Topics** and study feed content from the Hivemind area
- **App settings**

### 2.2 iCloud synchronisation

If you use the app with your iCloud account, the data listed above is also automatically synced between your devices via your private iCloud account. Apple acts as the data processor in this case. We have no access to that data — it lives exclusively in your iCloud storage and is protected by your Apple account.

### 2.3 Family feature (parent ↔ child)

If you enable the family feature and connect a parent device with a child device:

- Connecting generates a **6-digit pairing code**.
- Specific child study data (study time, grades, streak, topics, exams) is written to the public CloudKit database of the app provider so the parent device can fetch it.
- This data is only retrievable using the secret pairing code — other users have no access.
- Parents can send **topics**, **study goals**, and **motivation messages** to the child, which are also transmitted via CloudKit.

You can disconnect the family link at any time in settings.

### 2.4 AI features (beta)

The AI features of the app (AI assistant, study feed generation, quiz/flashcard creation, photo-based study plan) use the external provider **Groq, Inc.** ([https://groq.com](https://groq.com)). When you use the AI, the following data is transmitted to Groq:

- Your **input texts** (question, topic name, OCR text)
- For photo study plans: the **text recognized** by the Vision framework (the image itself never leaves your device)
- Optionally: instructions such as language, response style

Groq processes this data according to its own privacy policy ([https://groq.com/privacy-policy/](https://groq.com/privacy-policy/)).

**Important:** Do **not** store or send any sensitive personal data through the AI features.

The AI feature is optional and requires your own API key, which you store in settings.

### 2.5 Voice input

When you use voice input (in the AI assistant or Feynman mode), the **Apple Speech Recognition Framework** is used. Apple processes voice input according to its own privacy policy.

### 2.6 Photo selection

When creating a study plan or topic from a photo, the selected image is processed **locally with the Apple Vision Framework** (OCR). The image never leaves your device. Only the recognized text is sent to the AI.

---

## 3. What we do NOT do

- ❌ **No tracking** — the app uses no tracking frameworks (Google Analytics, Facebook SDK, AppsFlyer, etc.).
- ❌ **No advertising**.
- ❌ **No selling to third parties**.
- ❌ **No profile building**.
- ❌ **No location data** is collected.
- ❌ **No access to contacts, system calendar, reminders, or media library** outside of photo selections you explicitly trigger.

---

## 4. Permissions

The app only requests the following permissions — and only when you actually use the corresponding feature:

- **Microphone** — for voice input in the AI assistant and Feynman mode
- **Speech recognition** — for the same feature
- **Photos** — when you pick an image for a study plan or topic
- **Notifications** — for study reminders and parent notifications

---

## 5. Retention

- **Local data** stays on your device until you delete it or uninstall the app.
- **iCloud data** stays in your iCloud account until you delete it.
- **CloudKit data of the family feature** is removed when you disconnect the family link.
- **AI inputs at Groq** are subject to Groq's retention policies.

---

## 6. Your rights (GDPR)

As a user in the EU/EEA you have the following rights under the GDPR:

- **Right of access** to your stored data
- **Right to rectification** of inaccurate data
- **Right to erasure** of your data
- **Right to restriction** of processing
- **Right to data portability**
- **Right to object** to processing
- **Right to lodge a complaint** with a supervisory authority

Since most data lives locally on your device, you can manage it yourself via the app settings or iOS settings. For CloudKit data of the family feature, contact us at the email listed in section 1.

---

## 7. Children

The app is suitable for students of all ages. For children under 16 we recommend using it with parental consent. The family feature gives parents insight into their child's study progress.

---

## 8. Changes

This privacy policy may be updated when the app changes. The current version is linked from the app under **Settings → Privacy**.

---

## 9. Contact

For privacy questions: geldtracker.contact@gmail.com
