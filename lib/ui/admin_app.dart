import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'common_widgets.dart';
import 'profile_page.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminOverviewPage(),
      const AdminUsersPage(),
      const AdminHotelsPage(),
      const AdminBookingsPage(),
      ProfilePage(user: widget.user),
    ];

    final titles = [
      'Administration',
      'Users and roles',
      'All hotels',
      'All bookings',
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
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            label: 'Hotels',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: DatabaseService.instance.allUsers(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<List<Hotel>>(
          stream: DatabaseService.instance.allHotels(),
          builder: (context, hotelsSnapshot) {
            return StreamBuilder<List<Booking>>(
              stream: DatabaseService.instance.allBookings(),
              builder: (context, bookingsSnapshot) {
                if (!usersSnapshot.hasData ||
                    !hotelsSnapshot.hasData ||
                    !bookingsSnapshot.hasData) {
                  return const LoadingView();
                }

                final users = usersSnapshot.data!;
                final hotels = hotelsSnapshot.data!;
                final bookings = bookingsSnapshot.data!;

                return GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _AdminMetric(
                      label: 'Users',
                      value: users.length,
                      icon: Icons.people_alt_outlined,
                    ),
                    _AdminMetric(
                      label: 'Owners',
                      value: users
                          .where(
                            (item) =>
                                item.role == UserRole.owner,
                          )
                          .length,
                      icon: Icons.business_center_outlined,
                    ),
                    _AdminMetric(
                      label: 'Hotels',
                      value: hotels.length,
                      icon: Icons.hotel_outlined,
                    ),
                    _AdminMetric(
                      label: 'Bookings',
                      value: bookings.length,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 29),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 27,
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

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: DatabaseService.instance.allUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!);
        }

        if (!snapshot.hasData) return const LoadingView();

        final users = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.blush,
                  child: Text(
                    user.name.isEmpty
                        ? '?'
                        : user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  user.name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(user.email),
                trailing: DropdownButton<UserRole>(
                  value: user.role,
                  underline: const SizedBox.shrink(),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
                  onChanged: (role) async {
                    if (role == null || role == user.role) return;

                    final confirmed = await confirmAction(
                      context,
                      title: 'Change user role',
                      message:
                          'Change ${user.name} from ${user.role.name} to ${role.name}?',
                    );

                    if (!confirmed) return;

                    try {
                      await BackendService.instance.setUserRole(
                        userId: user.id,
                        role: role,
                      );

                      if (context.mounted) {
                        showMessage(context, 'Role updated.');
                      }
                    } catch (error) {
                      if (context.mounted) {
                        showMessage(
                          context,
                          error.toString(),
                          error: true,
                        );
                      }
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminHotelsPage extends StatelessWidget {
  const AdminHotelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Hotel>>(
      stream: DatabaseService.instance.allHotels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingView();

        final hotels = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: hotels.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final hotel = hotels[index];

            return Card(
              child: SwitchListTile(
                value: hotel.active,
                activeThumbColor: AppColors.primary,
                title: Text(
                  hotel.name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${hotel.city} • Owner: ${hotel.ownerId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (value) => DatabaseService.instance
                    .updateHotelState(
                  hotelId: hotel.id,
                  active: value,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminBookingsPage extends StatelessWidget {
  const AdminBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: DatabaseService.instance.allBookings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingView();

        final bookings = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final booking = bookings[index];

            return BookingCard(
              booking: booking,
              actions: [
                DropdownButton<String>(
                  value: booking.status,
                  items: const [
                    'pending',
                    'confirmed',
                    'checkedIn',
                    'completed',
                    'cancelled',
                  ]
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (status) async {
                    if (status == null ||
                        status == booking.status) {
                      return;
                    }

                    try {
                      await BackendService.instance
                          .updateBookingStatus(
                        bookingId: booking.id,
                        status: status,
                      );
                    } catch (error) {
                      if (context.mounted) {
                        showMessage(
                          context,
                          error.toString(),
                          error: true,
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}