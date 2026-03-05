# Product Context: Anda

## Problem Statement
Users need a native desktop application for **real-time audio transcription and translation** that provides:
- Real-time audio capture from selected input device
- Real-time transcription of spoken audio to text
- Real-time translation of transcribed text to target language
- Audio device selection (input/output)
- Language selection (source/destination)
- Low-latency processing for natural conversation flow
- Cross-platform availability
- Modern, responsive UI

## Solution Approach
Anda provides a native C++ application optimized for real-time processing:
- **Slint UI**: Declarative, reactive UI framework for native performance
- **PortAudio**: Cross-platform audio I/O for capturing input audio streams
- **Audio Buffering**: Chunk-based audio processing for real-time transcription
- **AI Models**: OpenAI Whisper (or similar) for speech-to-text transcription
- **Translation Engine**: AI-based translation for real-time language conversion
- **SoXR**: Audio resampling for format compatibility
- **Visualization**: Real-time waveform display using SVG path rendering
- **Modular Design**: Separated UI components and business logic
- **Performance Optimization**: Optimized for real-time audio buffer processing

## User Experience Goals
1. **Intuitive Interface**: Clean, modern UI with clear controls for device and language selection
2. **Real-time Feedback**: 
   - Live audio visualization during capture
   - Real-time transcription text appearing as user speaks
   - Real-time translation text appearing shortly after transcription
3. **Low Latency**: Minimal delay between speech and displayed transcription/translation
4. **Multi-language Support**: Easy selection of source and destination languages
5. **Device Flexibility**: Easy selection of input and output audio devices
6. **Cross-platform Consistency**: Same experience across all platforms
7. **Performance**: Native performance optimized for real-time audio processing

## Current UI Components

### Active Components
- **AppWindow**: Main application window with counter demo and waveform visualizer
- **WaveformVisualizer**: Component for displaying audio waveforms using SVG paths

### Available Components (Commented Out)
- **AudioTranscriptionApp**: Full-featured audio transcription interface with:
  - Device selection (input/output)
  - Language selection (from/to)
  - Real-time audio level visualization
  - Transcription and translation text displays
  - Recording controls (start/stop/save/clear)
  - Status bar with recording duration

## Key Features
- Real-time audio waveform visualization
- Audio device selection
- Language selection for transcription/translation
- Recording state management
- Text display for transcription and translation results
