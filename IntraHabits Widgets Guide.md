# IntraHabits Widgets Guide

## Overview

IntraHabits includes comprehensive widget support that allows users to track their activities directly from the home screen. The widgets are designed to mirror the app's design language and provide interactive functionality for both timer and numeric activities.

## Widget Types

### 1. Activity Quick Actions Widget
**Sizes:** Small, Medium  
**Purpose:** Interactive control for individual activities

**Features:**
- **Timer Activities:** Start/stop/pause timer controls
- **Numeric Activities:** +1 and +5 increment buttons
- **Real-time Updates:** Shows current timer duration and today's progress
- **Configuration:** Users can select which activity to control

**Interactions:**
- Start Timer: Begins timing for timer activities
- Stop Timer: Stops and saves the current timer session
- Pause/Resume Timer: Pauses and resumes timer without saving
- Increment (+1/+5): Adds numeric values to numeric activities

### 2. Today's Progress Widget
**Sizes:** Medium, Large  
**Purpose:** Overview of all activities and daily progress

**Features:**
- **Progress Overview:** Shows up to 4 activities with progress bars
- **Daily Summary:** Total sessions and time for the day
- **Visual Progress:** Color-coded progress indicators
- **Overall Progress:** Circular progress indicator showing daily completion

**Display:**
- Activity name with color indicator
- Progress value (time for timers, count for numeric)
- Progress bar showing completion percentage
- Summary statistics at the bottom

### 3. Activity Timer Widget
**Sizes:** Small, Medium  
**Purpose:** Dedicated timer control for timer activities

**Features:**
- **Timer Display:** Large, prominent timer showing current session
- **Progress Ring:** Visual progress indicator (medium widget only)
- **Control Buttons:** Start, stop, pause, resume functionality
- **Today's Total:** Shows cumulative time for the day
- **Status Indicators:** Running, paused, stopped states

**Interactions:**
- All timer control functions
- Quick access to open the main app
- Real-time timer updates every 30 seconds

### 4. Activity Statistics Widget
**Sizes:** Large  
**Purpose:** Comprehensive statistics and analytics

**Features:**
- **Top Activities:** Shows top 3 activities by session count
- **Streak Tracking:** Current and best streaks
- **Overall Stats:** Active days, total progress
- **Activity Rankings:** Ranked list with detailed statistics

**Display:**
- Activity statistics with session counts and totals
- Streak indicators with flame icons
- Overall progress metrics
- Trophy and achievement indicators

## Technical Implementation

### Architecture
- **App Intents:** Interactive buttons using iOS 17+ App Intents framework
- **Shared Data:** App Group container for data sharing between app and widgets
- **Timeline Updates:** Smart update scheduling based on activity state
- **Background Processing:** Efficient data loading and caching

### Data Sharing
- **App Group:** `group.com.intrahabits.shared`
- **Core Data:** Shared persistent store for real-time data access
- **User Defaults:** Shared preferences and timer states
- **Widget Center:** Automatic timeline reloading on data changes

### Update Strategy
- **Timer Widgets:** Update every 30 seconds when timer is running
- **Progress Widgets:** Update every 15 minutes during active hours
- **Stats Widgets:** Update every hour
- **Manual Updates:** Triggered by app interactions and data changes

## Widget Configuration

### Setup Process
1. **Add Widget:** Long press on home screen → Add Widget → IntraHabits
2. **Select Type:** Choose from 4 available widget types
3. **Configure:** Select specific activities for configurable widgets
4. **Customize:** Choose widget size and placement

### Configuration Options
- **Activity Quick Actions:** Select specific activity to control
- **Activity Timer:** Choose timer activity to monitor
- **Today's Progress:** Automatic (shows all activities)
- **Activity Statistics:** Automatic (shows top activities)

## Design Guidelines

### Visual Design
- **Brand Colors:** Consistent with app design (#CD3A2E primary)
- **Typography:** SF Pro/SF Rounded with proper Dynamic Type support
- **Corner Radius:** 12pt radius matching app design
- **Shadows:** 4pt radius with 2pt offset
- **Dark Mode:** Full dark mode compatibility

### Accessibility
- **VoiceOver:** Complete VoiceOver support with descriptive labels
- **Dynamic Type:** Scales from xSmall to accessibility5
- **High Contrast:** Adaptive colors for high contrast mode
- **Reduce Motion:** Conditional animations with alternative feedback

### Interaction Design
- **Button Feedback:** Haptic feedback on interactions
- **Visual States:** Clear indication of timer states (running/paused/stopped)
- **Progress Indicators:** Intuitive progress visualization
- **Error Handling:** Graceful handling of configuration and data errors

## Performance Optimization

### Memory Management
- **Efficient Data Loading:** Only load necessary data for each widget
- **Caching Strategy:** Smart caching of frequently accessed data
- **Background Limits:** Respect iOS background processing limits
- **Memory Footprint:** Minimal memory usage for widget extensions

### Battery Optimization
- **Update Frequency:** Balanced update frequency for battery life
- **Background Processing:** Minimal background processing
- **Network Usage:** No network requests from widgets
- **CPU Usage:** Efficient data processing and UI rendering

## Troubleshooting

### Common Issues
1. **Widget Not Updating:** Check app group configuration and data sharing
2. **Timer Not Syncing:** Verify shared UserDefaults and timer service
3. **Configuration Lost:** Check widget configuration persistence
4. **Performance Issues:** Review update frequency and data loading

### Debug Information
- **Widget Timeline:** Use Xcode widget timeline debugging
- **App Group Access:** Verify app group entitlements
- **Data Consistency:** Check Core Data shared store configuration
- **Intent Handling:** Debug App Intent execution

## Future Enhancements

### Planned Features
- **Live Activities:** Real-time timer updates on lock screen
- **Siri Shortcuts:** Voice control for starting/stopping activities
- **Complications:** Apple Watch complications support
- **Smart Suggestions:** AI-powered activity suggestions

### iOS Version Support
- **iOS 17+:** Full App Intents support with interactive widgets
- **iOS 16:** Basic widget functionality with limited interactivity
- **iOS 15:** Display-only widgets with app launching

## Best Practices

### For Users
1. **Widget Placement:** Place frequently used widgets on main home screen
2. **Configuration:** Configure widgets for most important activities
3. **Size Selection:** Choose appropriate widget sizes for available space
4. **Regular Updates:** Keep app updated for latest widget features

### For Developers
1. **Data Efficiency:** Minimize data loading and processing
2. **Update Strategy:** Use appropriate update frequencies
3. **Error Handling:** Implement robust error handling and fallbacks
4. **Testing:** Test widgets across different device sizes and orientations

## Integration with Main App

### Seamless Experience
- **Deep Linking:** Widgets can open specific app sections
- **Data Synchronization:** Real-time sync between widgets and app
- **State Management:** Consistent state across app and widgets
- **User Preferences:** Shared settings and preferences

### App Group Configuration
```swift
// App Group Identifier
let appGroupIdentifier = "group.com.intrahabits.shared"

// Shared UserDefaults
let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

// Shared Core Data Store
let storeURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
    .appendingPathComponent("DataModel.sqlite")
```

This comprehensive widget system provides users with powerful home screen functionality while maintaining the app's design excellence and performance standards.

