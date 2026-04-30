<div align="center">

# 🍽️ Veg Recipe AI App

### *Smart vegetarian cooking with AI-powered suggestions.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge\&logo=flutter\&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge\&logo=dart\&logoColor=white)](https://dart.dev)
[![API](https://img.shields.io/badge/API-TheMealDB-orange?style=for-the-badge)](https://www.themealdb.com/)
[![AI](https://img.shields.io/badge/AI-Gemini-blueviolet?style=for-the-badge)](https://ai.google.dev/)
[![State](https://img.shields.io/badge/Riverpod-State%20Mgmt-4CAF50?style=for-the-badge)](https://riverpod.dev)

**A modern Flutter application that fetches vegetarian recipes from a REST API and generates smart AI-based recipes using Google Gemini.**

</div>

---

## 📖 Overview

The **Veg Recipe AI App** is a premium Flutter application built as part of the **Android Development Framework (ADF)** course.
It combines **REST API integration** and **AI-powered features** to provide a complete cooking experience.

Users can:

* Browse vegetarian recipes
* Search meals in real-time
* Save favorites
* Plan meals
* Generate recipes using AI

---

## ✨ Features

### 🔹 Core Features

* 🍽️ Fetch vegetarian recipes using REST API
* 🔍 Real-time search with debounce
* 📷 Recipe images with caching
* ❤️ Favorites system (local storage)
* 📺 YouTube cooking video integration

### 🤖 AI Features

* Generate recipes from ingredients
* Smart meal planning suggestions
* Voice input support
* AI fallback when API fails

### 🎨 UI / UX Features

* Apple-style smooth UI
* Light & Dark mode
* Glassmorphism cards
* Hero animations
* Shimmer loading effects

### ⚡ Advanced Features

* Drag & Drop Meal Planner
* Offline support (fallback recipes)
* Persistent storage using SharedPreferences
* Smooth navigation transitions

---

## 🛠️ Tech Stack

| Layer            | Technology           |
| ---------------- | -------------------- |
| Framework        | Flutter              |
| Language         | Dart                 |
| API              | TheMealDB            |
| AI               | Google Gemini        |
| State Management | Riverpod             |
| Storage          | SharedPreferences    |
| UI               | Material + Custom UI |

---

## 📱 App Screenshots

<div align="center">

### 🏠 Home Screen

<img src="images/home.jpg" width="250"/>

---

### 🔍 Search Screen

<img src="images/search.jpg" width="250"/>

---

### 🤖 AI Recipe Screen
<img src="images/ai-1.jpg" width="250"/>
<img src="images/ai.jpg" width="250"/>

---

### ❤️ Favorites Screen

<img src="images/favorites.jpg" width="250"/>

---

### 📅 Meal Planner

<img src="images/plan.jpg" width="250"/>

---

### 👤 Profile Screen

<img src="images/profile.jpg" width="250"/>

---

### 📖 Recipe Detail

<img src="images/detail.jpg" width="250"/>

</div>

---

## 🧩 Project Structure

```
lib/
├── models/
├── repository/
├── services/
├── screens/
├── widgets/
└── main.dart
```

---

## ⚙️ Installation

```bash
git clone https://github.com/Kanani-Shubham/ADF_ALA-2_Recipe_Finder_App.git
cd recipefinder

flutter pub get
flutter run
```

---

## 🔐 API Setup (IMPORTANT)

Run app with Gemini API:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

---

## 🎯 Learning Outcomes

* REST API Integration
* JSON Parsing
* Repository Pattern
* State Management using Riverpod
* AI Integration (Gemini API)
* Flutter UI/UX Design

---

## 🔮 Future Improvements

* Firebase login system
* Recipe rating & comments
* AI nutrition tracking
* Voice assistant cooking mode

---

## 👨‍💻 Author

**Shubham Kanani**
Enrollment No: 20230905090053

---

<div align="center">

⭐ If you like this project, give it a star!

</div>
