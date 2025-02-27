import 'package:flutter/material.dart';
import 'package:ollama_ui/shared/components/sidebar.dart';

class ModelListScreen extends StatelessWidget {
  const ModelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      drawer: const Sidebar(),
      body: const Center(
        child: Text('Model List - Coming Soon', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
