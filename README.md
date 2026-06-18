# UniGrades
## (Unofficial app! It is not affiliated with, endorsed by, or maintained by TU-Sofia!)

Android application for students of **Technical University of Sofia** that provides quick access to grades from the E-Student system, grade monitoring, notifications for newly published grades, average score calculation, and in-app updates.

## Features

###  Grade Viewing

* View all grades from the TU-Sofia E-Student portal.
* Semester grouping.
* Color-coded grades for easier reading.
* Automatic calculation of average score.

###  Grade Monitoring

* Background monitoring for newly published grades.
* Persistent notification showing monitoring status.
* Notifications when new grades are detected.

###  Average Score

* Automatically calculates average score.
* Uses the latest available result for subjects with correction exams.
* Supports regular, correction, and liquidation exam results.

###  In-App Updates

* Automatic update checks on startup.
* Downloads APK updates directly from Google Drive.
* One-click installation.

###  Saved Login

* Stores Faculty Number and EGN locally.
* Automatic login on app startup.

---

## Installation

### Download APK

Download the latest APK from the Releases page:

```text
https://github.com/petrovemil05/e_student/releases
```

Or use the built-in updater inside the application.

---

## Requirements

* Android 8.0+
* Internet connection
* Valid TU-Sofia E-Student credentials

---

## Permissions

| Permission           | Purpose                                      |
| -------------------- | -------------------------------------------- |
| Notifications        | Grade alerts and monitoring status           |
| Internet             | Accessing E-Student data                     |
| Install Unknown Apps | Installing updates downloaded by the updater |
| Foreground Service   | Background grade monitoring                  |
| Wake Lock            | Reliable background checks                   |

---

## How Monitoring Works

When monitoring is enabled:

1. The app starts a foreground background service.
2. The service periodically checks the E-Student portal.
3. Newly detected grades trigger a notification.
4. Monitoring continues even when the application is closed.

### Notes

* Monitoring intervals are not guaranteed to be exact.
* Android battery optimization may delay checks.
* Some manufacturers (Xiaomi, Huawei, Oppo, Vivo, etc.) may apply additional background restrictions.

---

## Technology Stack

* Flutter
* Provider
* Dio
* Shared Preferences
* Flutter Background Service
* Flutter Local Notifications
* Package Info Plus
* Permission Handler

---

## Project Structure

```text
lib/
├── models/
│   ├── grade_item.dart
│   └── update_info.dart
│
├── services/
│   ├── grades_parser.dart
│   ├── notification_service.dart
│   ├── tu_api_service.dart
│   ├── grade_monitor_service.dart
│   ├── background_service.dart
│   └── update_service.dart
│
├── ui/
│   └── update_dialog.dart
│   └── main_page.dart
│
├── viewmodels/
│   └── grade_monitor_viewmodel.dart
│
│
└── main.dart
```

---

## Privacy

* Credentials are stored locally on the user's device.
* No personal information is sent to third-party services.
* The application communicates only with TU-Sofia services and update sources configured by the developer.

---

## Disclaimer

This project is an independent student-made application and is **not affiliated with, endorsed by, or maintained by Technical University of Sofia**.

The application accesses information available through the E-Student portal using credentials provided by the user.

---

## Contact and suggestions

If you have any ideas or spotted some problems, feel free to message me via email: timkaq67@gmail.com
If you are familiar with GitHub, contribute to the repository or open an issue.





