import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'common_widgets.dart';
import 'profile_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OwnerApp extends StatefulWidget {
  const OwnerApp({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  State<OwnerApp> createState() => _OwnerAppState();
}

class _OwnerAppState extends State<OwnerApp> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      OwnerOverviewPage(owner: widget.user),
      OwnerHotelsPage(owner: widget.user),
      OwnerBookingsPage(owner: widget.user),
      const QrScannerPage(),
      ProfilePage(user: widget.user),
    ];

    final titles = [
      'Owner dashboard',
      'My hotels',
      'Bookings',
      'Scan guest QR',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[index])),
      body: NetworkStatusBanner(
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel_rounded),
            label: 'Hotels',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_online_outlined),
            selectedIcon: Icon(Icons.book_online_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scan',
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

class OwnerOverviewPage extends StatelessWidget {
  const OwnerOverviewPage({
    required this.owner,
    super.key,
  });

  final AppUser owner;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Hotel>>(
      stream: DatabaseService.instance.ownerHotels(owner.id),
      builder: (context, hotelSnapshot) {
        return StreamBuilder<List<Booking>>(
          stream: DatabaseService.instance.ownerBookings(owner.id),
          builder: (context, bookingSnapshot) {
            if (!hotelSnapshot.hasData ||
                !bookingSnapshot.hasData) {
              return const LoadingView();
            }

            final hotels = hotelSnapshot.data!;
            final bookings = bookingSnapshot.data!;
            final pending = bookings
                .where((item) => item.status == 'pending')
                .length;
            final confirmed = bookings
                .where((item) => item.status == 'confirmed')
                .length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Welcome,\n',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: owner.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _StatisticCard(
                      icon: Icons.hotel_rounded,
                      label: 'Hotels',
                      value: '${hotels.length}',
                    ),
                    _StatisticCard(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      value: '$pending',
                    ),
                    _StatisticCard(
                      icon: Icons.check_circle_outline,
                      label: 'Confirmed',
                      value: '$confirmed',
                    ),
                    _StatisticCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'All bookings',
                      value: '${bookings.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Recent bookings'),
                const SizedBox(height: 10),
                if (bookings.isEmpty)
                  const EmptyView(
                    title: 'No bookings',
                    message:
                        'Guest reservations will appear here.',
                  )
                else
                  ...bookings.take(4).map(
                        (booking) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: BookingCard(booking: booking),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class OwnerHotelsPage extends StatelessWidget {
  const OwnerHotelsPage({
    required this.owner,
    super.key,
  });

  final AppUser owner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Hotel>>(
        stream: DatabaseService.instance.ownerHotels(owner.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!);
          }

          if (!snapshot.hasData) return const LoadingView();

          final hotels = snapshot.data!;

          if (hotels.isEmpty) {
            return const EmptyView(
              title: 'No hotels',
              message:
                  'Use the add button to create your first hotel.',
              icon: Icons.add_business_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: hotels.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final hotel = hotels[index];

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.blush,
                        child: const Icon(
                          Icons.hotel,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        hotel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${hotel.city} • '
                        '${hotel.active ? "Active" : "Inactive"}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => HotelFormPage(
                                    owner: owner,
                                    hotel: hotel,
                                  ),
                                ),
                              );
                            case 'rooms':
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RoomManagerPage(hotel: hotel),
                                ),
                              );
                            case 'state':
                              await DatabaseService.instance
                                  .updateHotelState(
                                hotelId: hotel.id,
                                active: !hotel.active,
                              );
                            case 'delete':
                              final confirmed =
                                  await confirmAction(
                                context,
                                title: 'Delete hotel',
                                message:
                                    'This removes the hotel listing. Existing bookings remain for audit history.',
                                confirmText: 'Delete',
                              );

                              if (confirmed) {
                                await DatabaseService.instance
                                    .deleteHotel(hotel.id);
                              }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit hotel'),
                          ),
                          const PopupMenuItem(
                            value: 'rooms',
                            child: Text('Manage rooms'),
                          ),
                          PopupMenuItem(
                            value: 'state',
                            child: Text(
                              hotel.active
                                  ? 'Deactivate'
                                  : 'Activate',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style:
                                  TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RoomManagerPage(hotel: hotel),
                                ),
                              ),
                              child: const Text('Rooms'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => HotelFormPage(
                                    owner: owner,
                                    hotel: hotel,
                                  ),
                                ),
                              ),
                              child: const Text('Edit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => HotelFormPage(owner: owner),
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add hotel'),
      ),
    );
  }
}

class HotelFormPage extends StatefulWidget {
  const HotelFormPage({
    required this.owner,
    super.key,
    this.hotel,
  });

