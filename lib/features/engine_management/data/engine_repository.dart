import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:ollama_ui/core/services/logging_service.dart';
import 'package:ollama_ui/features/engine_management/domain/engine_provider.dart';

/// Low-level class that executes commands for engine installation, listing, and operation.
class EngineRepository {
  static String ollamaApiUrl = 'http://127.0.0.1:11434';

  // Reuse a single http.Client instance for efficient resource management.
  final http.Client _client = http.Client();

  /// Dispose the HTTP client when no longer needed.
  void dispose() {
    _client.close();
  }

  /// Checks if Ollama is running by issuing an HTTP GET request.
  Future<bool> isOllamaRunning() async {
    try {
      final response = await _client.get(Uri.parse(ollamaApiUrl));
      if (response.statusCode == 200 && response.body == "Ollama is running.") {
        return true;
      }
    } catch (e) {
      // Log error and continue returning false.
      await LoggingService.log("Error checking Ollama status: $e");
    }
    return false;
  }

  /// Starts Ollama if it is not running.
  Future<void> startOllama() async {
    final isRunning = await isOllamaRunning();
    if (!isRunning) {
      await Process.start('ollama', ['serve']);
      // Wait a couple of seconds to allow Ollama to start
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Sends a message to the engine API and streams the response.
  Stream<String> sendMessage(String model, String message) async* {
    try {
      final request = http.Request(
        "POST",
        Uri.parse("$ollamaApiUrl/api/generate"),
      )
        ..headers.addAll({"Content-Type": "application/json; charset=utf-8"})
        ..body = jsonEncode({"model": model, "prompt": message});

      final streamedResponse = await _client.send(request);
      final responseStream = streamedResponse.stream.transform(utf8.decoder);

      await for (final chunk
          in responseStream.transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue; // Skip empty lines

        final Map<String, dynamic> jsonResponse = jsonDecode(chunk);
        if (jsonResponse.containsKey("response")) {
          yield jsonResponse["response"]; // Emit each response chunk
        }
        if (jsonResponse["done"] == true) {
          break; // End streaming when done
        }
      }
    } catch (e) {
      await LoggingService.log("Error pulling model: $e");
      yield "[ERROR] Failed to communicate with Ollama.";
    }
  }

  /// Checks if the engine is installed by running "ollama list" or checking the binary.
  Future<bool> isEngineInstalled() async {
    try {
      final result = await Process.run('ollama', ['list']);
      if (result.exitCode == 0) {
        await LoggingService.log("Ollama is installed and responding.");
        return true;
      } else {
        await LoggingService.log(
            "ollama list failed. Exit code: ${result.exitCode}");
      }
    } catch (e) {
      await LoggingService.log("Error running ollama list: ${e.toString()}");
    }

    // Fallback: verify binary exists in expected paths
    if (Platform.isWindows) {
      if (File(r'C:\Program Files\Ollama\ollama.exe').existsSync()) return true;
    } else if (Platform.isMacOS) {
      if (Directory('/Applications/Ollama.app').existsSync()) return true;
    } else if (Platform.isLinux) {
      final whichResult = await Process.run('which', ['ollama']);
      if (whichResult.exitCode == 0) return true;
    }

    await LoggingService.log("Ollama is not installed or not recognized.");
    return false;
  }

  /// Installs the engine if missing (placeholder logic for MVP).
  Future<void> installEngine({
    required void Function(EngineState newState) onStateChange,
    required void Function(int progress) onProgress,
  }) async {
    try {
      onStateChange(EngineState.downloading);
      await LoggingService.log("Starting Ollama download...");

      final downloadUrl = Platform.isWindows
          ? 'https://ollama.com/download/OllamaSetup.exe'
          : Platform.isMacOS
              ? 'https://ollama.com/download/Ollama-darwin.zip'
              : 'https://ollama.com/install.sh';

      final installerPath = Platform.isWindows
          ? './download/OllamaSetup.exe'
          : Platform.isMacOS
              ? './download/Ollama-darwin.zip'
              : './download/install.sh';

      final dio = Dio();
      await dio.download(
        downloadUrl,
        installerPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = ((received / total) * 100).toInt();
            onProgress(progress);
          }
        },
      );

      await LoggingService.log("Download completed. Verifying installer...");
      if (!File(installerPath).existsSync()) {
        await LoggingService.log("Installer file missing after download.");
        onStateChange(EngineState.offline);
        return;
      }

      // Transition to installing state
      onStateChange(EngineState.installing);
      await LoggingService.log("Starting Ollama installation...");

      if (Platform.isWindows) {
        final result = await Process.run(installerPath, ["/silent"]);
        if (result.exitCode != 0) {
          await LoggingService.log(
              "Installation failed with exit code: ${result.exitCode}");
          onStateChange(EngineState.offline);
          return;
        }
        final userProfile = Platform.environment['USERPROFILE'];
        final ollamaPath = '$userProfile\\AppData\\Local\\Programs\\Ollama';
        await Process.run('setx', ['PATH', '%PATH%;$ollamaPath']);
      } else if (Platform.isMacOS) {
        await Process.run('unzip', [installerPath]);
        await Process.run('mv', ['Ollama.app', '/Applications/']);
        const ollamaPath = '/Applications/Ollama.app/Contents/MacOS';
        await Process.run(
            'launchctl', ['setenv', 'PATH', '\$PATH:$ollamaPath']);
      } else if (Platform.isLinux) {
        final result = await Process.run('sh', [installerPath]);
        if (result.exitCode != 0) {
          await LoggingService.log(
              "Linux installation failed: ${result.stderr}");
          onStateChange(EngineState.offline);
          return;
        }
        const ollamaPath = '/usr/local/bin';
        await Process.run('export', ['PATH=\$PATH:$ollamaPath']);
      }

      // Delete installer file(s) after successful installation.
      final installerFile = File(installerPath);
      if (installerFile.existsSync()) {
        await installerFile.delete();
        await LoggingService.log("Deleted installer file at $installerPath");
      }

      await LoggingService.log("Ollama installed successfully.");
      onStateChange(EngineState.ready);
    } catch (e) {
      await LoggingService.log("Error during installation: ${e.toString()}");
      onStateChange(EngineState.offline);
    }
  }

  /// Loads the given model by sending a POST request.
  Future<void> loadModel(String model) async {
    try {
      final url = Uri.parse("$ollamaApiUrl/api/generate");
      final response = await _client.post(
        url,
        body: jsonEncode({'model': model}),
        headers: {'Content-Type': 'application/json'},
      );
      await LoggingService.log(
          'Load Model Response status: ${response.statusCode}');
      await LoggingService.log('Load Model Response body: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to load model: ${response.body}');
      }
    } catch (e) {
      await LoggingService.log('Error loading model: $e');
      throw Exception('Failed to load model: $e');
    }
  }

  /// Unloads the given model by sending a POST request with 'keep_alive' flag set to 0.
  Future<void> unloadModel(String model) async {
    try {
      final url = Uri.parse("$ollamaApiUrl/api/generate");
      final response = await _client.post(
        url,
        body: jsonEncode({'model': model, 'keep_alive': 0}),
        headers: {'Content-Type': 'application/json'},
      );
      await LoggingService.log(
          'Unload Model Response status: ${response.statusCode}');
      await LoggingService.log('Unload Model Response body: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to unload model: ${response.body}');
      }
    } catch (e) {
      await LoggingService.log('Error unloading model: $e');
      throw Exception('Failed to unload model: $e');
    }
  }
}
