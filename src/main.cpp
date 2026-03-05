#include <slint.h>
#include <spdlog/spdlog.h>

#include <chrono>
#include <cmath>
#include <random>
#include <thread>
#include <vector>

#include "app-window.h"

class Timer
{
  public:
    void start() { start_ = std::chrono::high_resolution_clock::now(); }

    double stop_ms()
    {
        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start_).count();
    }

    long long stop_us()
    {
        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration_cast<std::chrono::microseconds>(end - start_).count();
    }

  private:
    std::chrono::high_resolution_clock::time_point start_;
};

/**
 * Convert audio samples (-1..1) into an SVG polyline path for Slint Path.commands.
 *
 * @param samples        Audio samples in range [-1, 1].
 * @param width_px       Width of the waveform (Slint Path width).
 * @param height_px      Height of the waveform (Slint Path height).
 * @param downsample     Optional: subsampling factor to reduce points.
 *
 * @return SVG path string. Example: "M 0 50 L 1 48 L 2 47 ..."
 */
void samples_to_svg_path(const std::vector<float>& samples, std::string& path, int width_px,
                         int height_px, int downsample = 1)
{
    path.clear();
    if (samples.empty())
        return;

    path.reserve(samples.size() * 12);

    auto map_x = [&](int i) -> int { return i * width_px * 1 / (samples.size() - 1); };

    auto map_y = [&](float s) -> int { return (1 - s) * height_px; };

    // MoveTo first point
    path += "M ";
    path += "0";
    path += " ";
    path += std::to_string(map_y(samples[0]));

    // LineTo for each subsequent point
    for (int i = downsample; i < samples.size(); i += downsample) {
        path += " L ";
        path += std::to_string(map_x(i));
        path += " ";
        path += std::to_string(map_y(samples[i]));
    }
}

void generate_waveform_image(const std::vector<float>&                    samples,
                             slint::SharedPixelBuffer<slint::Rgba8Pixel>& buf, int width,
                             int height)
{
    // Fill background (fast path)
    std::fill(buf.begin(), buf.end(), slint::Rgba8Pixel{17, 17, 17, 255});  // #111

    if (samples.size() < 2)
        return;

    auto draw_pixel = [&](int x, int y, slint::Rgba8Pixel color) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
            *(buf.begin() + x + y * width) = color;
        }
    };

    slint::Rgba8Pixel waveform_color{0, 255, 136, 255};

    // Draw waveform lines using DDA
    for (size_t i = 1; i < samples.size(); i++) {
        int x1 = (i - 1) * width / (samples.size() - 1);
        int y1 = (1 - samples[i - 1]) * height;

        int x2 = i * width / (samples.size() - 1);
        int y2 = (1 - samples[i]) * height;

        int dx    = x2 - x1;
        int dy    = y2 - y1;
        int steps = std::max(std::abs(dx), std::abs(dy));

        float sx = dx / float(steps);
        float sy = dy / float(steps);

        float x = x1;
        float y = y1;

        for (int s = 0; s <= steps; s++) {
            draw_pixel(int(x), int(y), waveform_color);
            x += sx;
            y += sy;
        }
    }
}

std::vector<float> generate_random_audio_levels()
{
    std::vector<float> levels;
    for (int i = 0; i < 100; i++) {
        levels.push_back(static_cast<float>(std::rand()) / RAND_MAX);
    }
    return levels;
}

