import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import 'rankings_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  List<CandidateResult>? _cvs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final job = await ApiClient.instance.getJob(widget.jobId);
      final cvs = await ApiClient.instance.listCvs(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _cvs = cvs;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _pickCvs() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (files.isEmpty) return;

      final uploaded =
          await ApiClient.instance.uploadCvs(widget.jobId, files);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${uploaded.length} CV(s)')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rank() async {
    setState(() => _busy = true);
    try {
      final response = await ApiClient.instance.rankJob(widget.jobId);
      if (!mounted) return;
      setState(() => _cvs = response.results);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RankingsScreen(
            jobId: widget.jobId,
            jobTitle: _job?.title ?? 'Job',
            source: response.source,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ranking failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final job = _job;
    if (job == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final cvs = _cvs ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(job.description.isEmpty ? 'No description' : job.description),
            if (job.requirements != null) ...[
              const SizedBox(height: 16),
              _RequirementsView(requirements: job.requirements!),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickCvs,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Add CVs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _rank,
                    icon: const Icon(Icons.psychology),
                    label: const Text('Rank candidates'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Candidates (${cvs.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (cvs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No CVs uploaded yet. Tap "Add CVs".'),
                ),
              )
            else
              ...cvs.map((cv) => _CandidateTile(cv: cv)),
          ],
        ),
      ),
    );
  }
}

class _RequirementsView extends StatelessWidget {
  final JobRequirements requirements;

  const _RequirementsView({required this.requirements});

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Required skills', requirements.requiredSkills),
            section('Preferred skills', requirements.preferredSkills),
            if (requirements.minYears > 0)
              Text('Min ${requirements.minYears.round()} years experience'),
            if (requirements.education != null)
              Text('Education: ${requirements.education}'),
            section('Certifications', requirements.certifications),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final CandidateResult cv;

  const _CandidateTile({required this.cv});

  @override
  Widget build(BuildContext context) {
    final name = cv.candidateName ?? cv.fileName;
    final score = cv.overallScore;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name),
        subtitle: Text(
          cv.status == 'failed'
              ? 'Failed: ${cv.error}'
              : score == null
                  ? cv.status
                  : '${(score * 100).round()}% · ${cv.bucket ?? ''}',
        ),
        trailing: score == null
            ? (cv.status == 'failed' ? const Icon(Icons.error_outline) : null)
            : Text(
                '${(score * 100).round()}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
      ),
    );
  }
}
