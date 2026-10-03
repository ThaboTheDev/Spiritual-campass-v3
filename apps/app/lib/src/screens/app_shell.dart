import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_providers.dart';
import 'centres_screen.dart';
import 'compass_screen.dart';
import 'membership_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<String> _titles = <String>[
    'Compass',
    'Centres',
    'Membership',
    'Profile',
    'Settings',
  ];
  int _index = 0;
  String? _handledCheckoutResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Map<String, String> query = GoRouterState.of(context).uri.queryParameters;
    final String? requestedTab = query['tab'];
    final int? tabIndex = switch (requestedTab) {
      'compass' => 0,
      'centres' => 1,
      'membership' => 2,
      'profile' => 3,
      'settings' => 4,
      _ => null,
    };
    if (tabIndex != null && tabIndex != _index) _index = tabIndex;
    final String? result = query['checkout'];
    if (result != null && result != _handledCheckoutResult) {
      _handledCheckoutResult = result;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final String message = result == 'return'
            ? 'Payment was submitted. Your access updates after PayFast confirms it.'
            : 'Checkout was cancelled. No payment confirmation has been received.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        ref.invalidate(entitlementProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final Session? session = ref.watch(supabaseClientProvider).auth.currentSession;
    final List<Widget> pages = <Widget>[
      const CompassScreen(),
      const CentresScreen(),
      const MembershipScreen(),
      ProfileScreen(email: session?.user.email),
      const SettingsScreen(),
    ];
    final List<NavigationDestination> destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Compass'),
      const NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place), label: 'Centres'),
      const NavigationDestination(icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Member'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh membership',
            onPressed: () => ref.invalidate(entitlementProvider),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
