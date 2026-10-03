import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/authentication.dart';
import '../auth/jwt_verifier.dart';
import '../data/compass_repository.dart';
import '../http/json_response.dart';

class AuthenticatedMember {
  const AuthenticatedMember({required this.principal, required this.member});

  final AuthPrincipal principal;
  final MemberRecord member;
}

Future<AuthenticatedMember> authenticatedMember({
  required Request request,
  required JwtVerifier jwtVerifier,
  required CompassRepository repository,
  required Clock clock,
}) async {
  final AuthPrincipal principal =
      await requirePrincipal(request, jwtVerifier, clock: clock);
  final MemberRecord member = await repository.ensureMember(principal);
  return AuthenticatedMember(principal: principal, member: member);
}

void requireAccess(MemberRecord member, Clock clock) {
  final EntitlementResult entitlement =
      const EntitlementPolicy().evaluate(member, now: clock.now());
  if (!entitlement.hasAccess) {
    throw const ApiException(403, 'subscription_required', 'An active subscription is required.');
  }
}
