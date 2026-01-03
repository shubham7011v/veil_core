# System Architecture & CI/CD Documentation

This document outlines the infrastructure, deployment pipelines, and core systems implemented for the Veil (Bluff) project.

---

## 1. CI/CD Workflow (GitHub Actions)

The project uses a tag-based CI/CD pipeline defined in [deploy.yml](file:///c:/Users/u32n08/Documents/veil_core/.github/workflows/deploy.yml). It distinguishes between simple development builds and official Play Store releases.

### Trigger Logic
Deployment is triggered by pushing a version tag (e.g., `v1.0.0-dev`).

| Tag Pattern | Build Type | Target Env | Play Store Track | Main Branch Required? |
| :--- | :--- | :--- | :--- | :--- |
| `v*-dev` | APK | Dev | **None** (Local Artifact) | No |
| `v*-internal` | AAB | Prod | Internal Testing | No |
| `v*-alpha` | AAB | Prod | Open Testing | No |
| `v*-beta` | AAB | Prod | Closed Testing | **Yes** |
| `v*-prod` | AAB | Prod | Production | **Yes** |

### Required GitHub Secrets
To make the pipeline work, the following secrets must be set in GitHub:
- `FIREBASE_SERVICE_ACCOUNT_DEV`: Service account JSON for the Dev project.
- `FIREBASE_SERVICE_ACCOUNT_PROD`: Service account JSON for the Prod project.
- `PLAY_STORE_SERVICE_ACCOUNT_JSON`: Service account JSON for Play Store access.
- `ANDROID_KEYSTORE_BASE64`: Base64 string of your `.jks` file.
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`: Keystore credentials.

---

## 2. Firebase & Environment Management

The app maintains strict separation between **Development** and **Production** environments.

### Project IDs
- **Dev**: `veil-dev-shubham`
- **Prod**: `veil-prod-shubham`

### Security Rules (Firestore)
Rules are managed via [firestore.rules](file:///c:/Users/u32n08/Documents/veil_core/firestore.rules). They enforce that a user can only read/write their own profile data.

**Manual Deployment**:
```powershell
firebase use [dev|prod]
firebase deploy --only firestore:rules
```

---

## 3. Cinematic Error Handling

The "Royal Court" theme extends to how errors are presented to users. Instead of technical JSON or stack traces, users see high-quality, atmospheric messages.

### ErrorMessages Utility
Located in [error_messages.dart](file:///c:/Users/u32n08/Documents/veil_core/lib/core/utils/error_messages.dart).

| Technical Error | Cinematic User Message |
| :--- | :--- |
| `permission-denied` | "The Royal Court requires your signature. Please sign in again." |
| `unavailable` (Network) | "The connection to the Court is weak. Check your internet." |
| `not-found` | "Searching for your seat in the court..." |
| Cancellation | "Sign-in was cancelled." |

### Implementation
- **AuthBloc**: Uses the utility during Google Sign-In failures.
- **ProfileBloc**: Uses the utility during profile sync or Firestore updates.
- **UI**: Displayed via floating Snackbars in the `IntroEntryPage` or `HomeScreen`.

---

## 4. Fingerprint Management

For Google Sign-In to work on Android, you must register fingerprints in the Firebase Console:

1.  **Debug**: Get from local machine using `keytool` (already provided for this machine).
2.  **Release/Upload**: Get from your `upload-keystore.jks`.
3.  **Production**: Get from **Google Play Console** > **App Integrity** > **App Signing Key**.

---

## 5. Post-Login Flow
- **SplashScreen**: Gold pulsing shield.
- **Intro Flow**: 3-screen mood setter + Google Sign-In.
- **Court Entry**: Ceramic 1.4s transition to absorb Firestore sync latency.
- **Main Lobby**: High-contrast gold/black dashboard prioritizing "PLAY ONLINE".
- **Royal Name Modal**: One-time ceremony for new users to pick a cinematic name.
