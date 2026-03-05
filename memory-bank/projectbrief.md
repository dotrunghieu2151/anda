# Project Brief: Anda

## Project Overview
**Anda** is a **real-time audio transcription and translation** cross-platform desktop application. The project uses modern C++20 with Slint for the UI framework and PortAudio for audio I/O, providing a native desktop experience across Windows, macOS, and Linux.

## Core Requirements
- Cross-platform desktop application (Windows, macOS, Linux)
- **Real-time audio transcription** from input audio device
- **Real-time translation** of transcribed audio to destination language
- Audio device selection (input and output)
- Language selection (source and destination)
- Real-time audio visualization (waveform display)
- **Performance optimization** for real-time audio buffer processing
- Modern, declarative UI using Slint framework
- Reproducible builds using CMake and vcpkg

## Project Goals
1. Provide real-time audio transcription from selected input device
2. Provide real-time translation of transcribed audio chunks/buffers
3. Support audio device selection (input/output)
4. Support multi-language selection (source/destination)
5. Optimize performance for real-time audio processing
6. Maintain cross-platform compatibility
7. Use modern C++ practices and tooling

## Core Workflow
1. User selects **input audio device** (microphone, line-in, etc.)
2. User selects **output audio device** (speakers, headphones, etc.)
3. User selects **source language** (language of input audio)
4. User selects **destination language** (target translation language)
5. Application captures audio from input device in **real-time**
6. Audio is processed in **buffers/chunks** for transcription
7. Transcribed text appears in **real-time**
8. Transcribed audio chunks are translated to destination language in **real-time**
9. Translation results appear in **real-time**

## Version
Current version: **10.1.1**

## Technology Stack
- **Language**: C++20
- **UI Framework**: Slint (declarative UI language)
- **Audio I/O**: PortAudio (cross-platform audio input/output)
- **Audio Processing**: SoXR (audio resampling)
- **Transcription/Translation**: OpenAI Whisper or similar open-source AI models (to be integrated)
- **Build System**: CMake 3.31.10+
- **Package Manager**: vcpkg (with custom ports)
- **Compilers**: MSVC (Windows), Clang (macOS/Windows), GCC (Linux)
- **Logging**: spdlog
- **Formatting**: fmt

## Performance Requirements
- **Real-time processing**: Audio buffers must be processed with minimal latency
- **Optimized for streaming**: Chunk-based processing for continuous audio streams
- **Low-latency transcription**: Transcribed text should appear with minimal delay
- **Low-latency translation**: Translated text should appear shortly after transcription

## Project Structure
- `src/` - Application source code
- `src/ui/` - Slint UI component files (.slint)
- `assets/` - Application assets and resources
- `cmake/` - CMake configuration, toolchains, and utilities
- `vcpkg-registry/` - Custom vcpkg ports for dependencies
- `.build/` - Build output directory (generated)
