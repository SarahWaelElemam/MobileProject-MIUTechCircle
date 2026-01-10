class FreelanceApplicationModel {
  final String applicationId;
  final String projectId;
  final String applicantId;
  final String introduction;
  final String status; // pending, accepted, rejected, withdrawn
  final DateTime appliedAt;
  final DateTime? reviewedAt;

  // New AI & Linkage Fields
  final String? applicantUuid;
  final String? applicantEmail;
  final String? applicantName;
  final double? matchScore;

  FreelanceApplicationModel({
    required this.applicationId,
    required this.projectId,
    required this.applicantId,
    required this.introduction,
    required this.status,
    required this.appliedAt,
    this.reviewedAt,
    this.applicantUuid,
    this.applicantEmail,
    this.applicantName,
    this.matchScore,
  });

  factory FreelanceApplicationModel.fromMap(Map<String, dynamic> map) {
    return FreelanceApplicationModel(
      applicationId: map['application_id']?.toString() ?? '',
      projectId: map['project_id']?.toString() ?? '',
      applicantId: map['applicant_id']?.toString() ?? '',
      introduction: map['introduction']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      appliedAt: map['applied_at'] != null
          ? DateTime.parse(map['applied_at'] as String)
          : DateTime.now(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      applicantUuid: map['applicant_uuid']?.toString(),
      applicantEmail: map['applicant_email']?.toString(),
      applicantName: map['applicant_name']?.toString(),
      matchScore: map['match_score'] != null
          ? double.tryParse(map['match_score'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'project_id': projectId,
      'applicant_id': applicantId,
      'introduction': introduction,
      'status': status,
      'applied_at': appliedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'applicant_uuid': applicantUuid,
      'applicant_email': applicantEmail,
      'applicant_name': applicantName,
      'match_score': matchScore,
    };
  }

  FreelanceApplicationModel copyWith({
    String? applicationId,
    String? projectId,
    String? applicantId,
    String? introduction,
    String? status,
    DateTime? appliedAt,
    DateTime? reviewedAt,
    String? applicantUuid,
    String? applicantEmail,
    String? applicantName,
    double? matchScore,
  }) {
    return FreelanceApplicationModel(
      applicationId: applicationId ?? this.applicationId,
      projectId: projectId ?? this.projectId,
      applicantId: applicantId ?? this.applicantId,
      introduction: introduction ?? this.introduction,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      applicantUuid: applicantUuid ?? this.applicantUuid,
      applicantEmail: applicantEmail ?? this.applicantEmail,
      applicantName: applicantName ?? this.applicantName,
      matchScore: matchScore ?? this.matchScore,
    );
  }

  @override
  String toString() {
    return 'FreelanceApplicationModel(applicationId: $applicationId, projectId: $projectId, status: $status)';
  }
}