int main()
{
    // auto app = AppWindow::create();

    // // Random number generator for audio visualization
    // std::random_device               rd;
    // std::mt19937                     gen(rd());
    // std::uniform_real_distribution<> dis(0.2, 1.0);

    // // Recording state
    // bool  is_recording   = false;
    // float recording_time = 0.0f;

    // // Simulate audio levels update (would be real audio data in production)
    // slint::Timer audio_timer;
    // audio_timer.start(slint::TimerMode::Repeated, std::chrono::milliseconds(100), [&]() {
    //     if (app->global<TranscriptionAdapter>().get_is_recording()) {
    //         // Generate random audio levels for visualization
    //         std::vector<float> new_levels;
    //         for (int i = 0; i < 30; i++) {
    //             new_levels.push_back(static_cast<float>(dis(gen)));
    //         }

    //         auto model = std::make_shared<slint::VectorModel<float>>(new_levels);
    //         app->global<TranscriptionAdapter>().set_audio_levels(model);

    //         // Update recording duration
    //         recording_time += 0.1f;
    //         app->global<TranscriptionAdapter>().set_recording_duration(recording_time);
    //     }
    // });

    // // Simulate transcription updates (would be real transcription in production)
    // slint::Timer transcription_timer;
    // transcription_timer.start(slint::TimerMode::Repeated, std::chrono::milliseconds(2000), [&]()
    // {
    //     if (app->global<TranscriptionAdapter>().get_is_recording()) {
    //         static const std::vector<std::string> sample_phrases = {
    //             "Hello, this is a sample transcription.",
    //             "The audio is being captured and processed in real-time.",
    //             "You can see the waveform visualization above.",
    //             "This demonstrates how the transcription would appear.",
    //             "Multiple languages are supported for translation."};

    //         static size_t phrase_index = 0;
    //         auto current_text = app->global<TranscriptionAdapter>().get_transcription_text();

    //         if (current_text == slint::SharedString("Original transcription will appear
    //         here...")) {
    //             current_text = slint::SharedString("");
    //         }

    //         std::string new_text = std::string(current_text) + " " +
    //                                sample_phrases[phrase_index % sample_phrases.size()];
    //         app->global<TranscriptionAdapter>().set_transcription_text(
    //             slint::SharedString(new_text));

    //         // Mock translation (in production, this would use a translation API)
    //         app->global<TranscriptionAdapter>().set_translation_text(
    //             slint::SharedString(new_text + " [Translated]"));

    //         phrase_index++;
    //     }
    // });

    // // Handle start recording
    // app->global<TranscriptionAdapter>().on_start_recording([&]() {
    //     is_recording   = true;
    //     recording_time = 0.0f;
    //     app->global<TranscriptionAdapter>().set_is_recording(true);
    //     app->global<TranscriptionAdapter>().set_transcription_text(slint::SharedString(""));
    //     app->global<TranscriptionAdapter>().set_translation_text(slint::SharedString(""));
    //     app->global<TranscriptionAdapter>().set_recording_duration(0.0f);
    // });

    // // Handle stop recording
    // app->global<TranscriptionAdapter>().on_stop_recording([&]() {
    //     is_recording = false;
    //     app->global<TranscriptionAdapter>().set_is_recording(false);

    //     // Reset audio levels to idle state
    //     std::vector<float> idle_levels(30, 0.1f);
    //     auto               model = std::make_shared<slint::VectorModel<float>>(idle_levels);
    //     app->global<TranscriptionAdapter>().set_audio_levels(model);
    // });

    // // Handle save audio
    // app->global<TranscriptionAdapter>().on_save_audio([&]() {
    //     // In production, this would save the audio buffer to a .wav file
    //     slint::invoke_from_event_loop([&]() {
    //         // Show some visual feedback (in production, open a file dialog)
    //         auto current_text = app->global<TranscriptionAdapter>().get_transcription_text();
    //         if (current_text.empty() ||
    //             current_text == slint::SharedString("Original transcription will appear
    //             here...")) { app->global<TranscriptionAdapter>().set_transcription_text(
    //                 slint::SharedString("No audio to save. Start recording first."));
    //         }
    //         else {
    //             app->global<TranscriptionAdapter>().set_transcription_text(slint::SharedString(
    //                 std::string(current_text) + "\n\n[Audio would be saved as recording.wav]"));
    //         }
    //     });
    // });

    // // Handle clear transcription
    // app->global<TranscriptionAdapter>().on_clear_transcription([&]() {
    //     recording_time = 0.0f;
    //     app->global<TranscriptionAdapter>().set_transcription_text(
    //         slint::SharedString("Original transcription will appear here..."));
    //     app->global<TranscriptionAdapter>().set_translation_text(
    //         slint::SharedString("Translation will appear here..."));
    //     app->global<TranscriptionAdapter>().set_recording_duration(0.0f);

    //     // Reset audio levels
    //     std::vector<float> idle_levels(30, 0.1f);
    //     auto               model = std::make_shared<slint::VectorModel<float>>(idle_levels);
    //     app->global<TranscriptionAdapter>().set_audio_levels(model);
    // });

    auto         app = AppWindow::create();
    // std::string  drawCommands;
    // slint::Timer timer;
    // timer.start(slint::TimerMode::Repeated, std::chrono::milliseconds(16), [&]() {
    //     samples_to_svg_path(generate_random_audio_levels(), drawCommands,
    //                         app->get_waveformState().width, app->get_waveformState().height);

    //     app->set_drawCommands(slint::SharedString(drawCommands));
    // });
    app->show();
    slint::run_event_loop();
    return 0;
}