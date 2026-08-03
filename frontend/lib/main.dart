import 'package:flutter/material.dart';

import 'screens/job_list_screen.dart';

void main() {
  runApp(const AtsApp());
}

class AtsApp extends StatelessWidget {
  const AtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI ATS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
        useMaterial3: true,
      ),
      home: const JobListScreen(),
    );
  }
}
