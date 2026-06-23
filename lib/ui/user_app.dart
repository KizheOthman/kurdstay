import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'common_widgets.dart';
import 'profile_page.dart';

class UserApp extends StatefulWidget {
  const UserApp({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  State<UserApp> createState() => _UserAppState();
}

class _UserAppState extends State<UserApp> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ExplorePage(),
      const HotelMapPage(),
      MyBookingsPage(user: widget.user),
      ProfilePage(user: widget.user),
    ];

    final titles = [
      'Explore',
      'Hotel map',
      'My bookings',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[index])),
      body: NetworkStatusBanner(
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_online_outlined),
            selectedIcon: Icon(Icons.book_online_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final searchController = TextEditingController();

  String city = 'All';
  String sort = 'Recommended';
  double minimumRating = 0;

  static const cities = [
    'All',
    'Sulaymaniyah',
    'Erbil',
    'Duhok',
    'Halabja',
    'Rawanduz',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Hotel> filter(List<Hotel> source) {
    final text = searchController.text.trim().toLowerCase();

    final result = source.where((hotel) {
      final searchMatches = text.isEmpty ||
          hotel.name.toLowerCase().contains(text) ||
          hotel.city.toLowerCase().contains(text) ||
          hotel.address.toLowerCase().contains(text);

      final cityMatches = city == 'All' || hotel.city == city;
      final ratingMatches = hotel.ratingAverage >= minimumRating;

      return searchMatches && cityMatches && ratingMatches;
    }).toList();

    switch (sort) {
      case 'Price: low to high':
        result.sort(
          (a, b) => a.minimumPrice.compareTo(b.minimumPrice),
        );
      case 'Price: high to low':
        result.sort(
          (a, b) => b.minimumPrice.compareTo(a.minimumPrice),
        );
      case 'Highest rated':
        result.sort(
          (a, b) => b.ratingAverage.compareTo(a.ratingAverage),
        );
      default:
        result.sort(
          (a, b) => b.featured == a.featured
              ? b.ratingAverage.compareTo(a.ratingAverage)
              : b.featured
                  ? 1
                  : -1,
        );
    }

    return result;
  }

  Future<void> openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SectionHeader(title: 'Search filters'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: city,
                    decoration:
                        const InputDecoration(labelText: 'City'),
                    items: cities
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => city = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: sort,
                    decoration:
                        const InputDecoration(labelText: 'Sort'),
                    items: const [
                      'Recommended',
                      'Price: low to high',
                      'Price: high to low',
                      'Highest rated',
                    ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => sort = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Minimum rating'),
                      const Spacer(),
                      Text(
                        minimumRating == 0
                            ? 'Any'
                            : minimumRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: minimumRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    onChanged: (value) => setSheetState(
                      () => minimumRating = value,
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Hotel>>(
      stream: DatabaseService.instance.activeHotels(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!);
        }

        if (!snapshot.hasData) return const LoadingView();

        final hotels = filter(snapshot.data!);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find your next stay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Hotels across the Kurdistan Region',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.travel_explore_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search hotels or cities',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    onPressed: openFilters,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: '${hotels.length} hotels',
              ),
              const SizedBox(height: 10),
              if (hotels.isEmpty)
                const SizedBox(
                  height: 300,
                  child: EmptyView(
                    title: 'No matching hotels',
                    message:
                        'Change the city, rating or search text.',
                    icon: Icons.hotel_outlined,
                  ),
                )
              else
                ...hotels.map(
                  (hotel) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: HotelCard(
                      hotel: hotel,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HotelDetailsPage(hotel: hotel),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class HotelDetailsPage extends StatefulWidget {
  const HotelDetailsPage({
    required this.hotel,
    super.key,
  });

  final Hotel hotel;

  @override
  State<HotelDetailsPage> createState() =>
      _HotelDetailsPageState();
}

class _HotelDetailsPageState extends State<HotelDetailsPage> {
  int imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;

    return Scaffold(
      appBar: AppBar(title: Text(hotel.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SizedBox(
            height: 255,
            child: hotel.images.isEmpty
                ? const ColoredBox(
                    color: AppColors.blush,
                    child: Icon(
                      Icons.hotel,
                      size: 70,
                      color: AppColors.primary,
                    ),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: hotel.images.length,
                        onPageChanged: (value) =>
                            setState(() => imageIndex = value),
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FullGalleryPage(
                                images: hotel.images,
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: hotel.images[index],
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${imageIndex + 1}/${hotel.images.length}',
                            style:
                                const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                    ),
                    Text(
                      hotel.ratingAverage.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${hotel.address}, ${hotel.city}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 15),
                Text(
                  hotel.description,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hotel.amenities
                      .map(
                        (amenity) => Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          label: Text(amenity),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SingleHotelMapPage(
                        hotel: hotel,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View location on map'),
                ),
                const SizedBox(height: 22),
                const SectionHeader(title: 'Available room types'),
                const SizedBox(height: 10),
                StreamBuilder<List<Room>>(
                  stream:
                      DatabaseService.instance.rooms(hotel.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(error: snapshot.error!);
                    }

                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 120,
                        child: LoadingView(),
                      );
                    }

                    final rooms = snapshot.data!
                        .where((room) => room.active)
                        .toList();

                    if (rooms.isEmpty) {
                      return const EmptyView(
                        title: 'No rooms available',
                        message:
                            'This hotel has not published rooms yet.',
                      );
                    }

                    return Column(
                      children: rooms
                          .map(
                            (room) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 11),
                              child: RoomCard(
                                room: room,
                                onBook: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        BookingFormPage(
                                      hotel: hotel,
                                      room: room,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Guest reviews',
                  actionText: '${hotel.reviewCount} reviews',
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Review>>(
                  stream: DatabaseService.instance
                      .hotelReviews(hotel.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const LoadingView();
                    }

                    final reviews = snapshot.data!;

                    if (reviews.isEmpty) {
                      return const Text(
                        'No reviews yet.',
                        style: TextStyle(color: AppColors.muted),
                      );
                    }

                    return Column(
                      children: reviews.take(5).map((review) {
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.blush,
                              child: Text(
                                review.userName.isEmpty
                                    ? '?'
                                    : review.userName[0],
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(review.userName),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                Text(
                                  review.rating
                                      .toStringAsFixed(1),
                                ),
                              ],
                            ),
                            subtitle: Text(review.comment),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    required this.room,
    required this.onBook,
    super.key,
  });

  final Room room;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (room.images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: room.images.first,
                  width: 95,
                  height: 95,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bed_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${room.type} • Up to ${room.capacity} guests',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${room.pricePerNight.toStringAsFixed(0)} IQD / night',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      onPressed: onBook,
                      child: const Text('Book room'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingFormPage extends StatefulWidget {
  const BookingFormPage({
    required this.hotel,
    required this.room,
    super.key,
  });

  final Hotel hotel;
  final Room room;

  @override
  State<BookingFormPage> createState() =>
      _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  DateTime? checkIn;
  DateTime? checkOut;
  int guests = 1;
  bool loading = false;

  final requestsController = TextEditingController();

  int get nights {
    if (checkIn == null || checkOut == null) return 0;
    return checkOut!.difference(checkIn!).inDays;
  }

  double get total => nights * widget.room.pricePerNight;

  Future<void> selectDates() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: checkIn != null && checkOut != null
          ? DateTimeRange(start: checkIn!, end: checkOut!)
          : null,
    );

    if (range != null) {
      setState(() {
        checkIn = range.start;
        checkOut = range.end;
      });
    }
  }

  Future<void> submit() async {
    if (checkIn == null || checkOut == null || nights < 1) {
      showMessage(
        context,
        'Select a valid check-in and check-out date.',
        error: true,
      );
      return;
    }

    if (guests > widget.room.capacity) {
      showMessage(
        context,
        'This room supports ${widget.room.capacity} guests.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final bookingId =
          await BackendService.instance.createBooking(
        hotelId: widget.hotel.id,
        roomId: widget.room.id,
        checkIn: checkIn!,
        checkOut: checkOut!,
        guests: guests,
        specialRequests: requestsController.text,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 62,
          ),
          title: const Text('Booking submitted'),
          content: Text(
            'Booking $bookingId was created. '
            'The hotel owner will receive it immediately.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context);
        } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'createBooking Firebase error: '
        '${error.code} - ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      showMessage(
        context,
        error.message ??
            'The booking could not be created. '
            'Firebase error: ${error.code}',
        error: true,
      );
    } catch (error, stackTrace) {
      debugPrint('createBooking unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      showMessage(
        context,
        'The booking could not be created.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    requestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.blush,
                child: Icon(
                  Icons.bed_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: Text(widget.hotel.name),
              subtitle: Text(widget.room.name),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              onTap: selectDates,
              leading: const Icon(
                Icons.date_range_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Stay dates'),
              subtitle: Text(
                checkIn == null
                    ? 'Tap to select check-in and check-out'
                    : '${formatter.format(checkIn!)} – '
                        '${formatter.format(checkOut!)}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: guests,
            decoration: const InputDecoration(
              labelText: 'Guests',
              prefixIcon: Icon(Icons.group_outlined),
            ),
            items: List.generate(
              widget.room.capacity,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1} guest(s)'),
              ),
            ),
            onChanged: (value) {
              if (value != null) setState(() => guests = value);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: requestsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Additional requests',
              hintText:
                  'Extra bed, late arrival, accessibility needs...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Price per night',
                    value:
                        '${widget.room.pricePerNight.toStringAsFixed(0)} IQD',
                  ),
                  _PriceRow(
                    label: 'Number of nights',
                    value: '$nights',
                  ),
                  const Divider(),
                  _PriceRow(
                    label: 'Total',
                    value: '${total.toStringAsFixed(0)} IQD',
                    bold: true,
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Payment method: Pay at hotel',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: loading ? null : submit,
            child: loading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                : const Text('Confirm booking'),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style.copyWith(
              color: bold ? AppColors.primary : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({
    required this.user,
    super.key,
  });

  final AppUser user;

  Future<void> reschedule(
    BuildContext context,
    Booking booking,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (range == null) return;

    try {
      await BackendService.instance.rescheduleBooking(
        bookingId: booking.id,
        checkIn: range.start,
        checkOut: range.end,
      );

      if (context.mounted) {
        showMessage(context, 'Booking rescheduled.');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  Future<void> cancel(
    BuildContext context,
    Booking booking,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Cancel booking',
      message:
          'The selected room will be released. Continue?',
      confirmText: 'Cancel booking',
    );

    if (!confirmed) return;

    try {
      await BackendService.instance.cancelBooking(booking.id);

      if (context.mounted) {
        showMessage(context, 'Booking cancelled.');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  Future<void> addReview(
    BuildContext context,
    Booking booking,
  ) async {
    double rating = 5;
    final comment = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate your stay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () =>
                        setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your review',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );

    if (submit != true) return;

    try {
      await DatabaseService.instance.addReview(
        booking: booking,
        userName: user.name,
        rating: rating,
        comment: comment.text,
      );

      if (context.mounted) {
        showMessage(context, 'Review published.');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: DatabaseService.instance.userBookings(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!);
        }

        if (!snapshot.hasData) return const LoadingView();

        final bookings = snapshot.data!;

        if (bookings.isEmpty) {
          return const EmptyView(
            title: 'No bookings yet',
            message:
                'Explore hotels and reserve your first room.',
            icon: Icons.book_online_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final booking = bookings[index];

            return BookingCard(
              booking: booking,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BookingQrPage(booking: booking),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('QR code'),
                ),
                if (booking.canBeChanged)
                  OutlinedButton(
                    onPressed: () => reschedule(context, booking),
                    child: const Text('Reschedule'),
                  ),
                if (booking.canBeChanged)
                  TextButton(
                    onPressed: () => cancel(context, booking),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (booking.canReview)
                  FilledButton.tonalIcon(
                    onPressed: () => addReview(context, booking),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Review'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class BookingQrPage extends StatelessWidget {
  const BookingQrPage({
    required this.booking,
    super.key,
  });

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking QR')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KurdStayLogo(size: 54, showName: false),
                  const SizedBox(height: 16),
                  Text(
                    booking.hotelName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    booking.roomName,
                    style:
                        const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  QrImageView(
                    data: booking.qrData,
                    version: QrVersions.auto,
                    size: 230,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 18),
                  StatusChip(booking.status),
                  const SizedBox(height: 12),
                  Text(
                    booking.status == 'confirmed'
                        ? 'Show this code to the hotel owner at check-in.'
                        : 'The code becomes valid after the booking is confirmed.',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HotelMapPage extends StatefulWidget {
  const HotelMapPage({super.key});

  @override
  State<HotelMapPage> createState() => _HotelMapPageState();
}

class _HotelMapPageState extends State<HotelMapPage> {
  LatLng initialPosition =
      const LatLng(35.5613, 45.4309);

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  Future<void> loadLocation() async {
    try {
      final position =
          await LocationService.instance.determinePosition();

      if (mounted) {
        setState(
          () => initialPosition =
              LatLng(position.latitude, position.longitude),
        );
      }
    } catch (_) {
      // The map still works from the default Kurdistan location.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Hotel>>(
      stream: DatabaseService.instance.activeHotels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingView();

        final hotels = snapshot.data!;
        final markers = hotels.map((hotel) {
          return Marker(
            markerId: MarkerId(hotel.id),
            position: LatLng(hotel.latitude, hotel.longitude),
            infoWindow: InfoWindow(
              title: hotel.name,
              snippet:
                  '${hotel.minimumPrice.toStringAsFixed(0)} IQD',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HotelDetailsPage(hotel: hotel),
                ),
              ),
            ),
          );
        }).toSet();

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: 11,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          zoomControlsEnabled: false,
        );
      },
    );
  }
}

class SingleHotelMapPage extends StatelessWidget {
  const SingleHotelMapPage({
    required this.hotel,
    super.key,
  });

  final Hotel hotel;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(hotel.latitude, hotel.longitude);

    return Scaffold(
      appBar: AppBar(title: Text(hotel.name)),
      body: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: position, zoom: 15),
        markers: {
          Marker(
            markerId: MarkerId(hotel.id),
            position: position,
            infoWindow: InfoWindow(
              title: hotel.name,
              snippet: hotel.address,
            ),
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}

class FullGalleryPage extends StatefulWidget {
  const FullGalleryPage({
    required this.images,
    required this.initialIndex,
    super.key,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<FullGalleryPage> createState() =>
      _FullGalleryPageState();
}

class _FullGalleryPageState extends State<FullGalleryPage> {
  late final PageController controller;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${index + 1}/${widget.images.length}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PhotoViewGallery.builder(
        pageController: controller,
        itemCount: widget.images.length,
        backgroundDecoration:
            const BoxDecoration(color: Colors.black),
        onPageChanged: (value) => setState(() => index = value),
        builder: (_, imageIndex) {
          return PhotoViewGalleryPageOptions(
            imageProvider:
                CachedNetworkImageProvider(widget.images[imageIndex]),
          );
        },
      ),
    );
  }
}