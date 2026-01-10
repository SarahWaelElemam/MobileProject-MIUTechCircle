class FreelanceApplicationModel {
  final String applicationId;
  final String projectId;
  final String applicantId;
  final String introduction;
  final String status; // pending, accepted, rejected, withdrawn
  final DateTime appliedAt;
  final DateTime? reviewedAt;

  FreelanceApplicationModel({
    required this.applicationId,
    required this.projectId,
    required this.applicantId,
    required this.introduction,
    required this.status,
    required this.appliedAt,
    this.reviewedAt,
  });

  factory FreelanceApplicationModel.fromMap(Map<String, dynamic> map) {
    return FreelanceApplicationModel(
      applicationId: map['application_id'] as String,
      projectId: map['project_id'] as String,
      applicantId: map['applicant_id'] as String,
      introduction: map['introduction'] as String,
      status: map['status'] as String,
      appliedAt: DateTime.parse(map['applied_at'] as String),
      reviewedAt: map['reviewed_at'] != null 
          ? DateTime.parse(map['reviewed_at'] as String) 
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
  }) {
    return FreelanceApplicationModel(
      applicationId: applicationId ?? this.applicationId,
      projectId: projectId ?? this.projectId,
      applicantId: applicantId ?? this.applicantId,
      introduction: introduction ?? this.introduction,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  @override
  String toString() {
    return 'FreelanceApplicationModel(applicationId: $applicationId, projectId: $projectId, status: $status)';
  }
}