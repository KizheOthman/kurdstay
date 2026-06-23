# KurdStay

KurdStay is an Android hotel-booking application developed with Flutter and Firebase for the ICT602 Mobile Technology and Development group project.

The application is designed for the Kurdistan Region and supports three user roles:

- **Users** can search hotels, view locations, book rooms, manage bookings, receive QR codes, and submit reviews.
- **Hotel owners** can manage their hotels, room types, bookings, and guest check-ins.
- **Administrators** can manage users, roles, hotels, and bookings across the platform.

> This repository does not include private API keys, Firebase configuration files, service-account files, or signing credentials.

---

## Project Information

- **Course:** ICT602 Mobile Technology and Development
- **Project type:** Android mobile application
- **Framework:** Flutter
- **Backend:** Firebase
- **Target region:** Kurdistan Region
- **Application name:** KurdStay

---

## Main Features

### User Features

- Email and password registration
- Email verification
- Login and logout
- Forgot-password support
- Profile and credential management
- Hotel search by name or city
- Filter hotels by city and minimum rating
- Sort hotels by price and rating
- Hotel details and amenities
- Multiple hotel photographs
- Full-screen zoomable photo gallery
- Hotel and user locations on Google Maps
- GPS-based current-location access
- Multiple room types
- Booking creation
- Additional booking requests
- Booking cancellation
- Booking rescheduling
- Unique booking QR code
- Booking-status notifications
- Star ratings and reviews

### Hotel Owner Features

- Owner dashboard
- Create, read, update, and soft-delete hotels
- Upload multiple hotel images
- Choose hotel location on Google Maps
- Create and manage room types
- Set room price, capacity, and available quantity
- View hotel bookings
- Create manual bookings
- Confirm or cancel bookings
- Check guests in with QR scanning
- Complete bookings
- Manage owner profile and credentials

### Administrator Features

- Administration dashboard
- View all users
- Change user roles
- Manage users, owners, and administrators
- View all hotels
- Activate or deactivate hotels
- View all bookings
- Change booking status
- Preserve deleted records for administrative history
- Manage administrator profile and credentials

---

## Mobile Technology Features

KurdStay uses more than the four mobile-platform features required by the assignment:

1. **Google Maps**
   - Hotel markers
   - Hotel-location selection
   - Map-based hotel discovery

2. **GPS**
   - Current user location
   - Location permission handling

3. **Camera**
   - Hotel-photo capture and selection
   - QR-code scanning

4. **QR Code**
   - Booking QR generation
   - Owner check-in verification

5. **Push and Local Notifications**
   - Booking confirmation
   - Booking cancellation
   - Booking status changes
   - Foreground notification display

6. **Connectivity**
   - Online/offline connection monitoring

7. **Third-Party APIs**
   - Google Maps Platform
   - Firebase services

---

## Technology Stack

### Frontend

- Flutter
- Dart
- Material 3

### Firebase Services

- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Firebase Cloud Functions

### Main Flutter Packages

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `cloud_functions`
- `google_maps_flutter`
- `geolocator`
- `image_picker`
- `mobile_scanner`
- `qr_flutter`
- `cached_network_image`
- `photo_view`
- `flutter_local_notifications`
- `connectivity_plus`
- `intl`
- `uuid`

---

## Project Structure

```text
kurdstay/
├── android/
├── assets/
│   └── images/
│       └── app_logo.png
├── functions/
│   ├── src/
│   │   ├── index.ts
│   │   └── seed.ts
│   ├── package.json
│   └── tsconfig.json
├── lib/
│   ├── core/
│   │   └── app_theme.dart
│   ├── data/
│   │   ├── models.dart
│   │   └── services.dart
│   ├── ui/
│   │   ├── admin_app.dart
│   │   ├── auth_pages.dart
│   │   ├── common_widgets.dart
│   │   ├── owner_app.dart
│   │   ├── profile_page.dart
│   │   └── user_app.dart
│   ├── firebase_options.dart
│   └── main.dart
├── firestore.indexes.json
├── firestore.rules
├── storage.rules
├── firebase.json
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## Security and Private Configuration

The following files are intentionally excluded from GitHub:

```text
android/local.properties
android/key.properties
android/app/google-services.json
lib/firebase_options.dart
functions/.env
serviceAccountKey.json
*.jks
*.keystore
```

The repository should include:

```text
firestore.rules
firestore.indexes.json
storage.rules
firebase.json
pubspec.yaml
pubspec.lock
functions/package.json
functions/package-lock.json
functions/src/
```

Never commit:

- Google Maps API keys
- Service-account private keys
- Android signing keys
- Firebase Functions secrets
- `.env` files
- Private passwords

---

## Requirements

Before running the project, install:

- Flutter stable
- Dart
- Android Studio
- Android SDK
- Node.js 22
- Firebase CLI
- FlutterFire CLI
- A Firebase project
- A Google Maps Platform project

Check Flutter:

```bash
flutter doctor
```

---

## Firebase Setup

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 2. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 3. Connect the Flutter project to Firebase

From the project root:

```bash
flutterfire configure
```

This generates the private files:

```text
lib/firebase_options.dart
android/app/google-services.json
```

These files are excluded from GitHub and must be generated separately by each developer.

### 4. Enable Firebase services

In Firebase Console, enable:

- Authentication → Email/Password
- Cloud Firestore
- Firebase Storage
- Cloud Messaging
- Cloud Functions

### 5. Configure Firebase resources

```bash
firebase init firestore
firebase init storage
firebase init functions
```

Use:

- TypeScript for Cloud Functions
- Node.js 22
- Existing `firestore.rules`
- Existing `firestore.indexes.json`
- Existing `storage.rules`

---

## Google Maps Setup

### 1. Create a Google Maps API key

In Google Cloud Console:

- Enable **Maps SDK for Android**
- Create an API key
- Restrict the key to Android applications
- Add the KurdStay package name
- Add the SHA-1 certificate fingerprint
- Restrict the key to Maps SDK for Android

Package name:

```text
com.ict602.kurdstay
```

### 2. Obtain the Android SHA-1 fingerprint

On Windows:

```bash
cd android
gradlew signingReport
```

On macOS or Linux:

```bash
cd android
./gradlew signingReport
```

### 3. Add the key locally

Open:

```text
android/local.properties
```

Add:

```properties
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

