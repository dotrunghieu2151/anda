// Example implementation showing the pattern in practice
// This demonstrates how to structure your C++ code for Slint binding

#pragma once

#include "app-window.h"
#include <slint.h>
#include <memory>
#include <string>
#include <vector>
#include <functional>
#include <chrono>

// ============================================================================
// SERVICE LAYER: Business Logic & State
// ============================================================================

class AudioDeviceService {
public:
    struct Device {
        std::string name;
        int index;
    };

    std::vector<Device> getInputDevices() const { return input_devices_; }
    std::vector<Device> getOutputDevices() const { return output_devices_; }
    int getSelectedInput() const { return selected_input_; }
    int getSelectedOutput() const { return selected_output_; }

    void selectInput(int index) {
        if (index >= 0 && index < input_devices_.size()) {
            selected_input_ = index;
            if (on_changed_) on_changed_();
        }
    }

    void selectOutput(int index) {
        if (index >= 0 && index < output_devices_.size()) {
            selected_output_ = index;
            if (on_changed_) on_changed_();
        }
    }

    void setOnChanged(std::function<void()> callback) {
        on_changed_ = callback;
    }

private:
    std::vector<Device> input_devices_ = {
        {"Default Microphone", 0},
        {"USB Microphone", 1},
        {"Headset Mic", 2}
    };
    std::vector<Device> output_devices_ = {
        {"Default Speaker", 0},
        {"Headphones", 1},
        {"USB Audio", 2}
    };
    int selected_input_ = 0;
    int selected_output_ = 0;
    std::function<void()> on_changed_;
};

class TranscriptionService {
public:
    enum class State { Idle, Recording, Paused };

    State getState() const { return state_; }
    bool isRecording() const { return state_ == State::Recording; }
    bool isPaused() const { return state_ == State::Paused; }
    
    float getDuration() const {
        if (state_ == State::Idle) return 0.0f;
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<float>(now - start_time_).count();
        return accumulated_duration_ + (state_ == State::Recording ? elapsed : 0.0f);
    }

    std::string getTranscriptionText() const { return transcription_text_; }
    std::string getTranslationText() const { return translation_text_; }
    std::string getWaveformPath() const { return waveform_path_; }

    void startRecording() {
        state_ = State::Recording;
        start_time_ = std::chrono::steady_clock::now();
        if (on_state_changed_) on_state_changed_();
    }

    void pauseRecording() {
        if (state_ == State::Recording) {
            accumulated_duration_ += getDuration();
            state_ = State::Paused;
            if (on_state_changed_) on_state_changed_();
        }
    }

    void continueRecording() {
        if (state_ == State::Paused) {
            state_ = State::Recording;
            start_time_ = std::chrono::steady_clock::now();
            if (on_state_changed_) on_state_changed_();
        }
    }

    void stopRecording() {
        state_ = State::Idle;
        accumulated_duration_ = 0.0f;
        if (on_state_changed_) on_state_changed_();
    }

    void updateTranscription(const std::string& text) {
        transcription_text_ = text;
        if (on_text_changed_) on_text_changed_();
    }

    void updateWaveform(const std::string& path) {
        waveform_path_ = path;
        if (on_text_changed_) on_text_changed_();
    }

    void setOnStateChanged(std::function<void()> callback) {
        on_state_changed_ = callback;
    }

    void setOnTextChanged(std::function<void()> callback) {
        on_text_changed_ = callback;
    }

private:
    State state_ = State::Idle;
    std::string transcription_text_;
    std::string translation_text_;
    std::string waveform_path_;
    std::chrono::steady_clock::time_point start_time_;
    float accumulated_duration_ = 0.0f;
    std::function<void()> on_state_changed_;
    std::function<void()> on_text_changed_;
};

// ============================================================================
// PRESENTER LAYER: Coordinates UI & Services
// ============================================================================

class AppPresenter {
public:
    explicit AppPresenter(std::shared_ptr<AppWindow> window)
        : window_(window)
        , audio_service_(std::make_unique<AudioDeviceService>())
        , transcription_service_(std::make_unique<TranscriptionService>())
    {
    }

