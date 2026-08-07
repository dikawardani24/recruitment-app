class JobRequirements {
  final String? title;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final double minYears;
  final String? education;
  final List<String> certifications;
  final List<String> responsibilities;

  const JobRequirements({
    this.title,
    this.requiredSkills = const [],
    this.preferredSkills = const [],
    this.minYears = 0,
    this.education,
    this.certifications = const [],
    this.responsibilities = const [],
  });
}