Do not commit `android/local.properties`.

### 4. Android manifest placeholder

The application reads the private key through:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${MAPS_API_KEY}" />
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/KurdStay-ICT602.git
cd KurdStay-ICT602
```

Install Flutter dependencies:

```bash
flutter pub get
```

Generate Firebase configuration:

```bash
flutterfire configure
```

Add the Google Maps key to:

```text
android/local.properties
```

Install Cloud Functions dependencies:

```bash
cd functions
npm install
npm run build
cd ..
```

---

## Deploy Firebase Backend

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

Deploy Firestore indexes:

```bash
firebase deploy --only firestore:indexes
```

Deploy Storage rules:

```bash
firebase deploy --only storage
```

Deploy Cloud Functions:

```bash
firebase deploy --only functions
```

Deploy all Firebase resources:

```bash
firebase deploy
```

> Cloud Functions deployment may require the Firebase Blaze billing plan.

---

## Sample Data

The project includes a seed script for demonstration data:

```text
functions/src/seed.ts
```

Run:

```bash
cd functions
npm install
npm run seed
cd ..
```

The seed creates sample:

- Administrators
- Hotel owners
- Users
- Kurdistan-region hotels
- Room types

Do not use demonstration credentials in a public or production environment.

---

## Run the Application

Connect an Android emulator or physical Android device, then run:

```bash
flutter run
```

For a clean rebuild:

```bash
flutter clean
flutter pub get
flutter run
```

Check code quality:

```bash
flutter analyze
```

---

## Build the Android APK

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

Generated APK location:

```text
build/app/outputs/flutter-apk/
```

---

## Authentication and Roles

New accounts are created with the `user` role.

Available roles:

```text
user
owner
admin
```

Administrators can promote a user to hotel owner from the administration interface.

Role information is stored in:

```text
users/{userId}
```

Example:

```json
{
  "name": "Example User",
  "email": "user@example.com",
  "phone": "+964 770 000 0000",
  "role": "user",
  "active": true
}
```

Privileged operations are validated through Cloud Functions and Firebase Security Rules.

---

## Main Firestore Collections

```text
users
hotels
hotels/{hotelId}/rooms
bookings
reviews
roomInventory
notifications/{userId}/items
```

### Users

Stores:

- Profile data
- Role
- Account status
- Notification tokens

### Hotels

Stores:

- Hotel details
- Owner ID
- City and address
- Google Maps location
- Image URLs
- Amenities
- Rating
- Active and deleted status

### Rooms

Stores:

- Room type
- Capacity
- Price
- Available room quantity
- Images
- Amenities

### Bookings

Stores:

- User and owner
- Hotel and room
- Stay dates
- Guest details
- Booking status
- Price
- Special requests
- QR token
- Check-in status

### Reviews

Stores:

- Rating
- Comment
- Booking reference
- Hotel reference
- User reference

---

## Booking Status Flow

```text
pending
   ↓
confirmed
   ↓
checkedIn
   ↓
