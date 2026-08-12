import 'user_profile.dart';

/// `GET /connections`.
///   viewers — people who can see MY data (I am the owner).
///   access  — people whose data I can see (I am the viewer).
/// Maps to the "My viewers" / "My access" tabs on the Connections screen.
class ConnectionsResponse {
  const ConnectionsResponse({required this.viewers, required this.access});

  final List<PersonCard> viewers;
  final List<PersonCard> access;

  factory ConnectionsResponse.fromJson(Map<String, dynamic> json) => ConnectionsResponse(
    viewers: (json['viewers'] as List).map((e) => PersonCard.fromJson(e as Map<String, dynamic>)).toList(),
    access: (json['access'] as List).map((e) => PersonCard.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
