import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/engine_management/domain/engine_provider.dart';
import 'package:ollama_ui/navigation/routes.dart';

class OllamaUI extends ConsumerStatefulWidget {
  const OllamaUI({super.key});

  @override
  ConsumerState<OllamaUI> createState() => _OllamaUIState();
}

class _OllamaUIState extends ConsumerState<OllamaUI> {
  @override
  void initState() {
    super.initState();
    // Execute engine startup after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(engineProvider.notifier).checkAndStartEngine();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ollama UI',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: appRoutes, // Our route map
      initialRoute: Routes.chat, // Use route constant for clarity
      debugShowCheckedModeBanner: false,
    );
  }
}
