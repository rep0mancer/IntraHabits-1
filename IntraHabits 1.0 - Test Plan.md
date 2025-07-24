# IntraHabits 1.0 - Test Plan

## Overview
This document outlines the comprehensive testing strategy for IntraHabits 1.0, covering unit tests, integration tests, UI tests, accessibility testing, and manual testing procedures.

## Test Coverage Goals
- **Unit Tests**: ≥ 80% code coverage
- **Integration Tests**: All critical user flows
- **UI Tests**: Key user interactions and navigation
- **Accessibility Tests**: VoiceOver, Dynamic Type, High Contrast
- **Performance Tests**: Memory usage, startup time, sync performance

## 1. Unit Tests

### 1.1 DataService Tests
**File**: `DataServiceTests.swift`
**Coverage**: Core data operations, validation, statistics

**Test Cases**:
- ✅ Activity creation with valid data
- ✅ Activity creation with invalid data (validation)
- ✅ Activity fetching and filtering
- ✅ Activity updating and deletion
- ✅ Session creation (numeric and timer types)
- ✅ Session fetching and deletion
- ✅ Statistics calculations (today, weekly, monthly totals)
- ✅ Streak calculations (current and best streaks)
- ✅ Performance tests for bulk operations

### 1.2 StoreKitService Tests
**File**: `StoreKitServiceTests.swift`
**Coverage**: In-app purchase logic, activity limits

**Test Cases**:
- ✅ Activity limit enforcement (free vs premium)
- ✅ Paywall trigger conditions
- ✅ Purchase status management
- ✅ Product loading and error handling
- ✅ Purchase workflow simulation
- ✅ Error message localization

### 1.3 CloudKitService Tests
**File**: `CloudKitServiceTests.swift`
**Coverage**: Sync logic, conflict resolution

**Test Cases**:
- [ ] Account status checking
- [ ] Sync status management
- [ ] Record creation and updating
- [ ] Conflict resolution strategies
- [ ] Error handling and retry logic
- [ ] Network connectivity handling

### 1.4 Model Tests
**File**: `ModelTests.swift`
**Coverage**: Core Data model validation

**Test Cases**:
- [ ] Activity model validation
- [ ] Session model validation
- [ ] Relationship integrity
- [ ] CloudKit field handling
- [ ] Data migration scenarios

## 2. Integration Tests

### 2.1 Activity Management Flow
**Scenarios**:
- Create activity → Add sessions → View statistics
- Reach activity limit → Trigger paywall → Purchase → Add more activities
- Edit activity → Update sessions → Verify data consistency
- Delete activity → Verify cascade deletion of sessions

### 2.2 Sync Integration
**Scenarios**:
- Create data offline → Go online → Verify sync
- Modify data on multiple devices → Verify conflict resolution
- Network interruption during sync → Verify recovery
- Account status changes → Verify sync behavior

### 2.3 Timer Integration
**Scenarios**:
- Start timer → Background app → Return → Verify time tracking
- Start timer → Force quit app → Reopen → Verify session recovery
- Multiple timer sessions → Verify total calculations
- Timer with notifications → Verify background behavior

## 3. UI Tests

### 3.1 Navigation Tests
**File**: `NavigationTests.swift`
**Test Cases**:
- [ ] Main navigation flow (Home → Add Activity → Settings)
- [ ] Deep linking to specific views
- [ ] Back navigation and state preservation
- [ ] Modal presentation and dismissal
- [ ] Tab switching and state management

### 3.2 Activity Management UI
**File**: `ActivityUITests.swift`
**Test Cases**:
- [ ] Add activity form validation
- [ ] Activity card interactions
- [ ] Timer UI state changes
- [ ] Context menu actions
- [ ] Drag and drop reordering

### 3.3 Paywall UI Tests
**File**: `PaywallUITests.swift`
**Test Cases**:
- [ ] Paywall presentation at activity limit
- [ ] Purchase flow UI
- [ ] Restore purchases UI
- [ ] Error handling UI
- [ ] Success confirmation UI

## 4. Accessibility Tests

### 4.1 VoiceOver Testing
**Manual Test Cases**:
- [ ] Navigate entire app using VoiceOver
- [ ] Verify all interactive elements are accessible
- [ ] Test custom accessibility labels and hints
- [ ] Verify proper reading order
- [ ] Test gesture navigation

### 4.2 Dynamic Type Testing
**Test Cases**:
- [ ] Test all text sizes from xSmall to accessibility5
- [ ] Verify layout adaptation to large text
- [ ] Test text truncation and wrapping
- [ ] Verify button and touch target sizes

### 4.3 High Contrast Testing
**Test Cases**:
- [ ] Test app in high contrast mode
- [ ] Verify color contrast ratios ≥ 4.5:1
- [ ] Test custom color adaptations
- [ ] Verify icon and image visibility

### 4.4 Reduce Motion Testing
**Test Cases**:
- [ ] Test app with reduce motion enabled
- [ ] Verify animations are disabled/reduced
- [ ] Test alternative visual feedback
- [ ] Verify functionality without animations

## 5. Performance Tests

### 5.1 Startup Performance
**Metrics**:
- Cold start time: ≤ 400ms (iPhone 13)
- Memory usage: < 100MB with 50 activities
- CPU usage during startup: < 50%

