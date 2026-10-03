import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person,
                        size: 32, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('Your account', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  SelectableText(email ?? 'Email not available'),
                  const SizedBox(height: 16),
                  Text(
                    'Your sign-in address is managed securely by Supabase Auth.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _ProfileRow(
            icon: Icons.shield_outlined,
            title: 'Account security',
            detail: 'Use a unique password and keep your email access secure.',
          ),
          const SizedBox(height: 10),
          const _ProfileRow(
            icon: Icons.location_on_outlined,
            title: 'Location control',
            detail: 'Location permission is requested only while the app is in use. You can also use manual coordinates.',
          ),
        ],
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(detail),
          ),
        ),
      );
}
