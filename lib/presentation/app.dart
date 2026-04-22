import 'package:flutter/material.dart';

class KaiClawApp extends StatelessWidget {
  const KaiClawApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KaiClaw Controller',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const Text('Welcome to KaiClaw!'), // Placeholder for now
    );
  }
}
