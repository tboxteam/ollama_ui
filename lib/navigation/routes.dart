import 'package:flutter/material.dart';
import 'package:ollama_ui/features/chat/presentation/chat_screen.dart';
import 'package:ollama_ui/features/model_management/presentation/model_selection_screen.dart';

class Routes {
  static const String chat = '/';
  static const String modelSelection = '/model';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.chat: (context) => const ChatScreen(),
  Routes.modelSelection: (context) => const ModelSelectionScreen(),
};
