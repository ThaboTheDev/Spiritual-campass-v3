import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_models.dart';
import '../providers/app_providers.dart';

class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementProvider);
    return entitlement.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _RetryPanel(
        title: 'Membership could not be checked',
        detail: 'Reconnect to check your directory access.',
        onRetry: () => ref.invalidate(entitlementProvider),
      ),
      data: (member) {
        if (!member.hasAccess) return const _DirectoryLocked();
        final AsyncValue<CentreCatalog> catalog = ref.watch(centresProvider);
        return catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _RetryPanel(
            title: 'Directory unavailable',
            detail: 'The centre list could not be loaded. Please try again.',
            onRetry: () => ref.invalidate(centresProvider),
          ),
          data: _directory,
        );
      },
    );
  }

  Widget _directory(CentreCatalog catalog) {
    final String query = _query.trim().toLowerCase();
    final List<({String name, List<Centre> centres})> regions =
        catalog.regions
            .map((region) => (
                  name: region.name,
                  centres: region.centres
                      .where((Centre centre) =>
                          query.isEmpty ||
                          centre.name.toLowerCase().contains(query) ||
                          centre.region.toLowerCase().contains(query) ||
                          (centre.address?.toLowerCase().contains(query) ?? false))
                      .toList(growable: false),
                ))
            .where((region) => region.centres.isNotEmpty)
            .toList(growable: false);

    if (catalog.count == 0) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const <Widget>[
          _DirectoryHeader(),
          SizedBox(height: 16),
          _EmptyDirectoryState(),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: <Widget>[
        const _DirectoryHeader(),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (String value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search centres or regions',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        for (final ({String name, List<Centre> centres}) region in regions) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 9, top: 8),
            child: Text(region.name, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final Centre centre in region.centres) ...<Widget>[
            _CentreCard(centre: centre),
            const SizedBox(height: 10),
          ],
        ],
        if (regions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: Text('No centres match that search.')),
          ),
      ],
    );
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Centres', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Browse verified TSHK centre listings by region.'),
        ],
      );
}

class _EmptyDirectoryState extends StatelessWidget {
  const _EmptyDirectoryState();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          child: Column(
            children: <Widget>[
              Icon(Icons.place_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Centre listings are not available yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'No verified centre records have been supplied. We will show the directory here when the information is ready.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({required this.centre});

  final Centre centre;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.location_city_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(centre.name, style: Theme.of(context).textTheme.titleMedium),
                    if (centre.address != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(centre.address!),
                    ],
                    if (centre.phone != null) ...<Widget>[
                      const SizedBox(height: 4),
                      SelectableText(centre.phone!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _DirectoryLocked extends StatelessWidget {
  const _DirectoryLocked();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline, size: 40),
                  const SizedBox(height: 12),
                  Text('Member access required',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'The centre directory is available to members with current access.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/app?tab=membership'),
                    child: const Text('View membership'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.title, required this.detail, required this.onRetry});

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
