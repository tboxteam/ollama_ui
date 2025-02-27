import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama_ui/core/services/library_service.dart';
import 'package:ollama_ui/features/model_management/data/model_repository.dart';

class InstallModelScreen extends ConsumerStatefulWidget {
  const InstallModelScreen({super.key});

  @override
  ConsumerState<InstallModelScreen> createState() => _InstallModelScreenState();
}

class _InstallModelScreenState extends ConsumerState<InstallModelScreen> {
  List<LibraryModel> _popularModels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPopularModels();
  }

  Future<void> _fetchPopularModels() async {
    setState(() {
      _isLoading = true;
    });
    final service = LibraryService();
    final result = await service.getTopPopularModels();
    setState(() {
      _popularModels = result;
      _isLoading = false;
    });
  }

  Future<void> _installModel(String modelName) async {
    // For MVP, we just assume the user is installing the model externally,
    // then we re-fetch local models so they're recognized.
    final repo = ProviderContainer().read(modelRepositoryProvider);
    await repo.fetchLocalModels();

    if (mounted) {
      Navigator.pop(context); // Close screen after 'install'
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Install Model')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _popularModels.isEmpty
              ? const Center(child: Text('Unable to fetch popular models.'))
              : ListView.builder(
                  itemCount: _popularModels.length,
                  itemBuilder: (context, index) {
                    final model = _popularModels[index];
                    return ListTile(
                      title: Text(model.name),
                      subtitle: Text(model.description),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _installModel(model.name);
                        },
                        child: const Text('Install'),
                      ),
                    );
                  },
                ),
    );
  }
}
