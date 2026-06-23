import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<User?> get userChanges => auth.userChanges();

  User? get currentUser => auth.currentUser;

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a user.');
    }

    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();

    await firestore.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'role': 'user',
      'active': true,
      'photoUrl': null,
      'fcmTokens': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendVerification() async {
    await auth.currentUser?.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerification() async {
  final currentUser = auth.currentUser;

  if (currentUser == null) {
    return false;
  }

  // Download the latest account data from Firebase.
  await currentUser.reload();

  final refreshedUser = auth.currentUser;

  if (refreshedUser == null) {
    return false;
  }

  if (refreshedUser.emailVerified) {
    // Refresh the authentication token after verification.
    await refreshedUser.getIdToken(true);
  }

  return refreshedUser.emailVerified;
}

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('No authenticated user.');

    await user.updateDisplayName(name.trim());

    await firestore.collection('users').doc(user.uid).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = auth.currentUser;
    final oldEmail = user?.email;

    if (user == null || oldEmail == null) {
      throw StateError('No password account is currently signed in.');
    }

    final credential = EmailAuthProvider.credential(
      email: oldEmail,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw StateError('No password account is currently signed in.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}

class DatabaseService {
  DatabaseService._();

  static final instance = DatabaseService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userReference(String id) {
    return db.collection('users').doc(id);
  }

  Stream<AppUser?> userStream(String id) {
    return userReference(id).snapshots().map(
          (document) =>
              document.exists ? AppUser.fromDocument(document) : null,
        );
  }

  Stream<List<AppUser>> allUsers() {
    return db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppUser.fromDocument).toList(),
        );
  }

  Stream<List<Hotel>> activeHotels() { return db .collection('hotels') .where('active', isEqualTo: true) .snapshots() .map((snapshot) { final hotels = snapshot.docs .map(Hotel.fromDocument) .where((hotel) => !hotel.deleted) .toList(); hotels.sort( (a, b) => b.featured == a.featured ? b.ratingAverage.compareTo(a.ratingAverage) : b.featured ? 1 : -1, ); return hotels; }); }

  Stream<List<Hotel>> allHotels() {
    return db.collection('hotels').snapshots().map(
          (snapshot) =>
              snapshot.docs.map(Hotel.fromDocument).toList(),
        );
  }

  Stream<List<Hotel>> ownerHotels(String ownerId) { return db .collection('hotels') .where('ownerId', isEqualTo: ownerId) .snapshots() .map((snapshot) { final hotels = snapshot.docs .map(Hotel.fromDocument) .where((hotel) => !hotel.deleted) .toList(); hotels.sort( (a, b) => a.name.compareTo(b.name), ); return hotels; }); }

  String newHotelId() => db.collection('hotels').doc().id;

  Future<void> saveHotel(Hotel hotel, {required bool isNew}) async {
    final reference = db.collection('hotels').doc(hotel.id);

    if (isNew) {
      await reference.set({
        ...hotel.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.update(hotel.toMap());
    }
  }

  Future<void> updateHotelState({
    required String hotelId,
    required bool active,
  }) async {
    await db.collection('hotels').doc(hotelId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHotel(String hotelId) async { await db.collection('hotels').doc(hotelId).update({ 'deleted': true, 'active': false, 'deletedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(), }); }

  Stream<List<Room>> rooms(String hotelId) {
    return db
        .collection('hotels')
        .doc(hotelId)
        .collection('rooms')
        .snapshots()
        .map((snapshot) {
      final values = snapshot.docs.map(Room.fromDocument).toList();
      values.sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
      return values;
    });
  }

  String newRoomId(String hotelId) {
    return db
        .collection('hotels')
        .doc(hotelId)
        .collection('rooms')
        .doc()
        .id;
  }

  Future<void> saveRoom(Room room, {required bool isNew}) async {
    final reference = db
        .collection('hotels')
        .doc(room.hotelId)
        .collection('rooms')
        .doc(room.id);

    if (isNew) {
      await reference.set({
        ...room.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.update(room.toMap());
    }

    final roomsSnapshot = await db
        .collection('hotels')
        .doc(room.hotelId)
        .collection('rooms')
        .where('active', isEqualTo: true)
        .get();

    final prices = roomsSnapshot.docs
        .map((document) =>
            (document.data()['pricePerNight'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (prices.isNotEmpty) {
      prices.sort();
      await db.collection('hotels').doc(room.hotelId).update({
        'minimumPrice': prices.first,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteRoom({
    required String hotelId,
    required String roomId,
  }) async {
    await db
        .collection('hotels')
        .doc(hotelId)
        .collection('rooms')
        .doc(roomId)
        .delete();
  }

  Stream<List<Booking>> userBookings(String userId) {
    return db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Booking.fromDocument).toList(),
        );
  }

  Stream<List<Booking>> ownerBookings(String ownerId) {
    return db
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Booking.fromDocument).toList(),
        );
  }

  Stream<List<Booking>> allBookings() {
    return db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Booking.fromDocument).toList(),
        );
  }

  Stream<List<Review>> hotelReviews(String hotelId) {
    return db
        .collection('reviews')
        .where('hotelId', isEqualTo: hotelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Review.fromDocument).toList(),
        );
  }

  Future<void> addReview({
    required Booking booking,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw StateError('You must be signed in.');

    final id = '${booking.id}_${user.uid}';

    await db.collection('reviews').doc(id).set({
      'hotelId': booking.hotelId,
      'bookingId': booking.id,
      'userId': user.uid,
      'userName': userName,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class StorageService {
  StorageService._();

  static final instance = StorageService._();

  final FirebaseStorage storage = FirebaseStorage.instance;
  final Uuid uuid = const Uuid();

  Future<List<String>> uploadHotelImages({
    required String ownerId,
    required String hotelId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];

    for (final file in files) {
      final Uint8List data = await file.readAsBytes();
      final extension =
          file.name.contains('.') ? file.name.split('.').last : 'jpg';

      final reference = storage.ref(
        'hotel_images/$ownerId/$hotelId/${uuid.v4()}.$extension',
      );

      await reference.putData(
        data,
        SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
      );

      urls.add(await reference.getDownloadURL());
    }

    return urls;
  }
}

class BackendService {
  BackendService._();

  static final instance = BackendService._();

  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<String> createBooking({
    required String hotelId,
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required String specialRequests,
  }) async {
    final result =
        await functions.httpsCallable('createBooking').call({
      'hotelId': hotelId,
      'roomId': roomId,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'guests': guests,
      'specialRequests': specialRequests.trim(),
      'paymentMethod': 'pay_at_hotel',
    });

    return (result.data as Map)['bookingId'] as String;
  }

  Future<String> createManualBooking({
    required String hotelId,
    required String roomId,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required String specialRequests,
  }) async {
    final result =
        await functions.httpsCallable('createManualBooking').call({
      'hotelId': hotelId,
      'roomId': roomId,
      'guestName': guestName.trim(),
      'guestEmail': guestEmail.trim(),
      'guestPhone': guestPhone.trim(),
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'guests': guests,
      'specialRequests': specialRequests.trim(),
      'paymentMethod': 'pay_at_hotel',
    });

    return (result.data as Map)['bookingId'] as String;
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await functions.httpsCallable('updateBookingStatus').call({
      'bookingId': bookingId,
      'status': status,
    });
  }

  Future<void> cancelBooking(String bookingId) async {
    await functions.httpsCallable('cancelBooking').call({
      'bookingId': bookingId,
    });
  }

  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    await functions.httpsCallable('rescheduleBooking').call({
      'bookingId': bookingId,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> verifyQr(String rawValue) async {
    final result =
        await functions.httpsCallable('verifyBookingQr').call({
      'qrData': rawValue,
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> setUserRole({
    required String userId,
    required UserRole role,
  }) async {
    await functions.httpsCallable('setUserRole').call({
      'userId': userId,
      'role': role.name,
    });
  }
}

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  Future<Position> determinePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is permanently denied. Open app settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  String? _boundUserId;

  Future<void> initialize() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      settings: initializationSettings,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(showForegroundMessage);
  }

  Future<void> bindToUser(String userId) async {
    if (_boundUserId == userId) return;
    _boundUserId = userId;

    final token = await messaging.getToken();

    if (token != null) {
      await _saveToken(userId, token);
    }

    await _tokenSubscription?.cancel();

    _tokenSubscription = messaging.onTokenRefresh.listen(
      (newToken) => _saveToken(userId, newToken),
    );
  }

  Future<void> _saveToken(String userId, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> showForegroundMessage(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'booking_updates',
      'Booking updates',
      channelDescription:
          'Confirmation, cancellation and check-in notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: message.notification?.title ?? 'KurdStay',
      body: message.notification?.body ?? 'Your booking was updated.',
      notificationDetails: details,
      payload: message.data['bookingId'] as String?,
    );
  }
}