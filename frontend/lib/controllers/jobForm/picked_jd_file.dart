import '../../domain/models/upload_file.dart';

/// A job description file chosen by the user, plus the description text read
/// out of it when the file is a text/markdown document.
class PickedJdFile {
  final UploadFile file;
  final String? description;

  const PickedJdFile({required this.file, this.description});
}