  final AppUser owner;
  final Hotel? hotel;

  @override
  State<HotelFormPage> createState() => _HotelFormPageState();
}

class _HotelFormPageState extends State<HotelFormPage> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  late final String hotelId;
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController addressController;

  String city = 'Sulaymaniyah';
  List<String> amenities = [];
  List<String> existingImages = [];
  List<XFile> newImages = [];

  double? latitude;
  double? longitude;
  bool loading = false;

  static const availableAmenities = [
    'Free Wi-Fi',
    'Parking',
    'Breakfast',
    'Restaurant',
    'Pool',
    'Gym',
    'Airport transfer',
    'Family rooms',
    'Accessibility',
    '24-hour reception',
  ];

  @override
  void initState() {
    super.initState();

    final hotel = widget.hotel;
    hotelId =
        hotel?.id ?? DatabaseService.instance.newHotelId();

    nameController =
        TextEditingController(text: hotel?.name ?? '');
    descriptionController =
        TextEditingController(text: hotel?.description ?? '');
    addressController =
        TextEditingController(text: hotel?.address ?? '');

    city = hotel?.city ?? 'Sulaymaniyah';
    amenities = [...?hotel?.amenities];
    existingImages = [...?hotel?.images];
    latitude = hotel?.latitude;
    longitude = hotel?.longitude;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final values = await picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );

    if (values.isNotEmpty) {
      setState(() => newImages.addAll(values));
    }
  }

  Future<void> pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute<LatLng>(
        builder: (_) => LocationPickerPage(
          initial: latitude != null && longitude != null
              ? LatLng(latitude!, longitude!)
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        latitude = result.latitude;
        longitude = result.longitude;
      });
    }
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (latitude == null || longitude == null) {
      showMessage(
        context,
        'Select the hotel location on the map.',
        error: true,
      );
      return;
    }

    if (existingImages.isEmpty && newImages.isEmpty) {
      showMessage(
        context,
        'Add at least one hotel photograph.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final uploaded =
          await StorageService.instance.uploadHotelImages(
        ownerId: widget.owner.id,
        hotelId: hotelId,
        files: newImages,
      );

      final hotel = Hotel(
        id: hotelId,
        ownerId: widget.owner.id,
        name: nameController.text,
        description: descriptionController.text,
        city: city,
        address: addressController.text,
        latitude: latitude!,
        longitude: longitude!,
        images: [...existingImages, ...uploaded],
        amenities: amenities,
        minimumPrice: widget.hotel?.minimumPrice ?? 0,
        ratingAverage: widget.hotel?.ratingAverage ?? 0,
        reviewCount: widget.hotel?.reviewCount ?? 0,
        active: widget.hotel?.active ?? true,
        featured: widget.hotel?.featured ?? false,
        deleted: widget.hotel?.deleted ?? false,
      );

      await DatabaseService.instance.saveHotel(
        hotel,
        isNew: widget.hotel == null,
      );

      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.hotel == null ? 'Add hotel' : 'Edit hotel'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Hotel name',
                prefixIcon: Icon(Icons.hotel_outlined),
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3
                      ? 'Enter the hotel name.'
                      : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: city,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: const [
                'Sulaymaniyah',
                'Erbil',
                'Duhok',
                'Halabja',
                'Rawanduz',
              ]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => city = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 5
                      ? 'Enter the hotel address.'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 20
                      ? 'Use at least 20 characters.'
                      : null,
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Amenities'),
            Wrap(
              spacing: 7,
              children: availableAmenities.map((amenity) {
                return FilterChip(
                  label: Text(amenity),
                  selected: amenities.contains(amenity),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        amenities.add(amenity);
                      } else {
                        amenities.remove(amenity);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: pickLocation,
              icon: Icon(
                latitude == null
                    ? Icons.add_location_alt_outlined
                    : Icons.location_on_rounded,
              ),
              label: Text(
                latitude == null
                    ? 'Select location on map'
                    : 'Location selected',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(title: 'Hotel photos'),
                ),
                IconButton.filled(
                  onPressed: pickImages,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              ],
            ),
            Text(
              '${existingImages.length + newImages.length} photo(s)',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (existingImages.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: existingImages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          existingImages[index],
                          width: 110,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 3,
                        top: 3,
                        child: IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(
                            () => existingImages.removeAt(index),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : Text(
                      widget.hotel == null
                          ? 'Create hotel'
                          : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initial,
  });

  final LatLng? initial;

  @override
  State<LocationPickerPage> createState() =>
      _LocationPickerPageState();
}

class _LocationPickerPageState
    extends State<LocationPickerPage> {
  late LatLng selected;

  @override
  void initState() {
    super.initState();
    selected =
        widget.initial ?? const LatLng(35.5613, 45.4309);
    useCurrentLocation();
  }

  Future<void> useCurrentLocation() async {
    try {
      final position =
          await LocationService.instance.determinePosition();

      if (mounted && widget.initial == null) {
        setState(
          () => selected =
              LatLng(position.latitude, position.longitude),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select location'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Done'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: selected, zoom: 14),
        markers: {
          Marker(
            markerId: const MarkerId('selected'),
            position: selected,
            draggable: true,
            onDragEnd: (value) =>
                setState(() => selected = value),
          ),
        },
        onLongPress: (value) =>
            setState(() => selected = value),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}

class RoomManagerPage extends StatelessWidget {
  const RoomManagerPage({
    required this.hotel,
    super.key,
  });

  final Hotel hotel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${hotel.name} rooms')),
      body: StreamBuilder<List<Room>>(
        stream: DatabaseService.instance.rooms(hotel.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();

          final rooms = snapshot.data!;

          if (rooms.isEmpty) {
            return const EmptyView(
              title: 'No rooms',
              message: 'Add the first room type.',
              icon: Icons.bed_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: rooms.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final room = rooms[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.blush,
                    child: Icon(
                      Icons.bed_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${room.pricePerNight.toStringAsFixed(0)} IQD • '
                    '${room.totalRooms} unit(s)',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => RoomFormDialog(
                      hotel: hotel,
                      room: room,
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Delete room',
                        message:
                            'Existing booking records will remain.',
                        confirmText: 'Delete',
                      );

                      if (confirmed) {
                        await DatabaseService.instance.deleteRoom(
                          hotelId: hotel.id,
                          roomId: room.id,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => RoomFormDialog(hotel: hotel),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
    );
  }
}

class RoomFormDialog extends StatefulWidget {
  const RoomFormDialog({
    required this.hotel,
    super.key,
    this.room,
  });

  final Hotel hotel;
  final Room? room;

  @override
  State<RoomFormDialog> createState() =>
      _RoomFormDialogState();
}

class _RoomFormDialogState extends State<RoomFormDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController typeController;
  late final TextEditingController descriptionController;
  late final TextEditingController priceController;
  late final TextEditingController capacityController;
  late final TextEditingController countController;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    final room = widget.room;

    nameController =
        TextEditingController(text: room?.name ?? '');
    typeController =
        TextEditingController(text: room?.type ?? '');
    descriptionController =
        TextEditingController(text: room?.description ?? '');
    priceController = TextEditingController(
      text: room?.pricePerNight.toStringAsFixed(0) ?? '',
    );
    capacityController =
        TextEditingController(text: '${room?.capacity ?? 2}');
    countController =
        TextEditingController(text: '${room?.totalRooms ?? 1}');
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);

    final room = Room(
      id: widget.room?.id ??
          DatabaseService.instance.newRoomId(widget.hotel.id),
      hotelId: widget.hotel.id,
      name: nameController.text,
      type: typeController.text,
      description: descriptionController.text,
      pricePerNight: double.parse(priceController.text),
      capacity: int.parse(capacityController.text),
      totalRooms: int.parse(countController.text),
      images: widget.room?.images ?? widget.hotel.images.take(1).toList(),
      amenities:
          widget.room?.amenities ?? const ['Private bathroom'],
      active: widget.room?.active ?? true,
    );

    try {
      await DatabaseService.instance.saveRoom(
        room,
        isNew: widget.room == null,
      );

      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showMessage(context, error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.room == null ? 'Add room' : 'Edit room'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Room name'),
                  validator: requiredValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    hintText: 'Standard, Deluxe, Suite...',
                  ),
                  validator: requiredValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  validator: requiredValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price per night in IQD',
                  ),
                  validator: numberValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Guest capacity',
                  ),
                  validator: numberValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of available rooms',
                  ),
                  validator: numberValidator,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: loading ? null : submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? requiredValidator(String? value) {
    return (value?.trim().isEmpty ?? true)
        ? 'This field is required.'
        : null;
  }

  String? numberValidator(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0
        ? 'Enter a positive number.'
        : null;
  }
}

class OwnerBookingsPage extends StatelessWidget {
  const OwnerBookingsPage({
    required this.owner,
    super.key,
  });

  final AppUser owner;

  Future<void> updateStatus(
    BuildContext context,
    Booking booking,
    String status,
  ) async {
    try {
      await BackendService.instance.updateBookingStatus(
        bookingId: booking.id,
        status: status,
      );

      if (context.mounted) {
        showMessage(context, 'Booking changed to $status.');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, error.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Booking>>(
        stream:
            DatabaseService.instance.ownerBookings(owner.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!);
          }

          if (!snapshot.hasData) return const LoadingView();

          final bookings = snapshot.data!;

          if (bookings.isEmpty) {
            return const EmptyView(
              title: 'No bookings',
              message:
                  'Online and manually created bookings appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: bookings.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = bookings[index];

              return BookingCard(
                booking: booking,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (status) =>
                        updateStatus(context, booking, status),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'confirmed',
                        child: Text('Confirm'),
                      ),
                      PopupMenuItem(
                        value: 'checkedIn',
                        child: Text('Check in'),
                      ),
                      PopupMenuItem(
                        value: 'completed',
                        child: Text('Complete'),
                      ),
                      PopupMenuItem(
                        value: 'cancelled',
                        child: Text(
                          'Cancel',
                          style:
                              TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.edit_outlined),
                      label: Text('Change status'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ManualBookingPage(owner: owner),
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Manual booking'),
      ),
    );
  }
}

class ManualBookingPage extends StatefulWidget {
  const ManualBookingPage({
    required this.owner,
    super.key,
  });

  final AppUser owner;

  @override
  State<ManualBookingPage> createState() =>
      _ManualBookingPageState();
}

class _ManualBookingPageState
    extends State<ManualBookingPage> {
  String? selectedHotelId;
  String? selectedRoomId;

  DateTimeRange? dates;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final requestsController = TextEditingController();

  int guests = 1;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    requestsController.dispose();
    super.dispose();
  }

  Future<void> selectDates() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: dates,
    );

    if (result != null && mounted) {
      setState(() => dates = result);
    }
  }

  Future<void> submit() async {
    if (selectedHotelId == null) {
      showMessage(
        context,
        'Select a hotel.',
        error: true,
      );
      return;
    }

    if (selectedRoomId == null) {
      showMessage(
        context,
        'Select a room type.',
        error: true,
      );
      return;
    }

    if (dates == null ||
        !dates!.end.isAfter(dates!.start)) {
      showMessage(
        context,
        'Select valid check-in and check-out dates.',
        error: true,
      );
      return;
    }

    if (nameController.text.trim().isEmpty) {
      showMessage(
        context,
        'Enter the guest name.',
        error: true,
      );
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      showMessage(
        context,
        'Enter the guest phone number.',
        error: true,
      );
      return;
    }

    if (guests < 1) {
      showMessage(
        context,
        'Enter at least one guest.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      await BackendService.instance.createManualBooking(
        hotelId: selectedHotelId!,
        roomId: selectedRoomId!,
        guestName: nameController.text,
        guestEmail: emailController.text,
        guestPhone: phoneController.text,
        checkIn: dates!.start,
        checkOut: dates!.end,
        guests: guests,
        specialRequests: requestsController.text,
      );

      if (!mounted) return;

      showMessage(
        context,
        'Manual booking created successfully.',
      );

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      showMessage(
        context,
        error.message ??
            'Manual booking failed: ${error.code}',
        error: true,
      );
    } catch (error) {
      if (!mounted) return;

      showMessage(
        context,
        error.toString(),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual booking'),
      ),
      body: StreamBuilder<List<Hotel>>(
        stream: DatabaseService.instance.ownerHotels(
          widget.owner.id,
        ),
        builder: (context, hotelSnapshot) {
          if (hotelSnapshot.hasError) {
            return ErrorView(
              error: hotelSnapshot.error!,
            );
          }

          if (!hotelSnapshot.hasData) {
            return const LoadingView();
          }

          final hotels = hotelSnapshot.data!;

          /*
           * Use a safe ID. If the selected hotel was deleted,
           * the dropdown returns to null rather than crashing.
           */
          final validHotelId = hotels.any(
            (hotel) => hotel.id == selectedHotelId,
          )
              ? selectedHotelId
              : null;

          if (hotels.isEmpty) {
            return const EmptyView(
              title: 'No hotels available',
              message:
                  'Create a hotel before adding a manual booking.',
              icon: Icons.hotel_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'hotel-dropdown-$validHotelId',
                ),
                initialValue: validHotelId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hotel',
                  prefixIcon: Icon(
                    Icons.hotel_outlined,
                  ),
                ),
                hint: const Text('Select a hotel'),
                items: hotels.map((hotel) {
                  return DropdownMenuItem<String>(
                    value: hotel.id,
                    child: Text(
                      hotel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: loading
                    ? null
                    : (hotelId) {
                        setState(() {
                          selectedHotelId = hotelId;

                          // Clear the old room selection whenever
                          // the hotel changes.
                          selectedRoomId = null;
                        });
                      },
                validator: (value) =>
                    value == null
                        ? 'Select a hotel.'
                        : null,
              ),
              const SizedBox(height: 12),

              if (validHotelId == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select a hotel to load its room types.',
                      style: TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                )
              else
                StreamBuilder<List<Room>>(
                  stream: DatabaseService.instance.rooms(
                    validHotelId,
                  ),
                  builder: (context, roomSnapshot) {
                    if (roomSnapshot.hasError) {
                      return ErrorView(
                        error: roomSnapshot.error!,
                      );
                    }

                    if (!roomSnapshot.hasData) {
                      return const SizedBox(
                        height: 80,
                        child: LoadingView(),
                      );
                    }

                    final rooms = roomSnapshot.data!
                        .where((room) => room.active)
                        .toList();

                    final validRoomId = rooms.any(
                      (room) =>
                          room.id == selectedRoomId,
                    )
                        ? selectedRoomId
                        : null;

                    if (rooms.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'The selected hotel has no active rooms. '
                            'Add a room before creating a booking.',
                            style: TextStyle(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      key: ValueKey(
                        'room-dropdown-'
                        '$validHotelId-$validRoomId',
                      ),
                      initialValue: validRoomId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Room type',
                        prefixIcon: Icon(
                          Icons.bed_outlined,
                        ),
                      ),
                      hint: const Text(
                        'Select a room type',
                      ),
                      items: rooms.map((room) {
                        return DropdownMenuItem<String>(
                          value: room.id,
                          child: Text(
                            '${room.name} – '
                            '${room.pricePerNight.toStringAsFixed(0)} IQD',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: loading
                          ? null
                          : (roomId) {
                              setState(() {
                                selectedRoomId = roomId;
                              });
                            },
                    );
                  },
                ),

              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                enabled: !loading,
                textCapitalization:
                    TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Guest name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                enabled: !loading,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Guest email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                enabled: !loading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Guest phone',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                initialValue: guests,
                decoration: const InputDecoration(
                  labelText: 'Number of guests',
                  prefixIcon: Icon(
                    Icons.group_outlined,
                  ),
                ),
                items: List.generate(
                  10,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(
                      '${index + 1} guest(s)',
                    ),
                  ),
                ),
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => guests = value);
                        }
                      },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: loading ? null : selectDates,
                icon: const Icon(
                  Icons.date_range_outlined,
                ),
                label: Text(
                  dates == null
                      ? 'Select stay dates'
                      : '${dates!.start.day}/'
                          '${dates!.start.month}/'
                          '${dates!.start.year} – '
                          '${dates!.end.day}/'
                          '${dates!.end.month}/'
                          '${dates!.end.year}',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: requestsController,
                enabled: !loading,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional requests',
                  hintText:
                      'Extra bed, late arrival, accessibility needs...',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),

              FilledButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create manual booking',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool processing = false;

  Future<void> detect(BarcodeCapture capture) async {
    if (processing) return;

    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;

    setState(() => processing = true);
    await controller.stop();

    try {
      final result =
          await BackendService.instance.verifyQr(value);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 56,
          ),
          title: const Text('Guest checked in'),
          content: Text(
            '${result['guestName']}\n'
            '${result['hotelName']}\n'
            '${result['roomName']}',
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
    } on FirebaseFunctionsException catch (error) {
  if (!mounted) return;

  String message;

  switch (error.code) {
    case 'failed-precondition':
      message =
          'This booking is not confirmed. It may be pending, cancelled, completed, or already checked in.';
      break;

    case 'already-exists':
      message =
          'This QR code has already been used for check-in.';
      break;

    case 'permission-denied':
      message =
          'This booking belongs to another hotel or the QR code is invalid.';
      break;

    case 'not-found':
      message =
          'The booking no longer exists.';
      break;

    default:
      message =
          error.message ?? 'The booking QR could not be verified.';
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.cancel_outlined,
        color: AppColors.danger,
        size: 56,
      ),
      title: const Text('Invalid booking QR'),
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
} catch (error, stackTrace) {
  debugPrint('QR verification error: $error');
  debugPrintStack(stackTrace: stackTrace);

  if (!mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.error_outline_rounded,
        color: AppColors.danger,
        size: 56,
      ),
      title: const Text('Unable to verify QR'),
      content: const Text(
        'An unexpected error occurred. Please try again.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
} finally {
      if (mounted) {
        setState(() => processing = false);
        await controller.start();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: detect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary,
                width: 4,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              processing
                  ? 'Checking booking...'
                  : 'Place the guest booking QR inside the frame.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}