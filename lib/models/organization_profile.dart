class OrganizationProfile {
  final String fullName;
  final String shortName;
  final String inn;
  final String kpp;
  final String legalAddress;
  final String directorPosition;
  final String directorName;
  final String accountantPosition;
  final String accountantName;
  final String materialResponsiblePosition;
  final String materialResponsibleName;
  final String formsApprovalOrderNo;
  final String formsApprovalOrderDate;
  final String procurementRegime;

  const OrganizationProfile({
    required this.fullName,
    required this.shortName,
    required this.inn,
    required this.kpp,
    required this.legalAddress,
    required this.directorPosition,
    required this.directorName,
    required this.accountantPosition,
    required this.accountantName,
    required this.materialResponsiblePosition,
    required this.materialResponsibleName,
    required this.formsApprovalOrderNo,
    required this.formsApprovalOrderDate,
    required this.procurementRegime,
  });

  factory OrganizationProfile.fromMap(Map<String, Object?> map) {
    return OrganizationProfile(
      fullName: map['full_name'] as String? ?? '',
      shortName: map['short_name'] as String? ?? '',
      inn: map['inn'] as String? ?? '',
      kpp: map['kpp'] as String? ?? '',
      legalAddress: map['legal_address'] as String? ?? '',
      directorPosition:
          map['director_position'] as String? ?? 'Руководитель',
      directorName: map['director_name'] as String? ?? '',
      accountantPosition:
          map['accountant_position'] as String? ?? 'Главный бухгалтер',
      accountantName: map['accountant_name'] as String? ?? '',
      materialResponsiblePosition:
          map['material_responsible_position'] as String? ??
              'Материально ответственное лицо',
      materialResponsibleName:
          map['material_responsible_name'] as String? ?? '',
      formsApprovalOrderNo:
          map['forms_approval_order_no'] as String? ?? '',
      formsApprovalOrderDate:
          map['forms_approval_order_date'] as String? ?? '',
      procurementRegime:
          map['procurement_regime'] as String? ?? 'commercial',
    );
  }

  bool get hasMinimumLegalDetails =>
      fullName.trim().isNotEmpty &&
      directorName.trim().isNotEmpty &&
      formsApprovalOrderNo.trim().isNotEmpty &&
      formsApprovalOrderDate.trim().isNotEmpty;
}
