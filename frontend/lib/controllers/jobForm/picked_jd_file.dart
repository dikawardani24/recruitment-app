import 'dart:io';

/// A job description file chosen by the user, plus the description text read
/// out of it when the file is a text/markdown document.
class PickedJdFile {
  final File file;
  final String name;
  final String? description;

  const PickedJdFile({
    required this.file,
    required this.name,
    this.description,
  });
}
