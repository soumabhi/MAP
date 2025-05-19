# FaceMap

A cross-platform face recognition attendance and employee management app built using **Flutter**. It leverages **Google ML Kit**, **TFLite**, and **Hive** for face detection, recognition, and offline data storage. Ideal for workplaces, institutions, and remote check-ins with real-time face scanning.

---

## 🔍 Features

- 📸 Live face detection using Google ML Kit  
- 🧠 Face recognition with MobileFaceNet (TFLite)  
- 👨‍💼 Register and scan faces with the camera  
- 📦 Offline local data persistence using Hive  
- 🔒 Employee login with branch ID and password  
- 📋 Employee listing with scan timestamps  
- 📱 Platform support: Android, iOS, Windows, macOS, Linux, Web

---

## 🧱 Project Structure

facemap/
├── assets/ # MobileFaceNet TFLite model
├── lib/
│ ├── main.dart # App entry point
│ ├── app/ # App-level configs and theme
│ ├── models/ # Face model with Hive support
│ ├── screens/ # All screens (login, home, register, scan)
│ └── services/ # ML, face, Hive services
├── android/ # Android native files (Gradle, Kotlin, Manifest)
├── ios/ # iOS native files (Xcode, Swift)
├── macos/ # macOS build support
├── linux/ # Linux build support
├── windows/ # Windows build support
├── web/ # Web build assets
├── pubspec.yaml # Project dependencies and assets
├── analysis_options.yaml # Dart linting configuration
└── README.md # You're reading it now


---

## 🛠️ Dependencies

Key Flutter packages used:

- `google_ml_kit`: Face detection using ML Kit  
- `tflite_flutter`: Run MobileFaceNet model  
- `hive` & `hive_flutter`: Local storage for face data  
- `camera`, `image_picker`: Capture and select images  
- `intl`, `provider`, `ffi`: Utilities and state management  

To install all packages:

```bash
flutter pub get
```

## 🚀 Getting Started

##Clone the Repository:

git clone https://github.com/your-username/soumabhi-map.git
cd soumabhi-map/facemap

## Install Flutter Packages:

flutter pub get

## Run the App:

flutter run

## 📦 Model

## This app uses a custom-trained MobileFaceNet model. The model is stored in:

assets/mobile_facenet.tflite

## Ensure the model is listed in pubspec.yaml.

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## 📧 Contact

Developed by Abhishek Emmanual Hansdak
For queries or support, contact at abhishekhansdak53@gmail.com

---

Feel free to customize this template further to suit your project's specific needs. If you require assistance with any particular section or additional features, don't hesitate to ask!
::contentReference[oaicite:1]{index=1}
