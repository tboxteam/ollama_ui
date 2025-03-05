# OllamaUI

OllamaUI is a cross-platform desktop application built with Flutter that provides a user-friendly interface for managing the Ollama engine. It allows users to interact via a chat interface and manage AI models efficiently.

## Pre-Release Version
This is a **pre-release version** of OllamaUI. Currently, only the **Windows** version is functional.

## Current Features
1. **Engine Management & Status**: Automatically detects, installs, and updates the Ollama engine as needed. Runs the engine as a background service and displays its status.
2. **Chat & Engine Interaction**: Provides a chat interface for user queries, displaying AI-generated responses.
3. **Basic Model Management**: Lists available models, allows users to load a model, and enables model deletion.

## Future Enhancements
- **Query History & Favorites**: Save previous queries and mark favorites.
- **Performance Monitoring & Alerts**: Display real-time performance metrics with alerts.
- **Downloads & Updates**: Manage model downloads and updates with visual progress indicators.
- **Multimodal Input Handling**: Supports file/image inputs with automatic text extraction.

## Installation
Currently, only the **Windows** prebuilt version is available for download.

### Download the latest release:
[OllamaUI Releases](https://github.com/tboxteam/ollama_ui/releases)

### Running from Source:
To build OllamaUI from source, ensure you have the following:
- Flutter SDK (>=3.4.4)
- Dart SDK
- Dependencies installed via `flutter pub get`

Run the application with:
```sh
flutter run
```

## Contributing
Contributions are welcome! Feel free to submit pull requests or report issues on [GitHub](https://github.com/tboxteam/ollama_ui/issues).

## License
OllamaUI is licensed under the MIT License.

