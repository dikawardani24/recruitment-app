/// A CV selected for upload.
///
/// This deliberately holds its contents instead of a filesystem path so the
/// same upload pipeline works on web, Android, and iOS.
class UploadFile {
  final String name;
  final List<int> bytes;

  const UploadFile({required this.name, required this.bytes});

  bool get hasBytes => bytes.isNotEmpty;
}
