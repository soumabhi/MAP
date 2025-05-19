# FaceMap <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Badge"/>

> A sophisticated cross-platform facial recognition system for modern attendance tracking and employee management

FaceMap leverages advanced machine learning with Flutter to provide real-time facial authentication across all major platforms. Built for reliability in diverse enterprise environments with or without network connectivity.

![Flutter](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/License-MIT-green)



## ✨ Key Capabilities

| Capability | Implementation |
|------------|----------------|
| **Facial Detection** | Google ML Kit integration with real-time processing |
| **Recognition Engine** | MobileFaceNet architecture via TensorFlow Lite |
| **Authentication Flow** | Branch-specific employee verification system |
| **Offline Operation** | Complete functionality without internet via Hive DB |
| **Cross-Platform** | Single codebase deployment across all major platforms |

## 🔍 Core Features

- **High-Precision Face Detection** - ML Kit powered detection optimized for varying lighting conditions
- **Secure Biometric Recognition** - Fast and accurate face recognition using MobileFaceNet (99.4% accuracy)
- **Enterprise-Grade Authentication** - Branch-specific employee verification with role-based access control
- **Comprehensive Attendance Management** - Automated time tracking with custom report generation
- **Offline-First Architecture** - Full functionality in disconnected environments with Hive persistence
- **Cross-Platform Consistency** - Identical experience across mobile, desktop, and web platforms
- **Minimal Resource Footprint** - Optimized for performance even on lower-end devices

## 🏗️ Architecture

```
facemap/
├── assets/                    # Assets and ML models
│   └── mobile_facenet.tflite  # Pre-trained facial recognition model
├── lib/
│   ├── app/                   # Application configuration
│   │   ├── config.dart        # Environment configuration
│   │   ├── routes.dart        # Navigation routes
│   │   └── theme.dart         # UI theme definitions
│   ├── models/                # Data structures
│   │   ├── employee.dart      # Employee model with Hive integration
│   │   ├── face_data.dart     # Facial embedding storage
│   │   └── attendance.dart    # Attendance record model
│   ├── screens/               # UI components
│   │   ├── auth/              # Authentication flows
│   │   ├── home/              # Main dashboard
│   │   ├── registration/      # Employee registration
│   │   └── verification/      # Face verification
│   ├── services/              # Core business logic
│   │   ├── ml/                # Machine learning services
│   │   │   ├── detector.dart  # Face detection implementation
│   │   │   └── recognizer.dart # Face recognition implementation
│   │   ├── storage/           # Data persistence
│   │   │   ├── hive_service.dart # Local database implementation
│   │   │   └── sync_service.dart # Optional cloud synchronization 
│   │   └── auth_service.dart  # Authentication service
│   └── main.dart              # Application entry point
├── platform/                  # Platform-specific implementations
│   ├── android/               # Android configuration
│   ├── ios/                   # iOS configuration
│   ├── web/                   # Web configuration
│   └── desktop/               # Desktop platforms configuration
├── test/                      # Automated testing
│   ├── unit/                  # Unit tests
│   ├── widget/                # Widget tests
│   └── integration/           # Integration tests
└── pubspec.yaml               # Project dependencies
```

## 🛠️ Technology Stack

| Category | Technologies |
|----------|-------------|
| **Framework** | Flutter SDK |
| **ML & Vision** | Google ML Kit, TensorFlow Lite |
| **State Management** | Provider |
| **Local Storage** | Hive NoSQL Database |
| **Image Processing** | camera, image_picker |
| **Utilities** | intl, path_provider, ffi |
| **Development** | flutter_lints, build_runner |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10+ (with Dart 3.0+)
- Android Studio / Xcode for native development
- Git

### Installation

```bash
# Clone repository
git clone https://github.com/your-username/facemap.git

# Navigate to project directory
cd facemap

# Install dependencies
flutter pub get

# Generate Hive adapters (if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the application
flutter run
```

### Configuration

1. **ML Model Setup**:
   - The MobileFaceNet model is included in the assets directory
   - No additional configuration required for basic usage

2. **Branch Configuration**:
   - Edit `lib/app/config.dart` to configure branch IDs and admin credentials

## 📱 Deployment

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

### Web

```bash
flutter build web --release
```

### Desktop

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## 📋 Usage Guide

1. **Administrator Setup**:
   - First-time login creates admin account
   - Configure branch settings and access permissions

2. **Employee Registration**:
   - Enter employee details
   - Capture facial data from multiple angles for improved accuracy
   - Assign to specific branch with appropriate permissions

3. **Attendance Tracking**:
   - Employees verify identity through facial recognition
   - System automatically records check-in/check-out times
   - Data persists locally and can sync when connectivity is available

4. **Reporting**:
   - Generate attendance reports by date range, department, or individual
   - Export data in multiple formats (CSV, PDF)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -m 'Add some feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a pull request

Please ensure your code adheres to the project's style guide and passes all tests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📧 Contact & Support

**Developer**: Abhishek Emmanual Hansdak  
**Email**: abhishekhansdak53@gmail.com

---
