import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/engine_management/domain/engine_provider.dart';
import 'package:ollama_ui/features/model_management/data/model_repository.dart';
import 'package:ollama_ui/core/services/logging_service.dart';

final modelProvider = StateNotifierProvider<ModelNotifier, ModelState>((ref) {
  return ModelNotifier(ref);
});

class ModelState {
  final List<String> installedModels;
  final List<Map<String, dynamic>> availableModels;
  final bool isLoading;
  final Set<String> loadingModels;
  final Map<String, double> progress;

  ModelState({
    required this.installedModels,
    required this.availableModels,
    required this.isLoading,
    required this.loadingModels,
    required this.progress,
  });

  ModelState copyWith({
    List<String>? installedModels,
    List<Map<String, dynamic>>? availableModels,
    bool? isLoading,
    Set<String>? loadingModels,
    Map<String, double>? progress,
  }) {
    return ModelState(
      installedModels: installedModels ?? this.installedModels,
      availableModels: availableModels ?? this.availableModels,
      isLoading: isLoading ?? this.isLoading,
      loadingModels: loadingModels ?? this.loadingModels,
      progress: progress ?? this.progress,
    );
  }
}

class ModelNotifier extends StateNotifier<ModelState> {
  final Ref ref;

  ModelNotifier(this.ref)
      : super(ModelState(
          installedModels: [],
          availableModels: [],
          isLoading: true,
          loadingModels: {},
          progress: {},
        )) {
    fetchModels();
  }

  Future<void> fetchModels() async {
    state = state.copyWith(isLoading: true);
    try {
      final installed = await ModelRepository.fetchInstalledModels();
      final available = await ModelRepository.fetchAllModelsAndSizes();
      state = state.copyWith(
        installedModels: installed,
        availableModels: available,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      await LoggingService.log("Error in fetchModels: $e");
    }
  }

  Future<void> installModel(String model) async {
    // Mark the model as loading.
    state = state.copyWith(loadingModels: {...state.loadingModels, model});

    try {
      // Listen to the pull model progress stream.
      ModelRepository.pullModel(model).listen(
        (progressValue) {
          state = state
              .copyWith(progress: {...state.progress, model: progressValue});
        },
        onDone: () async {
          // On completion, refresh the installed models list.
          final installed = await ModelRepository.fetchInstalledModels();
          final engineNotifier = ref.read(engineProvider.notifier);
          try {
            if (engineNotifier.state.selectedModel != model) {
              // Unload the current model if necessary.
              await engineNotifier
                  .unloadModel(engineNotifier.state.selectedModel);
            }
            // Load the new model.
            await engineNotifier.loadModel(model);
          } catch (e) {
            await LoggingService.log("Error switching models: $e");
          }
          // Update state: refresh installed models and remove loading indicators.
          state = state.copyWith(
            installedModels: installed,
            loadingModels: {...state.loadingModels}..remove(model),
            progress: {...state.progress}..remove(model),
          );
        },
        onError: (error) async {
          // On error, log the error and clear loading indicators.
          await LoggingService.log("Error pulling model $model: $error");
          state = state.copyWith(
            loadingModels: {...state.loadingModels}..remove(model),
            progress: {...state.progress}..remove(model),
          );
        },
      );
    } catch (e) {
      // Handle synchronous errors.
      await LoggingService.log("Exception in installModel for $model: $e");
      state = state.copyWith(
        loadingModels: {...state.loadingModels}..remove(model),
      );
    }
  }

  Future<void> cancelInstall(String model) async {
    // Placeholder for future cancellation logic.
    await LoggingService.log(
        "Cancel install not implemented for model: $model");
  }

  Future<void> removeModel(String model) async {
    final engineNotifier = ref.read(engineProvider.notifier);
    final bool isActive = (engineNotifier.state.selectedModel == model);

    try {
      // If the model to remove is active, attempt to switch to an alternative model.
      if (isActive) {
        final installedBeforeRemoval =
            await ModelRepository.fetchInstalledModels();
        // Choose an alternative model different from the one to remove.
        final String newModel = installedBeforeRemoval.firstWhere(
          (m) => m != model,
          orElse: () => "",
        );
        if (newModel.isNotEmpty) {
          await engineNotifier.loadModel(newModel);
        } else {
          // No alternative available: unload the active model so that selectedModel becomes empty.
          await engineNotifier.unloadModel(model);
        }
      }

      await LoggingService.log("Removing model: $model");
      await ModelRepository.removeModel(model);

      // Refresh the installed models list.
      final installed = await ModelRepository.fetchInstalledModels();
      state = state.copyWith(
        installedModels: installed,
        loadingModels: {...state.loadingModels}..remove(model),
        progress: {...state.progress}..remove(model),
      );

      // If the removed model was active and an alternative exists but hasn't been loaded yet,
      // load the first available model.
      if (isActive &&
          installed.isNotEmpty &&
          engineNotifier.state.selectedModel == model) {
        await engineNotifier.loadModel(installed.first);
      }
    } catch (e) {
      await LoggingService.log("Error removing model $model: $e");
      state = state.copyWith(
        loadingModels: {...state.loadingModels}..remove(model),
      );
    }
  }
}
