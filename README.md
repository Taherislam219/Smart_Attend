# SmartAttend

**GPS-based smart classroom attendance management**

SmartAttend is a Flutter application backed by Supabase. It is being developed to help teachers manage semester classes and attendance, while students can request class enrollment, check in during an open attendance session, and review their attendance records.

> **Project status:** Active development. Features described below are based on the current source code. Deployment, production security policies, and end-to-end behavior still need to be verified before public release.

## Current Features

### Student
- Student registration with full name, university student ID, email, and password.
- Login with database-backed role verification.
- Password reset flow.
- Request enrollment in a class using a class join code.
- View enrollment request status and approved classes.
- GPS-based attendance check-in while a teacher's attendance session is open.
- View finalized attendance history and overall attendance summaries.

### Teacher
- Teacher login with role verification; public teacher self-registration is not provided in the current UI.
- Create and edit semester classes.
- Generate and share class join codes.
- Review and approve or reject student enrollment requests.
- Create attendance sheets and open GPS attendance sessions with a configurable radius and check-in window.
- Review attendance rosters, finalize sheets, and cancel lectures.
- Correct individual or multiple attendance records, with correction history.
- View attendance sheets and semester reports, including PDF-related functionality.

### App Experience
- Flutter Material 3 interface with a custom SmartAttend theme.
- Light/dark theme support.
- Android, iOS, desktop and web platform folders are present in the repository. Actual release builds and deployment still need platform-specific testing.

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI |
| Dart | Application logic |
| Supabase | Authentication, PostgreSQL data and backend functions |
| Geolocator | Device location for attendance check-in |
| PDF / Printing | Report generation and printing |

## Project Structure

```
lib/
  main.dart
  screens/
    auth/
    student/
    teacher/
  services/
  theme/
  utils/
assets/
  icon/
web/
android/
ios/
```

## Getting Started

### Requirements
- Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`
- VS Code or Android Studio
- A Supabase project with the required database schema, SQL functions, triggers, and access policies configured

### 1. Clone the repository

```bash
git clone https://github.com/Taherislam219/Smart_Attend.git
cd Smart_Attend
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

The application reads the following compile-time values in `lib/main.dart`:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Run locally with your own project values:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Use the Supabase Project URL and publishable key. **Never include a Supabase secret key or service-role key in a Flutter client application.** A publishable key is not a substitute for database security: configure and test Row Level Security (RLS) policies and restrict privileged operations to trusted server-side code.

### 4. Run checks

```bash
flutter analyze
flutter test
```

These commands are recommended before submitting changes. This README update does not mean the project has already passed them.

## Attendance Flow (Current App Design)

1. A teacher creates a semester class.
2. Students request to join using the class code.
3. The teacher reviews enrollment requests.
4. The teacher creates an attendance sheet and opens GPS check-in for a limited time and radius.
5. An enrolled student attempts to check in from the app.
6. The teacher reviews, corrects if necessary, and finalizes attendance.
7. Students can review finalized attendance records.

GPS is a location signal, not proof of a person's identity or a guarantee against spoofing. Attendance integrity also depends on backend authorization and database policies.

## Roadmap

- [ ] Implement one-account/one-registered-device enforcement for student accounts.
- [ ] Add a secure device registration and device-change approval process.
- [ ] Review and test Supabase RLS policies and privileged database functions.
- [ ] Complete web deployment configuration and production testing.
- [ ] Add automated tests for authentication, enrollment, and attendance flows.

### Planned: One Student Account, One Device

The next planned security improvement is **device binding**: each student account will be registered to one device at a time, and attendance actions from another device will be rejected until an authorized device-change process is completed.

This is a planned feature, not an implemented or verified capability yet. The enforcement must happen on the backend (not only in Flutter), with a secure device-registration flow, server-side checks on attendance actions, and a controlled recovery/change process.

## Security Notes

- Keep Supabase secret and service-role keys out of the client and Git history.
- Use RLS on every table exposed to the client.
- Ensure database functions validate the authenticated user, their role, enrollment, class ownership, and attendance-session state.
- Treat client-supplied GPS coordinates and device identifiers as untrusted input.
- Review production logs to ensure passwords, tokens, and unnecessary personal data are not printed.

## Development

This is an individual learning project, and it is still being improved through implementation and testing. Feedback and suggestions are welcome.

## License

No license has been added yet. Unless a license is added, standard copyright applies.
