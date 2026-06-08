/// Verification Task Model
class VerificationTask {
  final String id;
  final String stationId;
  final String stationName;
  final String? changeRequestId;
  final int priority;
  final DateTime? slaDueAt;
  final String? assignedTo;
  final String? assignedToEmail;
  final VerificationTaskStatus status;
  final DateTime createdAt;
  final Checkin? checkin;
  final List<Evidence> evidences;
  final Review? review;
  final List<ChecklistItem>? checklist;
  final StationSnapshotDTO? stationSnapshot;

  VerificationTask({
    required this.id,
    required this.stationId,
    required this.stationName,
    this.changeRequestId,
    required this.priority,
    this.slaDueAt,
    this.assignedTo,
    this.assignedToEmail,
    required this.status,
    required this.createdAt,
    this.checkin,
    this.evidences = const [],
    this.review,
    this.checklist,
    this.stationSnapshot,
  });

  factory VerificationTask.fromJson(Map<String, dynamic> json) {
    return VerificationTask(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      changeRequestId: json['changeRequestId'] as String?,
      priority: json['priority'] as int,
      slaDueAt: json['slaDueAt'] != null
          ? DateTime.parse(json['slaDueAt'] as String)
          : null,
      assignedTo: json['assignedTo'] as String?,
      assignedToEmail: json['assignedToEmail'] as String?,
      status: VerificationTaskStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      checkin: json['checkin'] != null
          ? Checkin.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
      evidences: (json['evidences'] as List<dynamic>?)
              ?.map((e) => Evidence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      review: json['review'] != null
          ? Review.fromJson(json['review'] as Map<String, dynamic>)
          : null,
      checklist: (json['checklist'] as List<dynamic>?)
          ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      stationSnapshot: json['stationSnapshot'] != null
          ? StationSnapshotDTO.fromJson(
              json['stationSnapshot'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      if (changeRequestId != null) 'changeRequestId': changeRequestId,
      'priority': priority,
      if (slaDueAt != null) 'slaDueAt': slaDueAt!.toIso8601String(),
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      if (checkin != null) 'checkin': checkin!.toJson(),
      'evidences': evidences.map((e) => e.toJson()).toList(),
      if (review != null) 'review': review!.toJson(),
    };
  }
}

/// Checklist answer value enum
enum ChecklistAnswerValue {
  yes,
  no,
  unableToVerify;

  static ChecklistAnswerValue fromString(String value) {
    switch (value.toUpperCase()) {
      case 'YES':
        return ChecklistAnswerValue.yes;
      case 'NO':
        return ChecklistAnswerValue.no;
      case 'UNABLE_TO_VERIFY':
        return ChecklistAnswerValue.unableToVerify;
      default:
        throw ArgumentError('Unknown answer value: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case ChecklistAnswerValue.yes:
        return 'YES';
      case ChecklistAnswerValue.no:
        return 'NO';
      case ChecklistAnswerValue.unableToVerify:
        return 'UNABLE_TO_VERIFY';
    }
  }
}

/// Checklist item definition
class ChecklistItem {
  final String id;
  final String question;
  final String type;
  final String sourceCode;

  ChecklistItem({
    required this.id,
    required this.question,
    required this.type,
    required this.sourceCode,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      question: json['question'] as String,
      type: json['type'] as String,
      sourceCode: json['sourceCode'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'sourceCode': sourceCode,
    };
  }
}

/// Checklist answer submitted by collaborator
class ChecklistAnswer {
  final String itemId;
  final String question;
  final String type;
  final String sourceCode;
  final ChecklistAnswerValue answer;

  ChecklistAnswer({
    required this.itemId,
    required this.question,
    required this.type,
    required this.sourceCode,
    required this.answer,
  });

  factory ChecklistAnswer.fromJson(Map<String, dynamic> json) {
    return ChecklistAnswer(
      itemId: json['itemId'] as String,
      question: json['question'] as String,
      type: json['type'] as String,
      sourceCode: json['sourceCode'] as String,
      answer: ChecklistAnswerValue.fromString(json['answer'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'question': question,
      'type': type,
      'sourceCode': sourceCode,
      'answer': answer.toString(),
    };
  }
}

/// Station snapshot at task creation time
class StationSnapshotDTO {
  final int? totalBatteries;
  final double? avgChargePowerKw;
  final int? pileCount;
  final int? slotCount;
  final String? operatingHours;
  final double? parkingFee;

  StationSnapshotDTO({
    this.totalBatteries,
    this.avgChargePowerKw,
    this.pileCount,
    this.slotCount,
    this.operatingHours,
    this.parkingFee,
  });

  factory StationSnapshotDTO.fromJson(Map<String, dynamic> json) {
    return StationSnapshotDTO(
      totalBatteries: (json['totalBatteries'] as num?)?.toInt(),
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
      pileCount: (json['pileCount'] as num?)?.toInt(),
      slotCount: (json['slotCount'] as num?)?.toInt(),
      operatingHours: json['operatingHours'] as String?,
      parkingFee: (json['parkingFee'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (totalBatteries != null) 'totalBatteries': totalBatteries,
      if (avgChargePowerKw != null) 'avgChargePowerKw': avgChargePowerKw,
      if (pileCount != null) 'pileCount': pileCount,
      if (slotCount != null) 'slotCount': slotCount,
      if (operatingHours != null) 'operatingHours': operatingHours,
      if (parkingFee != null) 'parkingFee': parkingFee,
    };
  }
}

/// Verification Task Status
enum VerificationTaskStatus {
  open,
  assigned,
  checkedIn,
  submitted,
  reviewed;

  static VerificationTaskStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OPEN':
        return VerificationTaskStatus.open;
      case 'ASSIGNED':
        return VerificationTaskStatus.assigned;
      case 'CHECKED_IN':
        return VerificationTaskStatus.checkedIn;
      case 'SUBMITTED':
        return VerificationTaskStatus.submitted;
      case 'REVIEWED':
        return VerificationTaskStatus.reviewed;
      default:
        throw ArgumentError('Unknown status: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case VerificationTaskStatus.open:
        return 'OPEN';
      case VerificationTaskStatus.assigned:
        return 'ASSIGNED';
      case VerificationTaskStatus.checkedIn:
        return 'CHECKED_IN';
      case VerificationTaskStatus.submitted:
        return 'SUBMITTED';
      case VerificationTaskStatus.reviewed:
        return 'REVIEWED';
    }
  }

  String get displayName {
    switch (this) {
      case VerificationTaskStatus.open:
        return 'Open';
      case VerificationTaskStatus.assigned:
        return 'Assigned';
      case VerificationTaskStatus.checkedIn:
        return 'Checked in';
      case VerificationTaskStatus.submitted:
        return 'Submitted';
      case VerificationTaskStatus.reviewed:
        return 'Reviewed';
    }
  }
}

/// Check-in information
class Checkin {
  final double lat;
  final double lng;
  final DateTime checkedInAt;
  final int? distanceM;
  final String? deviceNote;
  final List<ChecklistAnswer>? checklistAnswers;

  Checkin({
    required this.lat,
    required this.lng,
    required this.checkedInAt,
    this.distanceM,
    this.deviceNote,
    this.checklistAnswers,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      checkedInAt: DateTime.parse(json['checkedInAt'] as String),
      distanceM: json['distanceM'] as int?,
      deviceNote: json['deviceNote'] as String?,
      checklistAnswers: (json['checklistAnswers'] as List<dynamic>?)
          ?.map(
              (e) => ChecklistAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'checkedInAt': checkedInAt.toIso8601String(),
      if (distanceM != null) 'distanceM': distanceM,
      if (deviceNote != null) 'deviceNote': deviceNote,
      if (checklistAnswers != null)
        'checklistAnswers':
            checklistAnswers!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Review information
class Review {
  final String result;
  final String? adminNote;
  final DateTime reviewedAt;
  final String reviewedBy;

  Review({
    required this.result,
    this.adminNote,
    required this.reviewedAt,
    required this.reviewedBy,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      result: json['result'] as String,
      adminNote: json['adminNote'] as String?,
      reviewedAt: DateTime.parse(json['reviewedAt'] as String),
      reviewedBy: json['reviewedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      if (adminNote != null) 'adminNote': adminNote,
      'reviewedAt': reviewedAt.toIso8601String(),
      'reviewedBy': reviewedBy,
    };
  }

  bool get isPass => result == 'PASS';
  bool get isFail => result == 'FAIL';
}

/// Check-in request DTO
class CheckinRequest {
  final double lat;
  final double lng;
  final String? deviceNote;
  final List<ChecklistAnswer>? checklistAnswers;

  CheckinRequest({
    required this.lat,
    required this.lng,
    this.deviceNote,
    this.checklistAnswers,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      if (deviceNote != null) 'deviceNote': deviceNote,
      if (checklistAnswers != null)
        'checklistAnswers':
            checklistAnswers!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Evidence information
class Evidence {
  final String id;
  final String photoObjectKey;
  final String? note;
  final DateTime submittedAt;
  final String submittedBy;

  Evidence({
    required this.id,
    required this.photoObjectKey,
    this.note,
    required this.submittedAt,
    required this.submittedBy,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      id: json['id'] as String,
      photoObjectKey: json['photoObjectKey'] as String,
      note: json['note'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : DateTime.now(),
      submittedBy: json['submittedBy'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photoObjectKey': photoObjectKey,
      if (note != null) 'note': note,
      'submittedAt': submittedAt.toIso8601String(),
      'submittedBy': submittedBy,
    };
  }
}

