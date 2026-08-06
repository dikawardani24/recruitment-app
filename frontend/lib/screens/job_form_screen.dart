import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers.dart';
import '../router.dart';
import '../widgets/loading_overlay.dart';

class JobFormScreen extends HookConsumerWidget {
  const JobFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final titleController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final jdFile = useState<File?>(null);
    final jdFileName = useState<String?>(null);
    final submitting = useState(false);
    final loadingMessage = useState<String?>(null);

    Future<void> pickJdFile() async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'md'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final name = result.files.single.name;
        final ext = name.split('.').last.toLowerCase();

        jdFile.value = file;
        jdFileName.value = name;

        // For text/markdown files, extract content and show in description.
        if (ext == 'txt' || ext == 'md' || ext == 'text') {
          try {
            final content = await file.readAsString();
            if (content.trim().isNotEmpty) {
              descriptionController.text = content;
            }
          } catch (_) {
            // Ignore read errors — user can still type manually.
          }
        }
      }
    }

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      submitting.value = true;
      loadingMessage.value = 'Creating job…';
      try {
        final job = await ref.read(apiClientProvider).createJob(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          jdFile: jdFile.value,
          jdFileName: jdFileName.value,
        );
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        ref.invalidate(jobsProvider);
        ref.read(navigatorProvider).pop();
        messenger.showSnackBar(
          SnackBar(content: Text('Created "${job.title}"')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create job: $e')),
        );
      } finally {
        if (context.mounted) {
          submitting.value = false;
          loadingMessage.value = null;
        }
      }
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('New job')),
          body: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    hintText: 'e.g. Senior Backend Engineer',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Job description',
                    hintText:
                        'Describe the role, required skills, experience and education…\n\nOr upload a JD file instead.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: pickJdFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(jdFileName.value ?? 'Upload JD file (optional)'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: submitting.value ? null : submit,
                  icon: submitting.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label:
                      Text(submitting.value ? 'Creating…' : 'Create job'),
                ),
              ],
            ),
          ),
        ),
        if (submitting.value)
          LoadingOverlay(message: loadingMessage.value ?? 'Loading…'),
      ],
    );
  }
}
