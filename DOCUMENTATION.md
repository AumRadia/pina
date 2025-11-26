# Pina Project Documentation

## Part 1: User Guide

Welcome to **Pina** (Personalized Impact & News Assistant)! This section helps you navigate the app.

### What is Pina?
Pina is your personal assistant for staying informed. It combines a curated news feed with "widgets" (AI tools) like translation and search.

### Getting Started
1.  **Registration**: Sign up with Email/Password or Google Sign-In. Upload a profile picture if you like.
2.  **Login**: Access your account securely.

### Key Features
*   **Home Screen**: Search for content and navigate the app.
*   **Trial Feed (News)**:
    *   **Read News**: Browse curated news articles.
    *   **Show Impact**: Tap this button on any article to get an AI-powered analysis of the news impact on various stakeholders.
    *   **Quick Action**: Perform immediate actions related to the news (coming soon).
*   **My AI Screen**: Your personal dashboard.
    *   **Add Widgets**: Tap `+` to browse the Marketplace.
    *   **Use Widgets**: Interact with Search or Translate tools directly.
    *   **Remove Widgets**: Tap `X` to delete.
*   **Menu**: Access Language settings, Contact Us, and Logout.

---

## Part 2: Technical Overview

This section provides a high-level look at how Pina is built, suitable for developers or stakeholders wanting to understand the technology without getting lost in code.

### Technology Stack
*   **Framework**: [Flutter](https://flutter.dev/) (Dart) - Used for building the mobile application.
*   **Backend**: Node.js/Express (External) - Handles authentication, widget marketplace data, and Telegram messaging.
*   **Database**: MongoDB (External) - Stores user profiles and widget data.
*   **APIs**:
    *   **NewsData.io**: Fetches news articles.
    *   **OpenAI**: Powers the "Impact Analysis" feature.

### App Architecture
The app follows a standard Flutter architecture:
*   **Screens (`lib/screens/`)**: The visual pages users see (Login, Home, My AI, Trial).
*   **Services (`lib/services/`)**: Handles communication with the backend and external APIs.
    *   `Apiservice`: Talks to NewsData.io (for `Trial` screen news) and OpenAI (for Impact Analysis).
    *   `WidgetService`: Manages user widgets and marketplace data.
*   **Models (`lib/models/`)**: Defines data structures (e.g., `NewsArticle`, `MarketWidget`).

### Key Data Flows
1.  **Authentication**:
    *   The app sends credentials to the backend.
    *   On success, it receives a token (or user ID) to manage the session.
2.  **Widget System**:
    *   **Marketplace**: The app fetches a list of available widgets from the database.
    *   **User Widgets**: When a user adds a widget, the app sends a request to link that widget ID to the user's profile in the database.
    *   **Dynamic UI**: The `MyAiScreen` checks the widget type (e.g., "Search", "Translate") and renders the appropriate UI component dynamically.
3.  **News & Impact**:
    *   **News Feed**: `Trial` screen fetches articles from NewsData.io.
    *   **Impact Analysis**: When requested, the app sends the article URL to OpenAI's API to generate a stakeholder analysis.

### Setup & Configuration
*   **Dependencies**: Managed via `pubspec.yaml`. Run `flutter pub get` to install.
*   **Assets**: Icons and images are stored in `assets/`.
*   **API Keys**: Currently configured in specific files (e.g., `trial.dart`, `Apiservice`). *Note: In a production environment, these should be secured.*

### Future Improvements
*   **State Management**: Implementing a solution like Riverpod or Bloc for better data handling as the app grows.
*   **Offline Mode**: Caching news and widgets for use without internet.
