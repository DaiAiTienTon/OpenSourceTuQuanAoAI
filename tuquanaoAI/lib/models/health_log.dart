class HealthLog {
  final String id;
  final String userId;
  final String logDate;
  final String heartRate;
  final String bloodPressure;
  final String weight;
  final String sleep;
  final String? notes;

  const HealthLog({
    required this.id,
    required this.userId,
    required this.logDate,
    this.heartRate = '',
    this.bloodPressure = '',
    this.weight = '',
    this.sleep = '',
    this.notes,
  });

  factory HealthLog.fromJson(Map<String, dynamic> j) => HealthLog(
    id: j['id']?.toString() ?? '',
    userId: j['userId']?.toString() ?? '',
    logDate: j['logDate']?.toString() ?? '',
    heartRate: j['heartRate']?.toString() ?? '',
    bloodPressure: j['bloodPressure']?.toString() ?? '',
    weight: j['weight']?.toString() ?? '',
    sleep: j['sleepHours']?.toString() ?? '',
    notes: j['notes'],
  );

  Map<String, dynamic> toJson(String userId) => {
    'userId': userId,
    'logDate': logDate,
    'heartRate': heartRate.isEmpty ? null : heartRate,
    'bloodPressure': bloodPressure.isEmpty ? null : bloodPressure,
    'weight': weight.isEmpty ? null : double.tryParse(weight),
    'sleepHours': sleep.isEmpty ? null : double.tryParse(sleep),
    'notes': notes,
  };
}