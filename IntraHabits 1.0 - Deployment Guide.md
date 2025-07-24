# IntraHabits 1.0 - Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying IntraHabits 1.0 to production environments using enterprise distribution and Mobile Device Management (MDM) systems.

## Prerequisites

### Development Environment
- macOS 14.0 or later
- Xcode 15.1 or later
- Apple Developer Enterprise Account
- Valid enterprise certificates and provisioning profiles

### Infrastructure Requirements
- GitHub repository with Actions enabled
- Enterprise distribution platform (e.g., AirWatch, Jamf, Intune)
- CloudKit container configured
- App Store Connect products configured

## 1. Pre-Deployment Setup

### 1.1 Certificate Management

**Generate Enterprise Certificate:**
```bash
# Generate certificate signing request
openssl req -new -newkey rsa:2048 -nodes -keyout enterprise.key -out enterprise.csr

# Upload CSR to Apple Developer Portal
# Download enterprise certificate
# Convert to P12 format
openssl pkcs12 -export -out enterprise.p12 -inkey enterprise.key -in enterprise.crt
```

**Create Provisioning Profile:**
1. Log in to Apple Developer Portal
2. Navigate to Certificates, Identifiers & Profiles
3. Create new provisioning profile for enterprise distribution
4. Select enterprise certificate and app ID
5. Download provisioning profile

### 1.2 CloudKit Configuration

**Set up CloudKit Container:**
```bash
# 1. Open CloudKit Dashboard (https://icloud.developer.apple.com)
# 2. Create new container: iCloud.com.yourcompany.intrahabits
# 3. Configure schema:
#    - Activity record type
#    - ActivitySession record type
#    - Set up indexes and security roles
# 4. Deploy to production environment
```

**Schema Configuration:**
```javascript
// Activity Record Type
{
  "recordType": "Activity",
  "fields": {
    "name": "String",
    "type": "String", 
    "color": "String",
    "isActive": "Int64",
    "createdAt": "DateTime",
    "updatedAt": "DateTime"
  }
}

// ActivitySession Record Type
{
  "recordType": "ActivitySession", 
  "fields": {
    "activityReference": "Reference(Activity)",
    "sessionDate": "DateTime",
    "numericValue": "Double",
    "duration": "Double",
    "isCompleted": "Int64",
    "createdAt": "DateTime"
  }
}
```

### 1.3 StoreKit Configuration

**App Store Connect Setup:**
1. Create app record in App Store Connect
2. Configure in-app purchase products:
   - Product ID: `com.intrahabits.unlimited_activities`
   - Type: Non-consumable
   - Price: $4.99 USD
3. Submit for review and approval

**StoreKit Testing:**
```bash
# Test with StoreKit configuration file
# Verify product loading and purchase flow
# Test restore purchases functionality
```

## 2. CI/CD Pipeline Setup

### 2.1 GitHub Secrets Configuration

Configure the following secrets in GitHub repository settings:

```bash
# Certificate and Provisioning
ENTERPRISE_CERTIFICATE_P12=<base64_encoded_p12>
ENTERPRISE_CERTIFICATE_PASSWORD=<certificate_password>
ENTERPRISE_PROVISIONING_PROFILE=<base64_encoded_profile>
TEAM_ID=<apple_developer_team_id>
KEYCHAIN_PASSWORD=<secure_keychain_password>

# Distribution
ENTERPRISE_DISTRIBUTION_URL=<mdm_distribution_endpoint>
ENTERPRISE_API_KEY=<mdm_api_key>

# Notifications
SLACK_WEBHOOK_URL=<slack_notification_webhook>
```

### 2.2 Workflow Triggers

The CI/CD pipeline triggers on:
- **Push to main**: Full build and test
- **Push to develop**: Test only
- **Pull requests**: Test and security scan
- **Release creation**: Full deployment pipeline

### 2.3 Pipeline Stages

1. **Test Stage**
   - Unit tests execution
   - Code coverage analysis
   - Security scanning
   - Accessibility validation

2. **Build Stage**
   - Archive creation
   - Code signing with enterprise certificate
   - IPA generation
   - dSYM upload

3. **Deploy Stage**
   - Upload to enterprise distribution
   - Manifest generation
   - MDM deployment trigger
   - Team notifications

