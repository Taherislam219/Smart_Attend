# SmartAttend

**Smart Classroom Attendance Made Simple**

SmartAttend is a Flutter application project focused on making classroom attendance easier for students and teachers. The project is currently under development as I continue learning and building with Flutter and Supabase.

## Current Project Overview

The current app includes:

- A welcome screen introducing SmartAttend.
- A role-selection screen for **Teacher** and **Student**.
- Navigation from role selection to a role-aware login screen.
- Supabase initialization in the app entry point using compile-time configuration.

> This repository is a work in progress. Authentication, attendance workflows, database integration, and other features should be considered incomplete until they are implemented and tested.

## Tech Stack

- **Flutter** — cross-platform application development
- **Dart** — application programming language
- **Supabase Flutter** — backend integration

## Getting Started

### Prerequisites

Install the following before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [VS Code](https://code.visualstudio.com/) or Android Studio
- A Supabase project

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

The app reads these compile-time values in `lib/main.dart`:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Run the app with your own Supabase project values:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Replace the placeholders with the Project URL and publishable key from your Supabase project.

**Important:** Do not put a Supabase secret key or service-role key in the Flutter app. Client applications are public environments. Configure appropriate Row Level Security (RLS) policies for every table that contains application data.

### 4. Run the project

You can also run the app from VS Code or Android Studio after configuring the required values.

## Project Structure

The project is organized around Flutter application screens and configuration files. Some of the current screen files include:

```
lib/
  main.dart
  screens/
    welcome_screen.dart
    role_selection_screen.dart
    auth/
      login_screen.dart
```

The structure may change as development continues.

## Development Status

- [x] Flutter project initialized
- [x] Supabase package added
- [x] Supabase initialization configured
- [x] Welcome screen
- [x] Teacher / Student role selection
- [ ] Complete authentication flow
- [ ] Teacher attendance management
- [ ] Student attendance view
- [ ] Database schema and access policies
- [ ] Testing and validation

The checklist reflects the project structure and progress documented so far; unchecked items are planned or unfinished.

## Learning Goals

Through this project, I am practicing:

- Building Flutter interfaces and screen navigation
- Organizing a Flutter application
- Connecting a Flutter app to Supabase
- Learning how authentication and role-based application flows work

## Contributing

This is currently a personal learning project. Suggestions and constructive feedback are welcome.

## License

No license has been added to this repository yet. All rights remain with the author unless a license is added.
