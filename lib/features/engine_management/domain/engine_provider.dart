import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/engine_management/data/engine_repository.dart';
import 'package:ollama_ui/core/services/logging_service.dart';
import 'package:ollama_ui/features/model_management/data/model_repository.dart';

/// Data class storing the current engine state and installation progress.
class EngineStatus {
  final EngineState state;
  final int progress;
  final String selectedModel;

  const EngineStatus({
    required this.state,
    this.progress = 0,
    this.selectedModel = "",
  });

  EngineStatus copyWith({
    EngineState? state,
    int? progress,
    String? selectedModel,
  }) {
    return EngineStatus(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      selectedModel: selectedModel ?? this.selectedModel,
    );
  }
}

/// Possible engine states.
enum EngineState {
  offline, // Engine not installed
  downloading, // Downloading engine
  installing, // Installing engine
  starting, // Engine starting up
  ready, // Engine installed but no model loaded
  online, // Engine running with a model loaded
}

/// Provides an instance of [EngineNotifier] via Riverpod.
final engineProvider =
    StateNotifierProvider<EngineNotifier, EngineStatus>((ref) {
  return EngineNotifier(EngineRepository());
});

class EngineNotifier extends StateNotifier<EngineStatus> {
  final EngineRepository _engineRepository;

  EngineNotifier(this._engineRepository)
      : super(const EngineStatus(state: EngineState.offline));

  /// Checks and starts the engine.
  Future<void> checkAndStartEngine() async {
    state = const EngineStatus(state: EngineState.starting);
    await LoggingService.log("Checking if Ollama is installed...");
    try {
      final installed = await _engineRepository.isEngineInstalled();
      if (!installed) {
        await LoggingService.log(
            "Ollama is not installed. Setting state to offline.");
        state = const EngineStatus(state: EngineState.offline);
        return;
      }

      final isRunning = await _engineRepository.isOllamaRunning();
      if (!isRunning) {
        await _engineRepository.startOllama();
      }

      final models = await ModelRepository.fetchInstalledModels();
      if (models.isNotEmpty) {
        await loadModel(models.first);
      } else {
        state = state.copyWith(state: EngineState.ready);
      }
    } catch (e) {
      await LoggingService.log("Error in checkAndStartEngine: $e");
      state = const EngineStatus(state: EngineState.offline);
    }
  }

  /// Loads the specified model.
  Future<void> loadModel(String model) async {
    try {
      await _engineRepository.loadModel(model);
      state = state.copyWith(state: EngineState.online, selectedModel: model);
    } catch (e) {
      await LoggingService.log("Error loading model $model: $e");
      state = state.copyWith(state: EngineState.ready);
    }
  }

  /// Unloads the specified model.
  Future<void> unloadModel(String model) async {
    try {
      await _engineRepository.unloadModel(model);
      state = state.copyWith(state: EngineState.ready, selectedModel: "");
    } catch (e) {
      await LoggingService.log("Error unloading model $model: $e");
    }
  }

  /// Installs the engine and updates state during installation.
  Future<void> installEngine() async {
    state = const EngineStatus(state: EngineState.downloading, progress: 0);
    try {
      await _engineRepository.installEngine(
        onStateChange: (newState) {
          state = state.copyWith(state: newState);
        },
        onProgress: (newProgress) {
          state = state.copyWith(progress: newProgress);
        },
      );

      await LoggingService.log(
          "Verifying installation using isEngineInstalled()...");
      final installed = await _engineRepository.isEngineInstalled();
      if (!installed) {
        await LoggingService.log(
            "Installation verification failed. Setting state to offline.");
        state = const EngineStatus(state: EngineState.offline, progress: 0);
        return;
      }

      // Optionally update system environment variables here.

      await _engineRepository.startOllama();
      await LoggingService.log(
          "Ollama installed successfully. Setting state to ready.");
      state = const EngineStatus(state: EngineState.ready, progress: 0);
    } catch (e) {
      await LoggingService.log("Error during engine installation: $e");
      state = const EngineStatus(state: EngineState.offline, progress: 0);
    }
  }
}
