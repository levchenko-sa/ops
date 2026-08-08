class WorkReport {
  final int? id;
  final int requestId;
  final double? batteryVoltage;
  final double? loopResistanceKohm;
  final String cause;
  final String workDone;
  final String result;
  final String createdAt;

  const WorkReport({
    this.id,
    required this.requestId,
    this.batteryVoltage,
    this.loopResistanceKohm,
    required this.cause,
    required this.workDone,
    required this.result,
    required this.createdAt,
  });
}
