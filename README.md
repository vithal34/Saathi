# Saathi - AI-Powered Healthcare Platform

Saathi is a freemium AI-powered healthcare platform designed for preliminary health screening in India. The app allows users to interact with an AI assistant in Hindi or English and receive AI-generated SOAP reports with triage-based diagnosis.

## Features

- 🤖 AI-powered health assistant (supports ChatGPT, Claude, or Gemini)
- 🌐 Bilingual support (Hindi and English)
- 📝 SOAP report generation
- 🚨 Triage-based diagnosis
- 👤 User profile management
- 📊 Health report history

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Setup

1. Clone the repository
2. Open `Saathi.xcodeproj` in Xcode
3. Configure your AI provider API key in `AIService.swift`
4. Build and run the project

## AI Integration

The app supports integration with multiple AI providers:
- OpenAI ChatGPT
- Anthropic Claude
- Google Gemini

To use a specific provider:
1. Sign up for an API key from your preferred provider
2. Update the `AIService` initialization with your API key
3. Select the provider in the app settings

## Architecture

The app follows MVVM architecture with the following components:

- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management
- **Services**: AI integration and data handling
- **Models**: Data structures and business objects

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 