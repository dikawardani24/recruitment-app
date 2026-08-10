import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/jobForm/job_form_controller.dart';
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
      final picked = await formController.pickJdFile();
      if (picked == null) return;
      jdFile.value = picked.file;
      jdFileName.value = picked.name;
      if (picked.description != null) {
        descriptionController.text = picked.description!;
      }
    }

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      await formController.submit(
        context,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        jdFile: jdFile.value,
        jdFileName: jdFileName.value,
      );
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
