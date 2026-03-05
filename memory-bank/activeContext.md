# Active Context: Anda

## Current Work Focus

### Active Implementation
The project currently has a **minimal working demo** with:
- Basic `AppWindow` component displaying a counter
- `WaveformVisualizer` component showing generated audio waveforms
- Timer-based updates generating random audio levels
- SVG path generation for waveform display

### Current State
- **Main entry point**: `src/main.cpp` implements simple waveform visualization demo
- **Active UI**: `src/ui/app-window.slint` - Basic counter and waveform display
- **Available but unused**: `src/ui/audio-transcription.slint` - Full-featured transcription UI (commented out in main.cpp)

## Recent Changes
- Project structure established with CMake and vcpkg
- Custom Slint port configured in vcpkg-registry
- Cross-platform toolchains configured (Windows, macOS, Linux)
- Basic waveform visualization implemented
- Asset copying utility created

## Next Steps / TODO

### Immediate Tasks
1. **Activate audio transcription UI**: Uncomment and integrate `audio-transcription.slint` in main.cpp
2. **Implement PortAudio integration**: 
   - Initialize PortAudio
   - Enumerate audio devices
   - Implement audio capture callback for real-time input
   - Process audio in buffers/chunks
3. **Implement transcription backend**: 
   - Integrate OpenAI Whisper (or similar) model
   - Process audio chunks for real-time transcription
   - Display transcribed text in UI
4. **Implement translation backend**: 
   - Integrate translation model/API
   - Translate transcribed chunks in real-time
   - Display translated text in UI
5. **Optimize for real-time**: Profile and optimize audio buffer processing pipeline

### Short-term Goals
- Complete audio transcription workflow
- Real-time audio level visualization
- Device selection functionality
- Language selection and translation
- Save/load audio files

### Medium-term Goals
- Error handling and user feedback
- Settings/preferences management
- Export functionality (transcription text, audio files)
- Performance optimization
- Testing infrastructure

## Active Decisions

### UI Framework Choice
- **Slint selected** for native performance and declarative UI
- Custom vcpkg port created to ensure specific version (1.14.0)
- Live preview enabled for development

### Audio I/O Choice
- **PortAudio selected** for cross-platform audio input/output
- Provides device enumeration and real-time audio streaming
- Supports multiple audio backends (ALSA, CoreAudio, WASAPI, etc.)

### AI Model Choice
- **OpenAI Whisper** (or similar open-source models) planned for transcription/translation
- Will be integrated later in development
- Open-source approach for offline capability and privacy

### Build System Choice
- **CMake presets** for easy multi-platform builds
- **vcpkg** for dependency management with custom registry
- **Ninja** as build generator for speed

### Architecture Decisions
- **Separation of concerns**: UI in Slint, business logic in C++
- **Global adapters**: Used for state management between UI and backend
- **Component-based**: Modular UI components for reusability
- **Real-time processing**: Chunk-based audio buffer processing for low latency
- **Performance-first**: Optimized for real-time audio processing workflows

## Current Challenges

### Known Issues
- Audio transcription UI exists but is not integrated
- No actual audio capture implementation yet
- No transcription/translation backend integration
- Testing infrastructure not yet established

### Technical Debt
- Commented-out code in main.cpp (audio transcription demo)
- Basic demo implementation needs expansion
- Asset management could be enhanced

## Development Environment

### Active Toolchain
- Platform-specific toolchains configured
- vcpkg auto-setup working
- Code formatting and linting configured
- Build presets ready for all platforms

### Development Workflow
1. Use CMake presets for configuration
2. Build with platform-specific presets
3. Format code with `format` target
4. Check formatting with `check-format` target

## Focus Areas

### High Priority
1. **Audio Integration**: Connect PortAudio for real audio capture
2. **UI Activation**: Integrate full transcription UI
3. **Backend Services**: Implement transcription and translation APIs

### Medium Priority
1. **Error Handling**: Add comprehensive error handling
2. **User Experience**: Improve UI/UX based on testing
3. **Documentation**: Add user and developer documentation

### Low Priority
1. **Packaging**: Create installers for each platform
2. **CI/CD**: Set up automated builds and tests
3. **Performance**: Profile and optimize hot paths