## 3. Manual Deployment Process

### 3.1 Local Build

**Prepare Environment:**
```bash
# Set Xcode version
sudo xcode-select -s /Applications/Xcode_15.1.app/Contents/Developer

# Verify certificates
security find-identity -v -p codesigning

# Import provisioning profile
cp IntraHabits_Enterprise.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
```

**Build Archive:**
```bash
xcodebuild archive \
  -project IntraHabits.xcodeproj \
  -scheme IntraHabits \
  -destination "generic/platform=iOS" \
  -archivePath IntraHabits.xcarchive \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="IntraHabits Enterprise" \
  CODE_SIGN_IDENTITY="iPhone Distribution: Your Company Name"
```

**Export IPA:**
```bash
# Create export options
cat > ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>enterprise</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

# Export archive
xcodebuild -exportArchive \
  -archivePath IntraHabits.xcarchive \
  -exportPath Export \
  -exportOptionsPlist ExportOptions.plist
```

### 3.2 Verification

**Verify IPA:**
```bash
# Check code signature
codesign -dv --verbose=4 Export/IntraHabits.ipa

# Verify provisioning profile
security cms -D -i "Export/IntraHabits.ipa/Payload/IntraHabits.app/embedded.mobileprovision"

# Check entitlements
codesign -d --entitlements :- Export/IntraHabits.ipa
```

**Test Installation:**
```bash
# Install on test device via Xcode
xcrun devicectl device install app --device <device_id> Export/IntraHabits.ipa

# Verify app launches and basic functionality
```

## 4. MDM Deployment

### 4.1 Upload to MDM Platform

**AirWatch/Workspace ONE:**
```bash
# Upload via API
curl -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "aw-tenant-code: $TENANT_CODE" \
  -F "file=@IntraHabits.ipa" \
  -F "applicationname=IntraHabits" \
  -F "bundleid=com.intrahabits.app" \
  "$MDM_URL/api/mam/apps/internal/uploadchunks"
```

**Microsoft Intune:**
```bash
# Upload via Graph API
curl -X POST \
  -H "Authorization: Bearer $GRAPH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "@odata.type": "#microsoft.graph.iosLobApp",
    "displayName": "IntraHabits",
    "bundleId": "com.intrahabits.app",
    "minimumSupportedOperatingSystem": {
      "v15_0": true
    }
  }' \
  "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
```

### 4.2 Create Deployment Policy

**Configuration Profile:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.applicationaccess</string>
            <key>PayloadIdentifier</key>
            <string>com.intrahabits.restrictions</string>
            <key>allowedApplications</key>
            <array>
                <dict>
                    <key>bundleID</key>
                    <string>com.intrahabits.app</string>
                </dict>
            </array>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>IntraHabits Deployment</string>
    <key>PayloadIdentifier</key>
    <string>com.intrahabits.deployment</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

### 4.3 Target Device Groups

**Create Device Groups:**
1. **Pilot Group**: 10-20 test devices
2. **Department Groups**: By organizational unit
3. **All Devices**: Full organization rollout

**Deployment Phases:**
1. **Phase 1**: Pilot group (1-2 days)
2. **Phase 2**: Department rollout (1 week)
3. **Phase 3**: Organization-wide (2-4 weeks)

## 5. Monitoring and Validation

### 5.1 Deployment Metrics

**Track Key Metrics:**
- Installation success rate
- App launch success rate
- Crash reports and errors
- User adoption metrics
- Performance benchmarks

**Monitoring Tools:**
```bash
# MDM console monitoring
# Device compliance reports
# App usage analytics
# Error tracking dashboards
```

### 5.2 Health Checks

**Post-Deployment Validation:**
```bash
# Verify app installation
# Test core functionality
# Validate iCloud sync
# Check in-app purchases
# Test accessibility features
```

**Automated Health Checks:**
```bash
#!/bin/bash
# health_check.sh

echo "Running IntraHabits health checks..."

# Check app installation
if xcrun devicectl device list apps --device $DEVICE_ID | grep -q "com.intrahabits.app"; then
    echo "✅ App installed successfully"
else
    echo "❌ App installation failed"
    exit 1
fi

# Test app launch
xcrun devicectl device launch app --device $DEVICE_ID com.intrahabits.app
sleep 5

# Verify app is running
if xcrun devicectl device list processes --device $DEVICE_ID | grep -q "IntraHabits"; then
    echo "✅ App launched successfully"
else
    echo "❌ App launch failed"
    exit 1
fi

echo "✅ All health checks passed"
```

