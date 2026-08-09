import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_form_controller.dart';
import '../widgets/gradient_header.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/section_card.dart';

class JobFormScreen extends HookConsumerWidget {
  const JobFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final titleController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final jdFile = useState<File?>(null);
    final jdFileName = useState<String?>(null);

    final formState = ref.watch(jobFormControllerProvider);
    final formController = ref.read(jobFormControllerProvider.notifier);

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
      final messenger = ScaffoldMessenger.of(context);
      try {
        final job = await formController.createJob(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          jdFile: jdFile.value,
          jdFileName: jdFileName.value,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Created "${job.title}"')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to create job: $e')),
        );
      }
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(),
          body: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const GradientHeader(
                  icon: Icons.post_add,
                  title: 'Create a job',
                  subtitle: 'Post a role and rank matching CVs in one place.',
                ),
                const SizedBox(height: 16),
                SectionCard(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Job title',
                          hintText: 'e.g. Senior Backend Engineer',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
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
                        label: Text(
                          jdFileName.value ?? 'Upload JD file (optional)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: formState.submitting ? null : submit,
                        icon: formState.submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          formState.submitting ? 'Creating…' : 'Create job',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (formState.submitting)
          LoadingOverlay(message: formState.loadingMessage ?? 'Loading…'),
      ],
    );
  }
}
