import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRefresh extends ChangeNotifier {
  AuthRefresh(SupabaseClient client) {
    _subscription = client.auth.onAuthStateChange.listen((AuthState _) {
      notifyListeners();
    });
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
