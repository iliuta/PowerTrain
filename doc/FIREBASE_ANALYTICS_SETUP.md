# Firebase Analytics Setup Guide

This guide explains how to complete the Firebase Analytics setup for the FTMS app.

## Prerequisites

1. A Google account
2. Firebase CLI installed (optional, for command-line setup)

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter a project name (e.g., "FTMS Fitness App")
4. Enable Google Analytics for this project (recommended)
5. Choose or create a Google Analytics account
6. Click "Create project"

## Step 2: Add Android App to Firebase

1. In Firebase Console, click "Add app" and select Android
2. Enter the Android package name: `com.iliuta.ftms`
3. (Optional) Enter app nickname: "FTMS"
4. (Optional) Enter Debug signing certificate SHA-1 (for advanced features)
5. Click "Register app"
6. Download `google-services.json`
7. Place it in: `android/app/google-services.json`

### Update Android Configuration

Add the Google Services plugin to `android/build.gradle`:

```gradle
plugins {
    // ... existing plugins
    id 'com.google.gms.google-services' version '4.4.2' apply false
}
```

Add the plugin to `android/app/build.gradle`:

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id 'com.google.gms.google-services'  // Add this line
}
```

## Step 3: Add iOS App to Firebase

1. In Firebase Console, click "Add app" and select iOS
2. Enter the iOS bundle ID: `com.iliuta.ftms` (check in Xcode if different)
3. (Optional) Enter app nickname: "FTMS"
4. Click "Register app"
5. Download `GoogleService-Info.plist`
6. Open `ios/Runner.xcworkspace` in Xcode
7. Right-click on `Runner` folder → "Add Files to Runner"
8. Select `GoogleService-Info.plist`
9. Ensure "Copy items if needed" is checked
10. Click "Add"

## Step 4: Install Dependencies

Run the following command to install the Firebase packages:

```bash
flutter pub get
```

## Step 5: Verify Setup

Build and run the app:

```bash
flutter run
```

Check the console for the message:
```
🔥 Firebase initialized successfully
```

## Analytics Events Tracked

The app tracks the following events by machine type (rower/indoor bike):

### Training Session Events

| Event Name | Description | Parameters |
|------------|-------------|------------|
| `training_session_created` | User creates a new custom training session | `machine_type`, `is_distance_based`, `interval_count` |
| `training_session_edited` | User edits an existing training session | `machine_type`, `is_distance_based`, `interval_count` |
| `training_session_deleted` | User deletes a custom training session | `machine_type` |
| `training_session_selected` | User selects a training session to start | `machine_type`, `session_title`, `is_custom`, `is_distance_based` |
| `training_session_started` | User starts a training session | `machine_type`, `is_distance_based`, `is_free_ride`, `total_duration_seconds`, `interval_count` |
| `training_session_completed` | User completes a training session naturally | `machine_type`, `is_distance_based`, `is_free_ride`, `elapsed_time_seconds`, `total_distance_meters`, `total_calories` |
| `training_session_cancelled` | User stops a session before completion | `machine_type`, `is_distance_based`, `is_free_ride`, `elapsed_time_seconds`, `completion_percentage` |
| `training_session_paused` | User pauses a training session | `machine_type`, `is_free_ride`, `elapsed_time_seconds` |
| `training_session_resumed` | User resumes a paused training session | `machine_type`, `is_free_ride`, `elapsed_time_seconds` |
| `training_session_extended` | User extends a completed session | `machine_type`, `is_free_ride`, `elapsed_time_seconds` |

### Free Ride Events

| Event Name | Description | Parameters |
|------------|-------------|------------|
| `free_ride_started` | User starts a free ride session | `machine_type`, `is_distance_based`, `target_value`, `has_warmup`, `has_cooldown`, `resistance_level`, `has_gpx_route` |

### Feature Usage Events

| Event Name | Description | Parameters |
|------------|-------------|------------|
| `training_sessions_viewed` | User views the training sessions list | `machine_type`, `session_count` |
| `fit_file_saved` | A FIT file is saved after workout | `machine_type`, `duration_seconds`, `distance_meters`, `calories` |
| `strava_upload` | Workout uploaded to Strava | `machine_type`, `success`, `duration_seconds` |
| `device_connected` | FTMS device connected | `machine_type`, `device_name` |
| `device_disconnected` | FTMS device disconnected | `machine_type`, `device_name` |

## Viewing Analytics in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to "Analytics" → "Events"
4. View events in real-time under "DebugView" (requires enabling debug mode)

### Enable Debug Mode (for testing)

On Android:
```bash
adb shell setprop debug.firebase.analytics.app com.iliuta.ftms
```

On iOS, add `-FIRDebugEnabled` to your scheme arguments in Xcode.

## Creating Custom Reports

In Firebase Analytics:

1. Go to "Analytics" → "Custom definitions"
2. Create custom dimensions for:
   - `machine_type` (user-scoped)
   - `is_free_ride` (event-scoped)
   - `is_distance_based` (event-scoped)

3. Go to "Analytics" → "Explore" to create:
   - **Feature Usage Report**: Compare event counts by `machine_type`
   - **Session Completion Funnel**: `training_session_started` → `training_session_completed`
   - **Engagement by Machine Type**: Session duration by `machine_type`

## Recommended BigQuery Export (Optional)

For advanced analysis, enable BigQuery export:

1. In Firebase Console, go to "Project settings"
2. Click "Integrations" → "BigQuery"
3. Enable BigQuery linking

This allows you to run SQL queries on your analytics data for detailed reports.

## Troubleshooting

### Firebase not initializing

1. Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
2. Check that package/bundle ID matches what's registered in Firebase
3. Run `flutter clean && flutter pub get`

### Events not appearing in Firebase Console

- Events may take up to 24 hours to appear in standard reports
- Use DebugView for real-time testing
- Verify analytics is initialized by checking console logs

### Missing platform configuration

If you see errors about missing Firebase configuration:
- For Android: Ensure Google Services plugin is applied
- For iOS: Ensure GoogleService-Info.plist is added to Xcode project (not just the folder)
