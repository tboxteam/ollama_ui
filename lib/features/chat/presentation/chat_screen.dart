import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/engine_management/domain/engine_provider.dart';
import 'package:ollama_ui/features/engine_management/data/engine_repository.dart';
import 'package:ollama_ui/features/model_management/domain/model_provider.dart';
import 'package:ollama_ui/core/services/logging_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _messages = [];
  late EngineRepository _engineRepository;

  @override
  void initState() {
    super.initState();
    _engineRepository =
        EngineRepository(); // Ensures it's initialized before use
    LoggingService.log("ChatScreen initialized");
  }

  Future<void> _sendMessage() async {
    final engineStatus = ref.read(engineProvider);
    if (engineStatus.state != EngineState.online) {
      await LoggingService.log("Engine not online. Message not sent.");
      return;
    }

    final message = _controller.text.trim();
    if (message.isEmpty) return;

    await LoggingService.log("Sending message: $message");

    setState(() {
      _messages.add("[You]\n$message");
      _messages.add("[${engineStatus.selectedModel}]\n");
    });
    _controller.clear();
    FocusScope.of(context).requestFocus(_focusNode);

    try {
      await for (final chunk in _engineRepository.sendMessage(
          engineStatus.selectedModel, message)) {
        if (!mounted) return;
        setState(() {
          _messages[_messages.length - 1] += chunk;
        });
        _scrollToBottom();
      }
      await LoggingService.log("Message sent successfully.");
    } catch (e) {
      await LoggingService.log("Error sending message: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Helper method to lookup model info from the available models.
  String _lookupModelInfo(
      String fullModelName, List<Map<String, dynamic>> availableModels) {
    for (var modelMap in availableModels) {
      final String name = modelMap["name"] as String;
      final List<dynamic> subVersionsDynamic = modelMap["subVersions"] ?? [];
      final List<String> subVersions =
          subVersionsDynamic.map((e) => e.toString()).toList();
      for (var sub in subVersions) {
        if ("$name:$sub" == fullModelName) {
          return modelMap["info"] ?? "";
        }
      }
    }
    return "";
  }

  Widget _buildEngineStatusBar(
      EngineStatus engineStatus, EngineNotifier engineNotifier) {
    final modelState = ref.watch(modelProvider);
    Widget engineText;
    if (engineStatus.state == EngineState.online) {
      final String selected = engineStatus.selectedModel;
      final String info =
          _lookupModelInfo(selected, modelState.availableModels);
      engineText = Tooltip(
        message: info,
        child: Text(
          "Talking with ${selected.isNotEmpty ? selected : "Unknown Model"}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                _getEngineStatusColor(engineStatus.state), // set correct color
          ),
        ),
      );
    } else {
      engineText = Text(
        _getEngineStatusMessage(engineStatus),
        style: TextStyle(
          fontSize: 16,
          color: _getEngineStatusColor(engineStatus.state),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                color: _getEngineStatusColor(engineStatus.state),
                size: 14,
              ),
              const SizedBox(width: 8),
              engineText,
            ],
          ),
          _buildActionButton(engineStatus, engineNotifier),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      EngineStatus engineStatus, EngineNotifier engineNotifier) {
    if (engineStatus.state == EngineState.downloading ||
        engineStatus.state == EngineState.installing ||
        engineStatus.state == EngineState.starting) {
      return const SizedBox.shrink();
    }

    final bool isOffline = engineStatus.state == EngineState.offline;
    final bool isReady = engineStatus.state == EngineState.ready;
    final String buttonText = isOffline
        ? 'Install Ollama'
        : isReady
            ? 'Install Model'
            : 'Switch Model';

    return ElevatedButton(
      onPressed: () {
        if (isOffline) {
          engineNotifier.installEngine();
        } else {
          Navigator.pushNamed(context, '/model');
        }
      },
      child: Text(buttonText),
    );
  }

  Widget _buildProgressIndicator(EngineStatus engineStatus) {
    if (engineStatus.state == EngineState.downloading) {
      return Column(
        children: [
          const SizedBox(height: 8),
          Text(
              "${_getEngineStatusMessage(engineStatus)} ${engineStatus.progress}%"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LinearProgressIndicator(
              value: (engineStatus.progress > 0 && engineStatus.progress < 100)
                  ? engineStatus.progress / 100
                  : null,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
        ],
      );
    } else if (engineStatus.state == EngineState.installing ||
        engineStatus.state == EngineState.starting) {
      return Column(
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(_getEngineStatusMessage(engineStatus)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _getEngineStatusMessage(EngineStatus status) {
    switch (status.state) {
      case EngineState.offline:
        return 'Ollama not installed';
      case EngineState.downloading:
        return 'Downloading Ollama...';
      case EngineState.installing:
        return 'Installing Ollama...';
      case EngineState.starting:
        return 'Starting Ollama...';
      case EngineState.ready:
        return 'Ollama ready, no model';
      case EngineState.online:
        return 'Talking with ${status.selectedModel.isNotEmpty ? status.selectedModel : "Unknown Model"}';
    }
  }

  Color _getEngineStatusColor(EngineState state) {
    switch (state) {
      case EngineState.offline:
        return Colors.grey;
      case EngineState.downloading:
        return Colors.blueAccent;
      case EngineState.installing:
        return Colors.orange;
      case EngineState.starting:
        return Colors.cyan;
      case EngineState.ready:
        return Colors.amber;
      case EngineState.online:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineStatus = ref.watch(engineProvider);
    final engineNotifier = ref.read(engineProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          _buildEngineStatusBar(engineStatus, engineNotifier),
          _buildProgressIndicator(engineStatus),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _messages[_messages.length - 1 - index],
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
          ),
          if (engineStatus.state == EngineState.online)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
