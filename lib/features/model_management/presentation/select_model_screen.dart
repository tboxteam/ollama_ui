import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/features/model_management/data/model_repository.dart';
import 'package:ollama_ui/features/model_management/domain/model_usage_state.dart';

class SelectModelScreen extends ConsumerStatefulWidget {
  const SelectModelScreen({super.key});

  @override
  ConsumerState<SelectModelScreen> createState() => _SelectModelScreenState();
}

class _SelectModelScreenState extends ConsumerState<SelectModelScreen> {
  List<String> _installedModels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshInstalledModels();
  }

  Future<void> _refreshInstalledModels() async {
    setState(() {
      _isLoading = true;
    });
    final repo = ProviderContainer().read(modelRepositoryProvider);
    final models = await repo.fetchLocalModels();
    setState(() {
      _installedModels = models;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usageList = ref.watch(modelUsageProvider);

    // Sort by most recently used first
    _installedModels.sort((a, b) {
      final usageA = usageList.firstWhere((u) => u.name == a,
          orElse: () => ModelUsage(name: a, usageCount: 0, lastUsed: null));
      final usageB = usageList.firstWhere((u) => u.name == b,
          orElse: () => ModelUsage(name: b, usageCount: 0, lastUsed: null));

      final dateA = usageA.lastUsed?.millisecondsSinceEpoch ?? 0;
      final dateB = usageB.lastUsed?.millisecondsSinceEpoch ?? 0;
      return dateB.compareTo(dateA); // Descending
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Select Model')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/install_model').then((_) {
            _refreshInstalledModels();
          });
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _installedModels.length,
              itemBuilder: (context, index) {
                final name = _installedModels[index];
                final usage = usageList.firstWhere((u) => u.name == name,
                    orElse: () =>
                        ModelUsage(name: name, usageCount: 0, lastUsed: null));

                final subTitle = usage.lastUsed == null
                    ? 'Never used'
                    : 'Last used: ${usage.lastUsed}';

                return ListTile(
                  title: Text(name),
                  subtitle: Text(subTitle),
                  onTap: () {
                    final repo =
                        ProviderContainer().read(modelRepositoryProvider);
                    repo.markModelUsed(name);
                    Navigator.pop(context); // Return to prior screen
                  },
                );
              },
            ),
    );
  }
}
