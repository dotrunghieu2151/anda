#include "app-window.h"

int main()
{
    auto ui_window = AppWindow::create();

    ui_window->on_request_increase_value(
        [&] { ui_window->set_counter(ui_window->get_counter() + 1); });

    ui_window->run();
    return 0;
}