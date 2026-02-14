class TbaEvent {
  final String key;
  final String name;
  final String? city;
  final String? stateProv;
  final String? startDate;
  final String? endDate;

  TbaEvent({
    required this.key,
    required this.name,
    this.city,
    this.stateProv,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'city': city,
        'stateProv': stateProv,
        'startDate': startDate,
        'endDate': endDate,
      };

  factory TbaEvent.fromJson(Map<String, dynamic> json) => TbaEvent(
        key: json['key'] ?? json['event_key'] ?? '',
        name: json['name'] ?? json['event_name'] ?? '',
        city: json['city'],
        stateProv: json['stateProv'] ?? json['state_prov'],
        startDate: json['startDate'] ?? json['start_date'],
        endDate: json['endDate'] ?? json['end_date'],
      );

  @override
  String toString() => '$name ($key)';
}