**Test Cases**:
- [ ] Measure cold start time
- [ ] Measure warm start time
- [ ] Test with large datasets
- [ ] Memory leak detection

### 5.2 Sync Performance
**Metrics**:
- Sync 100 activities: ≤ 5 seconds
- Sync 1000 sessions: ≤ 10 seconds
- Background sync completion: ≤ 30 seconds

**Test Cases**:
- [ ] Measure sync time with various data sizes
- [ ] Test background sync performance
- [ ] Network timeout handling
- [ ] Batch operation performance

### 5.3 UI Performance
**Metrics**:
- Scroll performance: 60 FPS
- Animation smoothness: No dropped frames
- Touch response time: ≤ 100ms

**Test Cases**:
- [ ] Scroll performance with large lists
- [ ] Animation frame rate measurement
- [ ] Touch response time testing
- [ ] Memory usage during UI operations

## 6. Localization Tests

### 6.1 Language Testing
**Languages**: English (en), German (de)

**Test Cases**:
- [ ] All strings are localized
- [ ] No hardcoded strings in UI
- [ ] Proper pluralization handling
- [ ] Date and number formatting
- [ ] Right-to-left layout (future)

### 6.2 Cultural Adaptation
**Test Cases**:
- [ ] Currency formatting (for pricing)
- [ ] Date format preferences
- [ ] Number format preferences
- [ ] Cultural color associations

## 7. Device Testing

### 7.1 iPhone Testing
**Devices**: iPhone SE (3rd gen), iPhone 14, iPhone 15 Pro Max
**Test Cases**:
- [ ] Layout adaptation to different screen sizes
- [ ] Touch target accessibility
- [ ] Performance on older devices
- [ ] Battery usage optimization

### 7.2 iPad Testing
**Devices**: iPad (10th gen), iPad Pro 12.9"
**Test Cases**:
- [ ] Universal app layout
- [ ] Multitasking support
- [ ] Keyboard shortcuts
- [ ] Apple Pencil support (if applicable)

## 8. Edge Cases and Error Handling

### 8.1 Network Conditions
**Test Cases**:
- [ ] Offline mode functionality
- [ ] Poor network connectivity
- [ ] Network interruption during operations
- [ ] Airplane mode transitions

### 8.2 Storage Conditions
**Test Cases**:
- [ ] Low storage space
- [ ] iCloud storage quota exceeded
- [ ] CoreData migration failures
- [ ] Backup and restore scenarios

### 8.3 System Conditions
**Test Cases**:
- [ ] Low memory warnings
- [ ] Background app refresh disabled
- [ ] Notifications disabled
- [ ] System date/time changes

## 9. Security Tests

### 9.1 Data Protection
**Test Cases**:
- [ ] Data encryption at rest
- [ ] Secure keychain usage
- [ ] App Transport Security compliance
- [ ] Privacy manifest compliance

### 9.2 Purchase Security
**Test Cases**:
- [ ] Transaction verification
- [ ] Receipt validation
- [ ] Fraud prevention
- [ ] Refund handling

## 10. Regression Tests

### 10.1 Critical Path Testing
**Scenarios** (to be run before each release):
1. Install app → Create 3 activities → Add sessions → Verify statistics
2. Reach activity limit → Purchase unlimited → Add more activities
3. Enable iCloud sync → Verify data sync across devices
4. Test timer functionality → Background → Foreground → Save session
5. Export data → Verify JSON format and completeness

### 10.2 Bug Regression
**Process**:
- Maintain list of fixed bugs
- Create specific test cases for each bug
- Run regression suite before releases
- Automate where possible

## 11. Test Automation

### 11.1 Continuous Integration
**Setup**:
- GitHub Actions workflow
- Automated unit test execution
- Code coverage reporting
- Performance regression detection

### 11.2 UI Test Automation
**Tools**: XCUITest
**Coverage**:
- Critical user flows
- Regression test scenarios
- Cross-device compatibility
- Accessibility validation

## 12. Test Data Management

### 12.1 Test Data Sets
**Small Dataset**: 5 activities, 50 sessions
**Medium Dataset**: 20 activities, 500 sessions
**Large Dataset**: 100 activities, 5000 sessions

### 12.2 Test Environment
**Configuration**:
- Separate CloudKit container for testing
- Mock StoreKit configuration
- Test user accounts
- Isolated test data

## 13. Release Criteria

### 13.1 Quality Gates
- [ ] All unit tests pass (≥ 80% coverage)
- [ ] All critical integration tests pass
- [ ] No accessibility violations
- [ ] Performance benchmarks met
- [ ] Security review completed

### 13.2 Sign-off Requirements
- [ ] Development team approval
- [ ] QA team approval
- [ ] Accessibility review approval
- [ ] Performance review approval
- [ ] Security review approval

## 14. Test Reporting

### 14.1 Test Metrics
- Test execution rate
- Pass/fail rates
- Code coverage percentage
- Performance benchmark results
- Bug discovery rate

### 14.2 Test Documentation
- Test execution reports
- Bug reports and tracking
- Performance analysis reports
- Accessibility audit reports
- Release readiness reports

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Next Review**: Before each major release