    void initialize() {
        // Wire up global callbacks
        setupAudioDeviceCallbacks();
        setupTranscriptionCallbacks();
        
        // Wire up service signals
        setupServiceSignals();
        
        // Initial UI sync
        syncDeviceLists();
        syncTranscriptionState();
        
        // Start update timer
        startUpdateTimer();
    }

private:
    void setupAudioDeviceCallbacks() {
        auto& adapter = window_->global<AudioDeviceAdapter>();
        
        adapter.on_input_device_selected([this](int index) {
            audio_service_->selectInput(index);
            syncDeviceLists();
        });

        adapter.on_output_device_selected([this](int index) {
            audio_service_->selectOutput(index);
            syncDeviceLists();
        });
    }

    void setupTranscriptionCallbacks() {
        auto& adapter = window_->global<TranscriptionAdapter>();
        
        adapter.on_start_transcription([this]() {
            transcription_service_->startRecording();
            syncTranscriptionState();
        });

        adapter.on_pause_transcription([this]() {
            transcription_service_->pauseRecording();
            syncTranscriptionState();
        });

        adapter.on_continue_transcription([this]() {
            transcription_service_->continueRecording();
            syncTranscriptionState();
        });

        adapter.on_stop_transcription([this]() {
            transcription_service_->stopRecording();
            syncTranscriptionState();
        });

        adapter.on_save_audio([this]() {
            // Handle save logic
            spdlog::info("Save audio requested");
        });

        adapter.on_clear_all([this]() {
            transcription_service_->stopRecording();
            transcription_service_->updateTranscription("");
            syncTranscriptionState();
        });
    }

    void setupServiceSignals() {
        // When service state changes, update UI (thread-safe)
        transcription_service_->setOnStateChanged([this]() {
            slint::invoke_from_event_loop([this]() {
                syncTranscriptionState();
            });
        });

        transcription_service_->setOnTextChanged([this]() {
            slint::invoke_from_event_loop([this]() {
                auto& adapter = window_->global<TranscriptionAdapter>();
                adapter.set_transcription_text(
                    slint::SharedString(transcription_service_->getTranscriptionText()));
                adapter.set_translation_text(
                    slint::SharedString(transcription_service_->getTranslationText()));
            });
        });

        audio_service_->setOnChanged([this]() {
            slint::invoke_from_event_loop([this]() {
                syncDeviceLists();
            });
        });
    }

    void syncDeviceLists() {
        auto& adapter = window_->global<AudioDeviceAdapter>();
        
        // Convert service devices to Slint arrays
        std::vector<slint::SharedString> input_names;
        for (const auto& device : audio_service_->getInputDevices()) {
            input_names.push_back(slint::SharedString(device.name));
        }
        adapter.set_input_devices(slint::SharedStringVector(input_names));

        std::vector<slint::SharedString> output_names;
        for (const auto& device : audio_service_->getOutputDevices()) {
            output_names.push_back(slint::SharedString(device.name));
        }
        adapter.set_output_devices(slint::SharedStringVector(output_names));

        adapter.set_selected_input_device(audio_service_->getSelectedInput());
        adapter.set_selected_output_device(audio_service_->getSelectedOutput());
    }

    void syncTranscriptionState() {
        auto& adapter = window_->global<TranscriptionAdapter>();
        
        adapter.set_is_recording(transcription_service_->isRecording());
        adapter.set_is_paused(transcription_service_->isPaused());
        adapter.set_recording_duration(transcription_service_->getDuration());
        adapter.set_transcription_text(
            slint::SharedString(transcription_service_->getTranscriptionText()));
        adapter.set_translation_text(
            slint::SharedString(transcription_service_->getTranslationText()));
        adapter.set_waveform_path(
            slint::SharedString(transcription_service_->getWaveformPath()));
    }

    void startUpdateTimer() {
        // Update duration every 100ms
        update_timer_.start(slint::TimerMode::Repeated, 
                           std::chrono::milliseconds(100), 
                           [this]() {
            if (transcription_service_->isRecording() || 
                transcription_service_->isPaused()) {
                syncTranscriptionState();
            }
        });
    }

    std::shared_ptr<AppWindow> window_;
    std::unique_ptr<AudioDeviceService> audio_service_;
    std::unique_ptr<TranscriptionService> transcription_service_;
    slint::Timer update_timer_;
};

// ============================================================================
// USAGE IN main.cpp
// ============================================================================

/*
int main() {
    auto window = AppWindow::create();
    
    AppPresenter presenter(window);
    presenter.initialize();
    
    window->show();
    slint::run_event_loop();
    
    return 0;
}
*/
