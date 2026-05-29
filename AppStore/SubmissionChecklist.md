# CardWise - App Store Submission Checklist

## Pre-Submission Requirements

### Apple Developer Account
- [ ] Register for Apple Developer Program ($99/year)
  - https://developer.apple.com/programs/enroll/
- [ ] Set up your developer team in Xcode
- [ ] Create App ID in Apple Developer Portal

### App Store Connect Setup
- [ ] Create new app in App Store Connect
- [ ] Fill in app metadata (name, subtitle, description)
- [ ] Add keywords
- [ ] Set up pricing (Free)
- [ ] Select age rating (4+)

### App Icon
- [ ] Generate 1024x1024 PNG app icon
  ```bash
  cd /Users/rich/Desktop/SmartCard/Scripts
  pip install Pillow
  python generate_app_icon.py
  ```
- [ ] Verify icon appears in Xcode Assets

### Screenshots
Required sizes for iPhone:
- [ ] 6.9" (iPhone 16 Pro Max): 1320 x 2868 pixels
- [ ] 6.7" (iPhone 15 Pro Max): 1290 x 2796 pixels
- [ ] 6.5" (iPhone 14 Plus): 1284 x 2778 pixels
- [ ] 5.5" (iPhone 8 Plus): 1242 x 2208 pixels

Recommended screenshots:
1. Home screen with card recommendations
2. Recommend view selecting a category
3. My Cards wallet view
4. Spending list with transactions
5. Analytics charts
6. Receipt scanning

### Privacy & Legal
- [x] Privacy Policy created (in-app)
- [x] Terms of Service created (in-app)
- [ ] Host privacy policy online (required URL for App Store)
- [ ] Set up support email: support@cardwiseapp.com

### Build Preparation
- [ ] Update DEVELOPMENT_TEAM in project.yml
- [ ] Run `xcodegen generate` to regenerate project
- [ ] Archive build in Xcode
- [ ] Upload to App Store Connect

---

## Technical Checklist

### Code Review
- [x] Remove all debug/test code
- [x] Verify no hardcoded API keys
- [x] Check for memory leaks
- [x] Test on multiple device sizes

### Features Testing
- [x] Card recommendation works correctly
- [x] Rotating categories display current quarter
- [x] Spending tracking saves/loads properly
- [x] Receipt OCR processes images
- [x] Charts display correctly
- [x] Settings save preferences
- [x] All navigation flows work

### Performance
- [x] App launches quickly
- [x] Smooth scrolling in lists
- [x] No UI freezing

### Accessibility
- [ ] VoiceOver works correctly
- [ ] Dynamic Type supported
- [ ] Sufficient color contrast

---

## Firebase Setup (Optional - for cloud sync)

If you want to enable Firebase:

1. Go to https://console.firebase.google.com
2. Create new project "CardWise"
3. Add iOS app with bundle ID: com.cardwise.app
4. Download GoogleService-Info.plist
5. Add to CardWise/Resources/
6. Enable Authentication (Email/Password, Apple)
7. Create Firestore database

---

## Submission Steps

1. **Archive Build**
   - Open CardWise.xcodeproj in Xcode
   - Select "Any iOS Device" as destination
   - Product → Archive
   - Wait for archive to complete

2. **Upload to App Store Connect**
   - In Organizer, select archive
   - Click "Distribute App"
   - Select "App Store Connect"
   - Upload

3. **Complete App Store Connect**
   - Add build to app version
   - Fill in "What's New"
   - Add screenshots
   - Submit for review

---

## Common Rejection Reasons to Avoid

1. **Crashes**: Test thoroughly on real devices
2. **Incomplete information**: Fill all metadata fields
3. **Broken links**: Verify privacy policy URL works
4. **Placeholder content**: Remove all "Lorem ipsum" or test data
5. **Missing permissions explanation**: Camera/Photo usage descriptions added

---

## Post-Launch

- [ ] Monitor App Store Connect for review status
- [ ] Respond to any review feedback
- [ ] Set up analytics monitoring
- [ ] Plan for version 1.1 updates

---

## Quick Commands

```bash
# Regenerate Xcode project
cd /Users/rich/Desktop/SmartCard
xcodegen generate

# Generate app icon
cd Scripts
pip install Pillow
python generate_app_icon.py

# Open project in Xcode
open CardWise.xcodeproj
```