completed
```

A booking may also become:

```text
cancelled
```

Only confirmed bookings can be checked in using the QR scanner.

---

## QR Check-In Flow

1. A user creates a booking.
2. The owner confirms the booking.
3. The application generates a booking QR code.
4. The user presents the QR code at the hotel.
5. The hotel owner scans the QR code.
6. A Cloud Function validates:
   - Booking ID
   - QR security token
   - Hotel ownership
   - Booking status
   - Whether the code was already used
7. The booking status changes to `checkedIn`.

---

## Email Verification Flow

1. A user registers.
2. Firebase sends a verification email.
3. The user opens the verification link.
4. The user returns to KurdStay.
5. The app reloads the Firebase user automatically.
6. The app opens the correct role interface without requiring a restart.

---

## Notifications

KurdStay sends notifications when booking status changes, including:

- Booking confirmed
- Booking cancelled
- Guest checked in
- Booking completed
- Booking rescheduled

Firebase Cloud Messaging sends the push notification.

Flutter Local Notifications displays the message while the application is open.

---

## Soft Delete

Hotels and bookings should not be physically deleted when historical records are required.

A deleted hotel is marked with:

```json
{
  "deleted": true,
  "active": false
}
```

Deleted hotels are hidden from:

- Users
- Hotel owners
- Public hotel search
- Hotel map

They remain visible to administrators for audit and project-demonstration purposes.

---

## Screenshots

Create a folder such as:

```text
docs/screenshots/
```

Recommended screenshot names:

```text
login.png
register.png
verify-email.png
explore-hotels.png
hotel-details.png
hotel-map.png
booking-form.png
booking-qr.png
owner-dashboard.png
owner-hotels.png
qr-scanner.png
admin-dashboard.png
admin-users.png
```

Example Markdown:

```markdown
![Explore Hotels](docs/screenshots/explore-hotels.png)
```

---

## Testing Checklist

### Authentication

 Register a new account
 Receive verification email
 Verify without restarting the app
 Log in
 Reset password
 Log out

### User

 Search hotels
 Filter by city
 Sort by price
 Open map
 View hotel gallery
 Book a room
 Cancel a booking
 Reschedule a booking
 View QR code
 Submit a review

### Owner

 Create hotel
 Upload multiple photos
 Select map location
 Create room types
 Edit hotel
 Soft-delete hotel
 Create manual booking
 Confirm booking
 Scan guest QR
 Complete booking

### Administrator

 View users
 Change user role
 View hotels
 Activate or deactivate hotel
 View bookings
 Change booking status

### Mobile Features

 GPS permission
 Current location
 Google Maps
 Camera permission
 QR scanner
 Push notifications
 Local notifications
 Connectivity warning

---

## Troubleshooting

### Firebase configuration is missing

Run:

```bash
flutterfire configure
```

### Google Maps is blank

Check:

- Maps SDK for Android is enabled
- The API key is in `android/local.properties`
- The package name is correct
- SHA-1 is registered
- Billing is enabled if required
- API restrictions include Maps SDK for Android

### Cloud Function returns `INTERNAL`

Check logs:

```bash
firebase functions:log
```

Check one function:

```bash
firebase functions:log --only createBooking
```

### Firestore requests are denied

Check:

- User is signed in
- Firestore role is correct
- Security rules are deployed
- Owner ID matches the hotel owner
- The required composite index exists

Deploy rules and indexes again:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Notification is not received

Check:

- Notification permission is granted
- The device has an FCM token
- The token is saved under the user document
- Cloud Functions are deployed
- The notification channel is configured
- Firebase Cloud Messaging is enabled

### Email verification page does not change

Check that the application uses:

```dart
FirebaseAuth.instance.currentUser?.reload();
```

The app should also check when it returns to the foreground.

---

## GitHub Safety Check

Before pushing:

```bash
git status
git diff --cached --name-only
```

Search tracked files for common secrets:

```bash
git grep -n -E "AIza[0-9A-Za-z_-]{20,}|BEGIN PRIVATE KEY|private_key|client_secret"
```

Files that must not be staged:

```text
android/local.properties
android/app/google-services.json
lib/firebase_options.dart
functions/.env
serviceAccountKey.json
```

---

## GitHub Upload

Initialize Git:

```bash
git init
git add .
git status
git commit -m "Initial KurdStay ICT602 project"
```

Connect the repository:

```bash
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/KurdStay-ICT602.git
git push -u origin main
```

Use a private repository while the project is under development.

---

## Assignment Demonstration Flow

A recommended demonstration sequence:

1. Log in as administrator.
2. Change a user role to owner.
3. Log in as owner.
4. Create or edit a hotel.
5. Add hotel photographs.
6. Select the hotel location on the map.
7. Add room types.
8. Log in as user.
9. Search and filter hotels.
10. Open the hotel gallery and map.
11. Book a room.
12. Confirm the booking as the owner.
13. Show the user QR code.
14. Scan the QR code as the owner.
15. Complete the booking.
16. Submit a review as the user.
17. Show the received notification.

---

## Academic Use

This application was developed for an ICT602 university group project.

The repository is intended for:

- Academic assessment
- Demonstration
- Learning
- Portfolio presentation

Before production use, additional work is recommended for:

- Payment integration
- Legal terms and privacy policy
- Production monitoring
- Advanced testing
- Accessibility auditing
- Localization
- Backup and disaster recovery
- Hotel verification
- Fraud prevention

---

## Contributors

Add the four group members here:

```text
1. Hazhan Halwan QIU23-0418 
2. Kizhe Othman QIU23-0423 
3. Arwan Awat QIU23-0265 

```

---

## Links

Add the final project links:

```text
GitHub Repository:https://github.com/KizheOthman/kurdstay
Recorded Demonstration:https://youtu.be/0eke1OtaMqM
```

---

## License

This project is provided for academic and educational purposes.
