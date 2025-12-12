import 'package:supabase_flutter/supabase_flutter.dart';

class AgencyMember {
  const AgencyMember({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
    this.joinedAt,
  });

  final String userId;
  final String email;
  final String? firstName;
  final String? lastName;
  final DateTime? joinedAt;
}

class AccountSummary {
  const AccountSummary({
    required this.email,
    this.firstName,
    this.lastName,
    this.agencyCode,
    this.agencyName,
  });

  final String email;
  final String? firstName;
  final String? lastName;
  final String? agencyCode;
  final String? agencyName;
}

class AgencyService {
  AgencyService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? _agencyId;

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    return user;
  }

  Future<String> ensureMembershipWithCode(
    String agencyCode, {
    String? firstName,
    String? lastName,
  }) async {
    final user = _requireUser();
    // Create or reuse agency by code
    final agencyRow = await _client
        .from('agencies')
        .upsert({'code': agencyCode, 'name': agencyCode}, onConflict: 'code')
        .select('id')
        .single();
    final agencyId = agencyRow['id'] as String;

    await _client.from('agency_members').upsert({
      'user_id': user.id,
      'agency_id': agencyId,
      'member_email': user.email,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    });
    _agencyId = agencyId;
    return agencyId;
  }

  Future<String> getAgencyId() async {
    if (_agencyId != null) return _agencyId!;
    final user = _requireUser();
    final row = await _client
        .from('agency_members')
        .select('agency_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null || row['agency_id'] == null) {
      throw StateError('No agency membership found for user.');
    }
    _agencyId = row['agency_id'] as String;
    return _agencyId!;
  }

  Future<List<AgencyMember>> fetchMembers() async {
    final agencyId = await getAgencyId();
    final rows = await _client
        .from('agency_members')
        .select('user_id, member_email, joined_at, first_name, last_name')
        .eq('agency_id', agencyId)
        .order('member_email');
    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => AgencyMember(
            userId: row['user_id'] as String,
            email: row['member_email'] as String? ?? '',
            firstName: row['first_name'] as String?,
            lastName: row['last_name'] as String?,
            joinedAt: DateTime.tryParse(row['joined_at'] as String? ?? ''),
          ),
        )
        .toList();
  }

  Future<AgencyMember?> fetchCurrentMember() async {
    final user = _requireUser();
    final row = await _client
        .from('agency_members')
        .select('user_id, member_email, joined_at, first_name, last_name')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return AgencyMember(
      userId: row['user_id'] as String,
      email: row['member_email'] as String? ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      joinedAt: DateTime.tryParse(row['joined_at'] as String? ?? ''),
    );
  }

  Future<AccountSummary> fetchAccountSummary() async {
    final user = _requireUser();
    final row = await _client
        .from('agency_members')
        .select(
          'member_email, first_name, last_name, agency_id, agencies!inner(code,name)',
        )
        .eq('user_id', user.id)
        .single();
    final agency = row['agencies'] as Map<String, dynamic>?;
    return AccountSummary(
      email: row['member_email'] as String? ?? user.email ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      agencyCode: agency?['code'] as String?,
      agencyName: agency?['name'] as String?,
    );
  }
}
