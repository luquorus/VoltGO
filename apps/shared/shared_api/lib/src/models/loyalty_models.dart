/// Loyalty Point System Models
/// 
/// DTOs for loyalty points, ratings, badges, and referrals

/// Loyalty user profile containing points and level info
class LoyaltyUserProfile {
  final String userId;
  final int currentPoints;
  final int lifetimePoints;
  final int totalRatings;
  final int totalBookings;
  final int totalSwaps;
  final int totalContributions;
  final int level;
  final String levelName;
  final List<UserBadge> badges;
  final int pointsToNextLevel;
  final int pointsNeededForNextLevel;

  LoyaltyUserProfile({
    required this.userId,
    required this.currentPoints,
    required this.lifetimePoints,
    required this.totalRatings,
    required this.totalBookings,
    required this.totalSwaps,
    required this.totalContributions,
    required this.level,
    required this.levelName,
    required this.badges,
    required this.pointsToNextLevel,
    required this.pointsNeededForNextLevel,
  });

  factory LoyaltyUserProfile.fromJson(Map<String, dynamic> json) {
    return LoyaltyUserProfile(
      userId: json['userId'] as String,
      currentPoints: json['currentPoints'] as int? ?? 0,
      lifetimePoints: json['lifetimePoints'] as int? ?? 0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      totalBookings: json['totalBookings'] as int? ?? 0,
      totalSwaps: json['totalSwaps'] as int? ?? 0,
      totalContributions: json['totalContributions'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      levelName: json['levelName'] as String? ?? 'Member',
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pointsToNextLevel: json['pointsToNextLevel'] as int? ?? 0,
      pointsNeededForNextLevel: json['pointsNeededForNextLevel'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'currentPoints': currentPoints,
      'lifetimePoints': lifetimePoints,
      'totalRatings': totalRatings,
      'totalBookings': totalBookings,
      'totalSwaps': totalSwaps,
      'totalContributions': totalContributions,
      'level': level,
      'levelName': levelName,
      'badges': badges.map((e) => e.toJson()).toList(),
      'pointsToNextLevel': pointsToNextLevel,
      'pointsNeededForNextLevel': pointsNeededForNextLevel,
    };
  }
}

/// Point transaction record
class PointTransaction {
  final String id;
  final String type;       // EARN / REDEEM / EXPIRE / ADJUST
  final String source;     // BOOKING / RATING / CR_SUBMIT / etc
  final String? sourceId;
  final int points;
  final int balanceAfter;
  final String description;
  final DateTime createdAt;

  PointTransaction({
    required this.id,
    required this.type,
    required this.source,
    this.sourceId,
    required this.points,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      source: json['source'] as String,
      sourceId: json['sourceId'] as String?,
      points: json['points'] as int? ?? 0,
      balanceAfter: json['balanceAfter'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'source': source,
      'sourceId': sourceId,
      'points': points,
      'balanceAfter': balanceAfter,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get sourceDisplayName {
    switch (source) {
      case 'BOOKING':
        return 'Charging Session';
      case 'BATTERY_SWAP':
        return 'Battery Swap';
      case 'RATING':
        return 'Station Rating';
      case 'RATING_WITH_COMMENT':
        return 'Station Rating';
      case 'CR_SUBMIT':
        return 'CR Submission';
      case 'CR_PUBLISH':
        return 'CR Published';
      case 'REFERRAL':
        return 'Referral';
      case 'BADGE':
        return 'Badge Earned';
      case 'ADMIN_ADJUST':
        return 'Admin Adjustment';
      default:
        return source;
    }
  }

  String get typeDisplayName {
    switch (type) {
      case 'EARN':
        return 'Earned';
      case 'REDEEM':
        return 'Redeemed';
      case 'EXPIRE':
        return 'Expired';
      case 'ADJUST':
        return 'Adjusted';
      default:
        return type;
    }
  }
}

/// Station eligible for rating
class EligibleStationForRating {
  final String stationId;
  final String eligibilityId;
  final String stationName;
  final String stationAddress;
  final DateTime eligibleAt;
  final String sourceType;  // BOOKING_USAGE / SWAP_USAGE / INFO_CONTRIBUTION
  final String? sourceId;
  final bool isRated;

  EligibleStationForRating({
    required this.stationId,
    required this.eligibilityId,
    required this.stationName,
    required this.stationAddress,
    required this.eligibleAt,
    required this.sourceType,
    this.sourceId,
    required this.isRated,
  });

  factory EligibleStationForRating.fromJson(Map<String, dynamic> json) {
    return EligibleStationForRating(
      stationId: json['stationId'] as String,
      eligibilityId: json['eligibilityId'] as String,
      stationName: json['stationName'] as String? ?? 'Unknown Station',
      stationAddress: json['stationAddress'] as String? ?? '',
      eligibleAt: json['eligibleAt'] != null
          ? DateTime.parse(json['eligibleAt'] as String)
          : DateTime.now(),
      sourceType: json['sourceType'] as String,
      sourceId: json['sourceId'] as String?,
      isRated: json['isRated'] as bool? ?? false,
    );
  }

  String get sourceDisplayName {
    switch (sourceType) {
      case 'BOOKING_USAGE':
        return 'After Charging';
      case 'SWAP_USAGE':
        return 'After Swap';
      case 'INFO_CONTRIBUTION':
        return 'After CR Published';
      default:
        return sourceType;
    }
  }
}

/// User's rating for a station
class MyRating {
  final String id;
  final String stationId;
  final String stationName;
  final int rating;
  final String? comment;
  final bool isVerified;
  final int helpfulCount;
  final DateTime createdAt;

  MyRating({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.rating,
    this.comment,
    required this.isVerified,
    required this.helpfulCount,
    required this.createdAt,
  });

  factory MyRating.fromJson(Map<String, dynamic> json) {
    return MyRating(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String? ?? 'Unknown Station',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      helpfulCount: json['helpfulCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      'rating': rating,
      'comment': comment,
      'isVerified': isVerified,
      'helpfulCount': helpfulCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Station rating (public view)
class StationRating {
  final String id;
  final String stationId;
  final String stationName;
  final int rating;
  final String? comment;
  final bool isVerified;
  final int helpfulCount;
  final DateTime createdAt;
  final String? userEmail;

  StationRating({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.rating,
    this.comment,
    required this.isVerified,
    required this.helpfulCount,
    required this.createdAt,
    this.userEmail,
  });

  factory StationRating.fromJson(Map<String, dynamic> json) {
    return StationRating(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String? ?? 'Unknown Station',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      helpfulCount: json['helpfulCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      userEmail: json['userEmail'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      'rating': rating,
      'comment': comment,
      'isVerified': isVerified,
      'helpfulCount': helpfulCount,
      'createdAt': createdAt.toIso8601String(),
      'userEmail': userEmail,
    };
  }

  String get maskedEmail {
    if (userEmail == null || userEmail!.isEmpty) return 'Anonymous';
    final parts = userEmail!.split('@');
    if (parts.length != 2) return 'Anonymous';
    final name = parts[0];
    if (name.length <= 2) return '${name[0]}***@${parts[1]}';
    return '${name.substring(0, 2)}***@${parts[1]}';
  }
}

/// Station rating summary
class StationRatingSummary {
  final String stationId;
  final double averageRating;
  final int totalRatings;
  final int r1;
  final int r2;
  final int r3;
  final int r4;
  final int r5;

  StationRatingSummary({
    required this.stationId,
    required this.averageRating,
    required this.totalRatings,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
  });

  factory StationRatingSummary.fromJson(Map<String, dynamic> json) {
    return StationRatingSummary(
      stationId: json['stationId'] as String,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      r1: json['r1'] as int? ?? 0,
      r2: json['r2'] as int? ?? 0,
      r3: json['r3'] as int? ?? 0,
      r4: json['r4'] as int? ?? 0,
      r5: json['r5'] as int? ?? 0,
    );
  }

  int getCountForRating(int rating) {
    switch (rating) {
      case 1: return r1;
      case 2: return r2;
      case 3: return r3;
      case 4: return r4;
      case 5: return r5;
      default: return 0;
    }
  }

  double getPercentForRating(int rating) {
    if (totalRatings == 0) return 0.0;
    return (getCountForRating(rating) / totalRatings) * 100;
  }
}

/// Badge earned by user
class UserBadge {
  final String id;
  final String code;
  final String name;
  final String description;
  final String tier;     // BRONZE / SILVER / GOLD
  final String icon;
  final DateTime earnedAt;

  UserBadge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.tier,
    required this.icon,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tier: json['tier'] as String? ?? 'BRONZE',
      icon: json['icon'] as String? ?? 'star',
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'tier': tier,
      'icon': icon,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }
}

/// Badge with progress (earned or locked)
class BadgeWithProgress {
  final String id;
  final String code;
  final String name;
  final String tier;
  final String description;
  final String icon;
  final int currentValue;
  final int targetValue;
  final int pointsBonus;
  final bool isEarned;

  BadgeWithProgress({
    required this.id,
    required this.code,
    required this.name,
    required this.tier,
    required this.description,
    required this.icon,
    required this.currentValue,
    required this.targetValue,
    required this.pointsBonus,
    required this.isEarned,
  });

  factory BadgeWithProgress.fromJson(Map<String, dynamic> json) {
    return BadgeWithProgress(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      tier: json['tier'] as String? ?? 'BRONZE',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'star',
      currentValue: json['currentValue'] as int? ?? 0,
      targetValue: json['targetValue'] as int? ?? 1,
      pointsBonus: json['pointsBonus'] as int? ?? 0,
      isEarned: json['isEarned'] as bool? ?? false,
    );
  }

  double get progressPercent {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
}

/// Submit rating request
class SubmitRatingRequest {
  final String stationId;
  final String? eligibilityId;
  final int rating;
  final String? comment;

  SubmitRatingRequest({
    required this.stationId,
    this.eligibilityId,
    required this.rating,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      if (eligibilityId != null) 'eligibilityId': eligibilityId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
    };
  }
}

/// Referral code response
class ReferralCode {
  final String code;
  final String referralLink;
  final DateTime createdAt;

  ReferralCode({
    required this.code,
    required this.referralLink,
    required this.createdAt,
  });

  factory ReferralCode.fromJson(Map<String, dynamic> json) {
    return ReferralCode(
      code: json['code'] as String,
      referralLink: json['referralLink'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Admin: Loyalty dashboard stats
class LoyaltyDashboardStats {
  final int totalPointsIssued;
  final int pointsThisMonth;
  final int activeUsers;
  final int ratingsToday;
  final List<DailyPointsData> pointsPerDay;
  final List<TopUserPoints> topUsers;

  LoyaltyDashboardStats({
    required this.totalPointsIssued,
    required this.pointsThisMonth,
    required this.activeUsers,
    required this.ratingsToday,
    required this.pointsPerDay,
    required this.topUsers,
  });

  factory LoyaltyDashboardStats.fromJson(Map<String, dynamic> json) {
    return LoyaltyDashboardStats(
      totalPointsIssued: json['totalPointsIssued'] as int? ?? 0,
      pointsThisMonth: json['pointsThisMonth'] as int? ?? 0,
      activeUsers: json['activeUsers'] as int? ?? 0,
      ratingsToday: json['ratingsToday'] as int? ?? 0,
      pointsPerDay: (json['pointsPerDay'] as List<dynamic>?)
              ?.map((e) => DailyPointsData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topUsers: (json['topUsers'] as List<dynamic>?)
              ?.map((e) => TopUserPoints.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyPointsData {
  final DateTime date;
  final int points;

  DailyPointsData({required this.date, required this.points});

  factory DailyPointsData.fromJson(Map<String, dynamic> json) {
    return DailyPointsData(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      points: json['points'] as int? ?? 0,
    );
  }
}

class TopUserPoints {
  final String userId;
  final String? email;
  final int currentPoints;
  final int lifetimePoints;

  TopUserPoints({
    required this.userId,
    this.email,
    required this.currentPoints,
    required this.lifetimePoints,
  });

  factory TopUserPoints.fromJson(Map<String, dynamic> json) {
    return TopUserPoints(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      currentPoints: json['currentPoints'] as int? ?? 0,
      lifetimePoints: json['lifetimePoints'] as int? ?? 0,
    );
  }

  String get maskedEmail {
    if (email == null || email!.isEmpty) return 'Unknown';
    final parts = email!.split('@');
    if (parts.length != 2) return 'Unknown';
    final name = parts[0];
    if (name.length <= 2) return '${name[0]}***@${parts[1]}';
    return '${name.substring(0, 2)}***@${parts[1]}';
  }
}

/// Admin: Rating for moderation
class AdminRating {
  final String id;
  final String stationId;
  final String stationName;
  final String userId;
  final String? userEmail;
  final int rating;
  final String? comment;
  final String status;  // ACTIVE / HIDDEN / FLAGGED
  final int helpfulCount;
  final DateTime createdAt;

  AdminRating({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.userId,
    this.userEmail,
    required this.rating,
    this.comment,
    required this.status,
    required this.helpfulCount,
    required this.createdAt,
  });

  factory AdminRating.fromJson(Map<String, dynamic> json) {
    return AdminRating(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String? ?? 'Unknown Station',
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String?,
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      helpfulCount: json['helpfulCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  String get maskedEmail {
    if (userEmail == null || userEmail!.isEmpty) return 'Anonymous';
    final parts = userEmail!.split('@');
    if (parts.length != 2) return 'Anonymous';
    final name = parts[0];
    if (name.length <= 2) return '${name[0]}***@${parts[1]}';
    return '${name.substring(0, 2)}***@${parts[1]}';
  }
}
