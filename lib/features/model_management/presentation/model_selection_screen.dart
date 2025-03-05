import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/model_management/domain/model_provider.dart';
import 'package:ollama_ui/core/services/logging_service.dart';
import 'package:ollama_ui/features/engine_management/domain/engine_provider.dart';

class ModelSelectionScreen extends ConsumerStatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  ModelSelectionScreenState createState() => ModelSelectionScreenState();
}

class ModelSelectionScreenState extends ConsumerState<ModelSelectionScreen> {
  // Track the model which is currently undergoing activation.
  String _activatingModel = "";

  Future<void> activateModel(String model) async {
    final engineNotifier = ref.read(engineProvider.notifier);
    final current = ref.read(engineProvider).selectedModel;

    if (current == model) return; // Already active

    setState(() {
      _activatingModel = model;
    });

    bool modelLoaded = false;

    try {
      // Unload the current active model first.
      await engineNotifier.unloadModel(current);
      // Then load the new (intended) model.

      await engineNotifier.loadModel(model);
      modelLoaded = ref.watch(engineProvider).state == EngineState.online;
    } catch (e) {
      await LoggingService.log("Error switching from $current to $model: $e");
    }
    setState(() {
      _activatingModel = "";
    });

    if (!modelLoaded) {
      // Clear activating flag before showing the error dialog.

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error Activating Model"),
            content: Text("Failed to activate $model."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> removeModel(String model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove $model?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final engineNotifier = ref.read(engineProvider.notifier);
    final engineStatus = ref.read(engineProvider);

    // If the model to be removed is the active one, attempt to switch to another
    if (engineStatus.selectedModel == model) {
      // Retrieve current installed models (from provider state)
      final installed = ref.read(modelProvider).installedModels;
      // Pick a fallback model different from the one to remove
      final fallback = installed.firstWhere(
        (m) => m != model,
        orElse: () => "",
      );

      if (fallback.isNotEmpty) {
        // Set fallback as activating to update UI immediately.
        setState(() {
          _activatingModel = fallback;
        });

        try {
          // Unload the current active model first.
          await engineNotifier.unloadModel(model);
          // Then load the fallback model.
          await engineNotifier.loadModel(fallback);
        } catch (e) {
          await LoggingService.log(
              "Error switching from $model to fallback $fallback: $e");
        }

        // Clear the activating flag once complete.
        setState(() {
          _activatingModel = "";
        });
      }
    }

    await LoggingService.log("Removing model: $model");
    await ref.read(modelProvider.notifier).removeModel(model);
  }

  Future<void> installModel(String model) async {
    await LoggingService.log('Installing model: $model');
    await ref.read(modelProvider.notifier).installModel(model);
  }

  Future<void> cancelInstall(String model) async {
    await LoggingService.log('Cancelling installation of model: $model');
    await ref.read(modelProvider.notifier).cancelInstall(model);
  }

  Future<void> refreshModels() async {
    ref.read(modelProvider.notifier).fetchModels();
  }

  Future<void> _showInstallWarningDialog(String model) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: const Text(
          'Installing a large language model may:\n\n'
          '• Require significant disk space\n'
          '• Slow down your computer during installation\n'
          '• Impact system performance\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Install'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await LoggingService.log('Installing model after warning: $model');
      await ref.read(modelProvider.notifier).installModel(model);
    } else {
      await LoggingService.log('Model installation cancelled by user: $model');
    }
  }

  // Helper function to build the action button.
  Widget _buildModelActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color baseColor,
  }) {
    // For simplicity, we use withOpacity (as before).
    final Color disabledColor = baseColor.withAlpha(0);

    // If the label is "Activating", replace the icon with a circular progress indicator.
    Widget iconWidget;
    if (label == "Activating") {
      iconWidget = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(baseColor),
        ),
      );
    } else {
      iconWidget = Icon(icon, color: baseColor);
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: iconWidget,
      label: Text(
        label,
        style: TextStyle(color: baseColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? disabledColor : null,
        disabledBackgroundColor: onPressed == null ? disabledColor : null,
      ),
    );
  }

  // Helper widget for headers.
  Widget _buildSectionHeader(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: Text(title, style: style)),
    );
  }

  // Helper to get model info from availableModels.
  String _getModelInfo(String fullModelName) {
    final available = ref.read(modelProvider).availableModels;
    for (var m in available) {
      final String name = m["name"] as String;
      final List<String> subVersions = List<String>.from(m["subVersions"]);
      for (var sub in subVersions) {
        if ("$name:$sub" == fullModelName) {
          return m["info"] ?? "";
        }
      }
    }
    return "";
  }

  // Helper widget for installed model tiles.
  Widget _buildInstalledModelTile(String model, EngineStatus engineStatus) {
    final bool isActive = (model == engineStatus.selectedModel);
    final bool isActivating = (_activatingModel == model);
    // Disable actions on all tiles when an activation is in progress.
    final bool disableActions = _activatingModel.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(
          isActive ? Icons.chat : Icons.storage,
          color: isActive ? Colors.green : Colors.blue,
        ),
        // For active models, display a tooltip with additional model info.
        title: isActive
            ? Tooltip(
                message: _getModelInfo(model),
                child: Text(
                  "Talking to $model",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : Text(model),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isActive
                ? _buildModelActionButton(
                    label: isActivating ? "Activating" : "Activated",
                    icon: isActivating ? Icons.hourglass_top : Icons.check,
                    onPressed: null,
                    baseColor: Colors.green,
                  )
                : _buildModelActionButton(
                    label: isActivating ? "Activating" : "Activate",
                    icon: isActivating ? Icons.hourglass_top : Icons.play_arrow,
                    // Disable if any activation is in progress.
                    onPressed:
                        disableActions ? null : () => activateModel(model),
                    baseColor: Colors.blue,
                  ),
            const SizedBox(width: 8),
            // Remove button disabled if any activation is in progress.
            _buildModelActionButton(
              label: "Remove",
              icon: Icons.delete,
              onPressed: disableActions ? null : () => removeModel(model),
              baseColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for available model tiles.
  Widget _buildAvailableModelTile(String fullModelName, bool isInstalled,
      bool isActive, bool isLoading, double progress) {
    final bool disableOther =
        _activatingModel.isNotEmpty && _activatingModel != fullModelName;

    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        leading: Icon(
          isActive
              ? Icons.chat
              : isInstalled
                  ? Icons.storage
                  : Icons.cloud_download,
          color: isActive
              ? Colors.green
              : isInstalled
                  ? Colors.blue
                  : Colors.grey,
        ),
        title: Text(fullModelName),
        trailing: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value:
                          (progress > 0.0 && progress < 1.0) ? progress : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: disableOther
                        ? null
                        : () => cancelInstall(fullModelName),
                  ),
                ],
              )
            : (!isInstalled
                ? _buildModelActionButton(
                    label: "Install",
                    icon: Icons.download,
                    onPressed: disableOther
                        ? null
                        : () => _showInstallWarningDialog(fullModelName),
                    baseColor: Colors.orange,
                  )
                : (isInstalled && !isActive)
                    ? _buildModelActionButton(
                        label: _activatingModel == fullModelName
                            ? "Activating"
                            : "Activate",
                        icon: _activatingModel == fullModelName
                            ? Icons.hourglass_top
                            : Icons.play_arrow,
                        onPressed: disableOther
                            ? null
                            : () => activateModel(fullModelName),
                        baseColor: Colors.blue,
                      )
                    : _buildModelActionButton(
                        label: "Activated",
                        icon: Icons.check,
                        onPressed: null,
                        baseColor: Colors.green,
                      )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(modelProvider);
    final engineStatus = ref.watch(engineProvider);
    final headerStyle = Theme.of(context)
        .textTheme
        .titleLarge!
        .copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Model"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshModels,
          ),
        ],
      ),
      body: modelState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching models, please wait..."),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // Installed models list.
                      if (modelState.installedModels.isNotEmpty) ...[
                        _buildSectionHeader("Installed Models", headerStyle),
                        ...modelState.installedModels.map((model) =>
                            _buildInstalledModelTile(model, engineStatus)),
                      ],
                      // Available models header and list.
                      _buildSectionHeader("Available Models", headerStyle),
                      ...modelState.availableModels.expand((modelMap) {
                        final String modelName = modelMap["name"];
                        final List<dynamic> subVersionsDynamic =
                            modelMap["subVersions"] ?? [];
                        final List<String> subVersions = subVersionsDynamic
                                .isEmpty
                            ? [
                                "latest"
                              ] // Use "latest" when no size versions are available
                            : List<String>.from(subVersionsDynamic);
                        final String modelInfo = modelMap["info"] ?? "";

                        return [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Tooltip(
                                  message: modelInfo,
                                  child: Text(
                                    modelName,
                                    style: headerStyle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...subVersions.map((subVersion) {
                            final String fullModelName =
                                '$modelName:$subVersion';
                            final bool isInstalled = modelState.installedModels
                                .contains(fullModelName);
                            final bool isActive =
                                engineStatus.selectedModel == fullModelName;
                            final bool isLoading = modelState.loadingModels
                                .contains(fullModelName);
                            final double progress =
                                modelState.progress[fullModelName] ?? 0.0;
                            return _buildAvailableModelTile(fullModelName,
                                isInstalled, isActive, isLoading, progress);
                          }),
                        ];
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
