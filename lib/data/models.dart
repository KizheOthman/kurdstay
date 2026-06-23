import 'package:cloud_firestore/cloud_firestore.dart';

DateTime dateFromFirestore(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}

enum UserRole {
  user,
  owner,
  admin;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (item) => item.name == value,
      orElse: () => UserRole.user,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool active;
  final String? photoUrl;

  factory AppUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return AppUser(
      id: document.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String?),
      active: data['active'] as bool? ?? true,
      photoUrl: data['photoUrl'] as String?,
    );
  }
}

class Hotel {
  const Hotel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.amenities,
    required this.minimumPrice,
    required this.ratingAverage,
    required this.reviewCount,
    required this.active,
    required this.featured,
    required this.deleted,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> images;
  final List<String> amenities;
  final double minimumPrice;
  final double ratingAverage;
  final int reviewCount;
  final bool active;
  final bool featured;
  final bool deleted;

  factory Hotel.fromDocument( DocumentSnapshot<Map<String, dynamic>> document, ) { final data = document.data() ?? {}; final point = data['location']; return Hotel( id: document.id, ownerId: data['ownerId'] as String? ?? '', name: data['name'] as String? ?? '', description: data['description'] as String? ?? '', city: data['city'] as String? ?? '', address: data['address'] as String? ?? '', latitude: point is GeoPoint ? point.latitude : (data['latitude'] as num?)?.toDouble() ?? 0, longitude: point is GeoPoint ? point.longitude : (data['longitude'] as num?)?.toDouble() ?? 0, images: List<String>.from( data['images'] as List? ?? const [], ), amenities: List<String>.from( data['amenities'] as List? ?? const [], ), minimumPrice: (data['minimumPrice'] as num?)?.toDouble() ?? 0, ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0, reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0, active: data['active'] as bool? ?? true, featured: data['featured'] as bool? ?? false, deleted: data['deleted'] as bool? ?? false, ); }

  Map<String, dynamic> toMap() { return { 'ownerId': ownerId, 'name': name.trim(), 'description': description.trim(), 'city': city, 'address': address.trim(), 'location': GeoPoint(latitude, longitude), 'images': images, 'amenities': amenities, 'minimumPrice': minimumPrice, 'ratingAverage': ratingAverage, 'reviewCount': reviewCount, 'active': active, 'featured': featured, 'deleted': deleted, 'updatedAt': FieldValue.serverTimestamp(), }; }

  Hotel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? images,
    List<String>? amenities,
    double? minimumPrice,
    double? ratingAverage,
    int? reviewCount,
    bool? active,
    bool? featured,
    bool? deleted,
  }) {
    return Hotel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      reviewCount: reviewCount ?? this.reviewCount,
      active: active ?? this.active,
      featured: featured ?? this.featured,
      deleted: deleted ?? this.deleted,
    );
  }
}

class Room {
  const Room({
    required this.id,
    required this.hotelId,
    required this.name,
    required this.type,
    required this.description,
    required this.pricePerNight,
    required this.capacity,
    required this.totalRooms,
    required this.images,
    required this.amenities,
    required this.active,
  });

  final String id;
  final String hotelId;
  final String name;
  final String type;
  final String description;
  final double pricePerNight;
  final int capacity;
  final int totalRooms;
  final List<String> images;
  final List<String> amenities;
  final bool active;

  factory Room.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return Room(
      id: document.id,
      hotelId: data['hotelId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pricePerNight:
          (data['pricePerNight'] as num?)?.toDouble() ?? 0,
      capacity: (data['capacity'] as num?)?.toInt() ?? 1,
      totalRooms: (data['totalRooms'] as num?)?.toInt() ?? 1,
      images: List<String>.from(data['images'] as List? ?? const []),
      amenities:
          List<String>.from(data['amenities'] as List? ?? const []),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hotelId': hotelId,
      'name': name.trim(),
      'type': type.trim(),
      'description': description.trim(),
      'pricePerNight': pricePerNight,
      'capacity': capacity,
      'totalRooms': totalRooms,
      'images': images,
      'amenities': amenities,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.hotelId,
    required this.hotelName,
    required this.roomId,
    required this.roomName,
    required this.ownerId,
    required this.userId,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.totalPrice,
    required this.status,
    required this.qrToken,
    required this.specialRequests,
    required this.paymentMethod,
    required this.createdBy,
    required this.qrUsed,
  });

  final String id;
  final String hotelId;
  final String hotelName;
  final String roomId;
  final String roomName;
  final String ownerId;
  final String? userId;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double totalPrice;
  final String status;
  final String qrToken;
  final String specialRequests;
  final String paymentMethod;
  final String createdBy;
  final bool qrUsed;

  factory Booking.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return Booking(
      id: document.id,
      hotelId: data['hotelId'] as String? ?? '',
      hotelName: data['hotelName'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      userId: data['userId'] as String?,
      guestName: data['guestName'] as String? ?? '',
      guestEmail: data['guestEmail'] as String? ?? '',
      guestPhone: data['guestPhone'] as String? ?? '',
      checkIn: dateFromFirestore(data['checkIn']),
      checkOut: dateFromFirestore(data['checkOut']),
      guests: (data['guests'] as num?)?.toInt() ?? 1,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'pending',
      qrToken: data['qrToken'] as String? ?? '',
      specialRequests: data['specialRequests'] as String? ?? '',
      paymentMethod:
          data['paymentMethod'] as String? ?? 'pay_at_hotel',
      createdBy: data['createdBy'] as String? ?? 'user',
      qrUsed: data['qrUsed'] as bool? ?? false,
    );
  }

  bool get canBeChanged =>
      status == 'pending' || status == 'confirmed';

  bool get canReview => status == 'completed';

  String get qrData {
    return '{"app":"kurdstay","bookingId":"$id","token":"$qrToken"}';
  }
}

class Review {
  const Review({
    required this.id,
    required this.hotelId,
    required this.bookingId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String hotelId;
  final String bookingId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  factory Review.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return Review(
      id: document.id,
      hotelId: data['hotelId'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Guest',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      comment: data['comment'] as String? ?? '',
      createdAt: dateFromFirestore(data['createdAt']),
    );
  }
}