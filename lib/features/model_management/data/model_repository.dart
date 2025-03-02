import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:ollama_ui/features/engine_management/data/engine_repository.dart';
import 'package:ollama_ui/core/services/logging_service.dart';

class ModelRepository {
  /// Fetches the list of installed models from the engine API.
  static Future<List<String>> fetchInstalledModels() async {
    try {
      final response = await http
          .get(Uri.parse("${EngineRepository.ollamaApiUrl}/api/tags"));
      if (response.statusCode == 200) {
        final List<dynamic> models = jsonDecode(response.body)['models'];
        return models.map((model) => model['name'].toString()).toList();
      } else {
        await LoggingService.log(
            "Failed to fetch installed models. Status: ${response.statusCode}");
      }
    } catch (e) {
      await LoggingService.log("Error fetching installed models: $e");
    }
    return [];
  }

  /// Fetches all available models and their sub-versions from the library webpage.
  static Future<List<Map<String, dynamic>>> fetchAllModelsAndSizes() async {
    final libraryUrl = Uri.parse('https://ollama.com/library');
    try {
      final libraryResponse = await http.get(libraryUrl);
      if (libraryResponse.statusCode == 200) {
        // Parse the HTML response.
        Document document = parser.parse(libraryResponse.body);

        // Extract model names, sub-versions, and model info.
        List<Map<String, dynamic>> modelsAndSubVersions = [];
        var modelElements = document.querySelectorAll('li[x-test-model]');
        for (var modelElement in modelElements) {
          var modelName = modelElement
              .querySelector('div[x-test-model-title]')
              ?.attributes['title'];
          if (modelName != null) {
            var subVersions = modelElement
                .querySelectorAll('span[x-test-size]')
                .map((e) => e.text.trim())
                .toList();

            // Extract model info from <p> with a class that includes "max-w-lg"
            var infoElement =
                modelElement.querySelector('p[class*="max-w-lg"]');
            var modelInfo = infoElement?.text.trim() ?? "";

            modelsAndSubVersions.add({
              "name": modelName,
              "subVersions": subVersions,
              "info": modelInfo,
            });
          }
        }
        return modelsAndSubVersions;
      } else {
        await LoggingService.log(
            "Failed to load search page: ${libraryResponse.statusCode}");
      }
    } catch (searchError) {
      await LoggingService.log("Error loading search page: $searchError");
    }
    return [];
  }

  /// Pulls a model by streaming progress updates.
  static Stream<double> pullModel(String model) async* {
    // Create a local HTTP client for this streaming request.
    final client = http.Client();
    try {
      final url = Uri.parse("${EngineRepository.ollamaApiUrl}/api/pull");
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'model': model, "stream": true});
      final streamedResponse = await client.send(request);
      final responseStream = streamedResponse.stream.transform(utf8.decoder);
      await for (final chunk
          in responseStream.transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue; // Skip empty lines.
        final Map<String, dynamic> jsonResponse = jsonDecode(chunk);
        if (jsonResponse["success"] == true) {
          break; // Stop processing once response is complete.
        }
        if (jsonResponse.containsKey("completed")) {
          final total = jsonResponse['total'];
          final completed = jsonResponse['completed'];
          // Guard against division by zero.
          if (total is num && total > 0) {
            final progress = (completed / total) * 100;
            yield progress.toDouble();
          }
        }
      }
    } catch (e) {
      await LoggingService.log("Error pulling model: $e");
      throw Exception('Failed to pull model');
    } finally {
      client.close();
    }
  }

  /// Removes the specified model by issuing an HTTP DELETE request.
  static Future<void> removeModel(String model) async {
    try {
      final url = Uri.parse("${EngineRepository.ollamaApiUrl}/api/delete");
      final response = await http.delete(
        url,
        body: jsonEncode({'model': model}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to remove model: ${response.body}');
      }
    } catch (e) {
      await LoggingService.log("Error removing model: $e");
      throw Exception('Failed to remove model: $e');
    }
  }

  /// Tracks the progress of a request by its ID.
  static Future<int> trackRequest(String requestId) async {
    try {
      final response = await http.get(
          Uri.parse("${EngineRepository.ollamaApiUrl}/api/track/$requestId"));
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['progress'];
      } else {
        throw Exception('Failed to track request');
      }
    } catch (e) {
      await LoggingService.log("Error tracking request: $e");
      throw Exception('Failed to track request');
    }
  }
}