## 6. Rollback Procedures

### 6.1 Emergency Rollback

**Immediate Actions:**
1. Remove app from MDM deployment groups
2. Push previous version if available
3. Communicate with affected users
4. Investigate and document issues

**Rollback Script:**
```bash
#!/bin/bash
# rollback.sh

echo "Initiating emergency rollback..."

# Remove current version from MDM
curl -X DELETE \
  -H "Authorization: Bearer $API_TOKEN" \
  "$MDM_URL/api/apps/com.intrahabits.app/v1.0.0"

# Deploy previous version
curl -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"version": "0.9.0", "groups": ["all_devices"]}' \
  "$MDM_URL/api/apps/com.intrahabits.app/deploy"

echo "Rollback completed"
```

### 6.2 Gradual Rollback

**Phased Approach:**
1. Stop new deployments
2. Remove from pilot groups first
3. Gradually remove from larger groups
4. Monitor for stability

## 7. Troubleshooting

### 7.1 Common Issues

**Certificate Expiration:**
```bash
# Check certificate validity
security find-certificate -c "iPhone Distribution" -p | openssl x509 -text -noout

# Renew certificate
# Update provisioning profile
# Rebuild and redeploy
```

**Provisioning Profile Issues:**
```bash
# Verify profile
security cms -D -i profile.mobileprovision

# Check device UDIDs
# Verify app ID configuration
# Update profile if needed
```

**CloudKit Sync Issues:**
```bash
# Check CloudKit status
# Verify container configuration
# Review sync logs
# Test with different iCloud accounts
```

### 7.2 Debug Procedures

**Enable Debug Logging:**
```swift
#if DEBUG
let logLevel = LogLevel.verbose
UserDefaults.standard.set(true, forKey: "enableDebugLogging")
#endif
```

**Collect Diagnostic Data:**
```bash
# Device logs
xcrun devicectl device log collect --device $DEVICE_ID

# Crash reports
xcrun devicectl device crash list --device $DEVICE_ID

# Performance data
xcrun devicectl device performance monitor --device $DEVICE_ID
```

## 8. Security Considerations

### 8.1 Code Signing Verification

**Verify Signatures:**
```bash
# Check app signature
codesign -dv --verbose=4 IntraHabits.app

# Verify certificate chain
codesign -dv --verbose=4 --extract-certificates IntraHabits.app

# Check entitlements
codesign -d --entitlements :- IntraHabits.app
```

### 8.2 Data Protection

**Encryption Verification:**
- CoreData encryption enabled
- Keychain storage for sensitive data
- CloudKit end-to-end encryption
- App Transport Security enforced

### 8.3 Privacy Compliance

**Data Handling:**
- No third-party analytics
- Minimal data collection
- User consent for CloudKit sync
- GDPR compliance for EU users

## 9. Performance Optimization

### 9.1 App Size Optimization

**Reduce IPA Size:**
```bash
# Enable app thinning
# Remove unused assets
# Optimize image compression
# Strip debug symbols in release
```

### 9.2 Launch Time Optimization

**Startup Performance:**
- Lazy loading of non-critical components
- Optimized CoreData stack initialization
- Minimal main thread blocking
- Efficient view hierarchy

### 9.3 Memory Management

**Memory Optimization:**
- Proper view lifecycle management
- Efficient image caching
- Background task optimization
- Memory leak prevention

## 10. Maintenance and Updates

### 10.1 Update Process

**Regular Updates:**
1. Bug fixes and security patches
2. Feature enhancements
3. iOS version compatibility
4. Performance improvements

**Update Schedule:**
- **Hotfixes**: As needed (critical issues)
- **Minor Updates**: Monthly (features/improvements)
- **Major Updates**: Quarterly (significant features)

### 10.2 Version Management

**Versioning Strategy:**
- Semantic versioning (MAJOR.MINOR.PATCH)
- Build numbers for internal tracking
- Release notes for each version
- Backward compatibility considerations

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Next Review**: Before each major release

