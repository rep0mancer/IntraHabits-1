# IntraHabits 1.0

> A production-ready iOS and iPadOS Universal habit tracker app built with SwiftUI, CoreData+CloudKit sync, and StoreKit 2 paywall integration.

![IntraHabits App Icon](https://private-us-east-1.manuscdn.com/sessionFile/fd9K9FHBowt9mbbyasyqmv/sandbox/Z5NRH7hHBWyY3ztYuWrKFK-images_1752568376361_na1fn_L2hvbWUvdWJ1bnR1L0ludHJhSGFiaXRzL0RvY3MvYXBwLWljb24.png?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9wcml2YXRlLXVzLWVhc3QtMS5tYW51c2Nkbi5jb20vc2Vzc2lvbkZpbGUvZmQ5SzlGSEJvd3Q5bWJieWFzeXFtdi9zYW5kYm94L1o1TlJIN2hIQld5WTN6dFl1V3JLRkstaW1hZ2VzXzE3NTI1NjgzNzYzNjFfbmExZm5fTDJodmJXVXZkV0oxYm5SMUwwbHVkSEpoU0dGaWFYUnpMMFJ2WTNNdllYQndMV2xqYjI0LnBuZyIsIkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTc5ODc2MTYwMH19fV19&Key-Pair-Id=K2HSFNDJXOU9YS&Signature=C3cMR38E7RhmzcsEvm4YBjLzMnRmPaGxVFOaOHxKwiucC~v6tF11TZR0QGjb9TzEJkHyE6txniJC-3cfRlwidFVp4HMM1o3-lhi2dujUENffe6r9JLefd1EGY6hr0x676zma1GZJkNtow9j0SaV3aEZB~4NK44wmUtqqL8qXn5cvAPtySdQ0zpHWG3eYsvlnQZPyLKhzX37jBOFn5Kqpj7S3jDzNuI-PXX8ieQ8Wp9wUf2aXr0wYSIHAeM4ua6JvxW7MKDm4WuhxPoge5GY3MF4m81f9k7jQeBmGaKiCR~LnvOBg73-tyshcSwWvRTsifAxV3OBMONqWtlqTMLz-fQ__)

## 📱 Overview

IntraHabits is an elegant, HIG-compliant habit tracking application that helps users build and maintain positive habits. The app features a clean dark theme interface, comprehensive data visualization, iCloud sync, and a freemium model with up to 5 free activities.

### Key Features

- ✅ **Universal App**: Native support for iPhone and iPad
- ⏱️ **Dual Activity Types**: Numeric counters and timer-based activities
- 🏠 **Interactive Widgets**: Home screen widgets with timer controls and +1 buttons
- 📊 **Rich Analytics**: Comprehensive statistics with charts and streak tracking
- ☁️ **iCloud Sync**: Automatic data synchronization across devices
- 💰 **Freemium Model**: 5 free activities, unlimited with in-app purchase
- 🌍 **Localized**: Full support for English and German
- ♿ **Accessible**: VoiceOver, Dynamic Type, and High Contrast support
- 🎨 **HIG Compliant**: Follows Apple's Human Interface Guidelines

## 🏗️ Architecture

### Technology Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI 4
- **Architecture**: MVVM + Combine
- **Persistence**: CoreData + CloudKit
- **In-App Purchases**: StoreKit 2
- **Minimum OS**: iOS 15.1 / iPadOS 15.1

### Project Structure

```
IntraHabits/
├── IntraHabits/
│   ├── Views/                 # SwiftUI Views
│   │   ├── Components/        # Reusable UI components
│   │   ├── ContentView.swift  # Main app view
│   │   ├── AddActivityView.swift
│   │   ├── TimerView.swift
│   │   └── ...
│   ├── ViewModels/           # MVVM ViewModels
│   ├── Models/               # CoreData models
│   ├── Services/             # Business logic services
│   │   ├── DataService.swift
│   │   ├── CloudKitService.swift
│   │   └── StoreKitService.swift
│   ├── Utils/                # Utilities and helpers
├── IntraHabitsWidget/        # Widget Extension
│   ├── Views/                # Widget UI views
│   │   ├── ActivityQuickActionsView.swift
│   │   ├── TodaysProgressView.swift
│   │   ├── ActivityTimerView.swift
│   │   └── ActivityStatsView.swift
│   ├── Models/               # Widget data models
│   │   ├── WidgetModels.swift
│   │   ├── WidgetDataService.swift
│   │   └── WidgetProviders.swift
│   ├── Intents/              # App Intents for interactions
│   │   └── WidgetIntents.swift
│   └── IntraHabitsWidget.swift # Main widget bundle
│   ├── Resources/            # Assets and configurations
│   └── Localization/         # String localizations
├── IntraHabitsTests/         # Unit tests
├── Docs/                     # Documentation and assets
└── .github/workflows/        # CI/CD pipelines
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15.1 or later
- iOS 15.1+ / iPadOS 15.1+ deployment target
- Apple Developer Account (for CloudKit and StoreKit)
- macOS 14.0+ (for development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/IntraHabits.git
   cd IntraHabits
   ```

2. **Open in Xcode**
   ```bash
   open IntraHabits.xcodeproj
   ```

3. **Configure Team and Bundle ID**
   - Select the IntraHabits target
   - Update the Team and Bundle Identifier
   - Ensure CloudKit capability is enabled

4. **Set up CloudKit**
   - Open CloudKit Dashboard
   - Create a new container or use existing
   - Update the container identifier in the project

5. **Configure StoreKit**
   - Update the product IDs in `StoreKitService.swift`
   - Configure the StoreKit configuration file
   - Set up products in App Store Connect

### Build and Run

```bash
# Build for simulator
xcodebuild build -project IntraHabits.xcodeproj -scheme IntraHabits -destination "platform=iOS Simulator,name=iPhone 15 Pro"

# Run tests
xcodebuild test -project IntraHabits.xcodeproj -scheme IntraHabits -destination "platform=iOS Simulator,name=iPhone 15 Pro"
```

## 🧪 Testing

### Unit Tests

The project includes comprehensive unit tests with ≥80% code coverage:

```bash
# Run all tests
xcodebuild test -project IntraHabits.xcodeproj -scheme IntraHabits

# Run specific test class
xcodebuild test -project IntraHabits.xcodeproj -scheme IntraHabits -only-testing:IntraHabitsTests/DataServiceTests

# Generate coverage report
xcodebuild test -project IntraHabits.xcodeproj -scheme IntraHabits -enableCodeCoverage YES
```

### Test Categories

- **DataService Tests**: Core data operations and validation
- **StoreKitService Tests**: In-app purchase logic and limits
- **CloudKitService Tests**: Sync functionality and conflict resolution
- **Accessibility Tests**: VoiceOver and accessibility compliance
- **Performance Tests**: Memory usage and startup time benchmarks

### Manual Testing Checklist

- [ ] Create and manage activities (numeric and timer types)
- [ ] Test activity limit enforcement and paywall
- [ ] Verify iCloud sync across multiple devices
- [ ] Test accessibility with VoiceOver enabled
- [ ] Validate localization in German and English
- [ ] Test on various device sizes (iPhone SE to iPad Pro)

## 📦 Deployment

### Enterprise Distribution

The project is configured for enterprise distribution with automated CI/CD:

1. **Set up GitHub Secrets**
   ```
   ENTERPRISE_CERTIFICATE_P12: Base64 encoded P12 certificate
   ENTERPRISE_CERTIFICATE_PASSWORD: Certificate password
   ENTERPRISE_PROVISIONING_PROFILE: Base64 encoded provisioning profile
   TEAM_ID: Apple Developer Team ID
   KEYCHAIN_PASSWORD: Keychain password for CI
   ```

2. **Trigger Deployment**
   ```bash
   # Create a release to trigger deployment
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **Manual Build**
   ```bash
   # Archive for enterprise distribution
   xcodebuild archive \
     -project IntraHabits.xcodeproj \
     -scheme IntraHabits \
     -destination "generic/platform=iOS" \
     -archivePath IntraHabits.xcarchive
   
   # Export IPA
   xcodebuild -exportArchive \
     -archivePath IntraHabits.xcarchive \
     -exportPath Export \
     -exportOptionsPlist ExportOptions.plist
   ```

### MDM Deployment

The generated IPA can be deployed via Mobile Device Management (MDM) systems:

1. Upload the IPA to your MDM platform
2. Create an app deployment policy
3. Assign to target device groups
4. Monitor installation status

## 🔧 Configuration

### Environment Variables

The app supports various configuration options:

```swift
// Debug settings
#if DEBUG
let isDebugMode = true
let syncInterval: TimeInterval = 10 // Faster sync for testing
#else
let isDebugMode = false
let syncInterval: TimeInterval = 30
#endif
```

### Feature Flags

Toggle features via UserDefaults or remote configuration:

```swift
// Enable/disable features
UserDefaults.standard.set(true, forKey: "enableAdvancedStatistics")
UserDefaults.standard.set(false, forKey: "enableBetaFeatures")
```

### CloudKit Configuration

Update CloudKit settings in `CloudKitService.swift`:

```swift
private let containerIdentifier = "iCloud.com.yourcompany.intrahabits"
private let syncInterval: TimeInterval = 30
private let maxRetryAttempts = 3
```

## 📊 Analytics and Monitoring

### Performance Metrics

The app tracks key performance indicators:

- **Startup Time**: Target ≤ 400ms on iPhone 13
- **Memory Usage**: Target < 100MB with 50 activities
- **Sync Performance**: Target ≤ 5 seconds for 100 activities
- **Battery Usage**: Optimized background sync

### Error Tracking

Implement error tracking for production monitoring:

```swift
// Example error tracking integration
func trackError(_ error: Error, context: String) {
    // Send to your analytics platform
    print("Error in \(context): \(error)")
}
```

## 🌍 Localization

### Supported Languages

- **English (en)**: Primary language
- **German (de)**: Full localization

### Adding New Languages

1. Create new `.lproj` folder in `Localization/`
2. Copy `Localizable.strings` from English
3. Translate all strings
4. Update project settings to include new language
5. Test with device language settings

### String Management

```swift
// Usage in code
Text("home.title") // Automatically localized
Text("activity.count", arguments: [count]) // With parameters
```

## ♿ Accessibility

### VoiceOver Support

The app provides comprehensive VoiceOver support:

```swift
// Example accessibility implementation
.accessibilityLabel("Activity: \(name)")
.accessibilityHint("Double tap to start timer")
.accessibilityAddTraits(.isButton)
```

### Dynamic Type

All text scales with user preferences:

```swift
.font(.title)
.dynamicTypeSize(.xSmall ... .accessibility5)
```

### High Contrast

Colors adapt to high contrast settings:

```swift
.foregroundColor(.primary) // Automatically adapts
.background(Color.systemBackground) // System colors
```

## 🔒 Security

### Data Protection

- All user data is encrypted at rest
- CloudKit provides end-to-end encryption
- Keychain storage for sensitive data
- App Transport Security (ATS) enabled

### Privacy

- No third-party analytics or tracking
- All data processing happens on-device
- CloudKit sync respects user privacy
- Minimal data collection

### Code Signing

```bash
# Verify code signature
codesign -dv --verbose=4 IntraHabits.app
spctl -a -vv IntraHabits.app
```

## 🐛 Troubleshooting

### Common Issues

**Build Errors**
```bash
# Clean build folder
xcodebuild clean -project IntraHabits.xcodeproj

# Reset simulator
xcrun simctl erase all
```

**CloudKit Sync Issues**
- Verify iCloud account is signed in
- Check CloudKit Dashboard for schema issues
- Ensure proper entitlements are configured

**StoreKit Testing**
- Use StoreKit configuration file for testing
- Verify product IDs match App Store Connect
- Test with sandbox Apple ID

### Debug Logging

Enable detailed logging for troubleshooting:

```swift
#if DEBUG
let logLevel = LogLevel.verbose
#else
let logLevel = LogLevel.error
#endif
```

## 📈 Performance Optimization

### Memory Management

- Use weak references in closures
- Implement proper view lifecycle management
- Monitor memory usage with Instruments

### Battery Optimization

- Efficient background sync scheduling
- Minimize location and sensor usage
- Optimize animation performance

### Network Optimization

- Batch CloudKit operations
- Implement exponential backoff for retries
- Use background app refresh efficiently

## 🤝 Contributing

### Development Workflow

1. Create feature branch from `develop`
2. Implement changes with tests
3. Run full test suite
4. Create pull request to `develop`
5. Code review and merge
6. Deploy to staging for testing

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for consistency
- Document public APIs
- Write meaningful commit messages

### Testing Requirements

- Unit tests for all new functionality
- Integration tests for critical paths
- Accessibility testing for UI changes
- Performance testing for optimizations

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For technical support or questions:

- **Email**: support@yourcompany.com
- **Documentation**: [Internal Wiki](https://wiki.yourcompany.com/intrahabits)
- **Issue Tracking**: [JIRA Project](https://yourcompany.atlassian.net)

## 🔄 Changelog

### Version 1.0.0 (2024-12-XX)

**Features**
- Initial release with core habit tracking functionality
- iCloud sync with CloudKit integration
- StoreKit 2 paywall for premium features
- Comprehensive accessibility support
- English and German localization

**Technical**
- MVVM architecture with Combine
- 80%+ unit test coverage
- Enterprise distribution ready
- Performance optimized for iOS 15.1+

---

**Built with ❤️ by the IntraHabits Team**

