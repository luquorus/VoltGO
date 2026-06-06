/// Collaborator Registration Request Model
/// 
/// Represents a collaborator registration request submitted by a user
class RegistrationRequest {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? dateOfBirth;
  final String? address;
  final String? idCardNumber;
  final String? bankAccountNumber;
  final String? bankName;
  final String? referralCode;
  final DateTime? contractAgreedAt;
  final RegistrationRequestStatus status;
  final String? rejectionReason;
  final int submissionCount;
  final bool canResubmit;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RegistrationRequest({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.dateOfBirth,
    this.address,
    this.idCardNumber,
    this.bankAccountNumber,
    this.bankName,
    this.referralCode,
    this.contractAgreedAt,
    required this.status,
    this.rejectionReason,
    required this.submissionCount,
    required this.canResubmit,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) {
    return RegistrationRequest(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      address: json['address'] as String?,
      idCardNumber: json['idCardNumber'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankName: json['bankName'] as String?,
      referralCode: json['referralCode'] as String?,
      contractAgreedAt: json['contractAgreedAt'] != null
          ? DateTime.parse(json['contractAgreedAt'] as String)
          : null,
      status: RegistrationRequestStatus.fromString(json['status'] as String),
      rejectionReason: json['rejectionReason'] as String?,
      submissionCount: json['submissionCount'] as int? ?? 1,
      canResubmit: json['canResubmit'] as bool? ?? true,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (address != null) 'address': address,
      if (idCardNumber != null) 'idCardNumber': idCardNumber,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (bankName != null) 'bankName': bankName,
      if (referralCode != null) 'referralCode': referralCode,
      if (contractAgreedAt != null) 'contractAgreedAt': contractAgreedAt!.toUtc().toIso8601String(),
      'status': status.value,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'submissionCount': submissionCount,
      'canResubmit': canResubmit,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final dobDate = DateTime.parse(dob);
    final now = DateTime.now();
    int age = now.year - dobDate.year;
    if (now.month < dobDate.month || (now.month == dobDate.month && now.day < dobDate.day)) {
      age--;
    }
    return age;
  }
}

/// Status enum for registration requests
enum RegistrationRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  final String value;
  const RegistrationRequestStatus(this.value);

  static RegistrationRequestStatus fromString(String value) {
    return RegistrationRequestStatus.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => RegistrationRequestStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case RegistrationRequestStatus.pending:
        return 'Pending';
      case RegistrationRequestStatus.approved:
        return 'Approved';
      case RegistrationRequestStatus.rejected:
        return 'Rejected';
    }
  }
}
