#pragma once
// Interrupt-driven reader for the Waveshare knob.
//
// The knob is not quadrature: a detent holds one channel low, GPIO8 (A) when
// turning clockwise and GPIO7 (B) anticlockwise. Polling it from the main
// loop (as rotary_encoder_custom does) misses most detents of a fast spin,
// because an LVGL redraw holds the loop longer than the pulse lasts.
//
// What the pulses look like (measured with knob_probe.h, 2026-10-16):
// - a real detent holds its channel low 5–20 ms on a fast spin and
//   100–190 ms on a slow turn;
// - about 180 µs after it ends, the OTHER channel glitches for 2–300 µs;
// - edges bounce, and on a 2 µs glitch the level read in the handler is
//   often already back high, so a falling edge can be read as "1";
// - after a fast spin the knob can rest half-way with a channel held low
//   for seconds.
//
// So a detent counts on a rising edge only if the previous edge on that
// channel was read low and the low phase lasted kMinLowUs..kMaxLowUs. The
// glitches (read high, or far shorter) and a half-detent rest (far longer)
// do not count.

#include <atomic>
#include <cstdint>

#include <driver/gpio.h>
#include <esp_log.h>
#include <esp_timer.h>

namespace knob {

constexpr int64_t kMinLowUs = 1000;
constexpr int64_t kMaxLowUs = 1000000;

struct Channel {
  gpio_num_t pin;
  int dir;
  volatile int64_t edge_us;
  volatile int level;
};

inline Channel channels[2] = {{GPIO_NUM_8, 1, 0, 1}, {GPIO_NUM_7, -1, 0, 1}};

// Net detents (clockwise positive) not yet taken by the main loop.
inline std::atomic<int> pending{0};

// Not IRAM_ATTR: an inline function in IRAM fails to link on Xtensa
// ("dangerous relocation: l32r"), and ESPHome installs the GPIO ISR service
// without ESP_INTR_FLAG_IRAM, so handlers run from flash anyway.
inline void on_edge(void *arg) {
  auto *c = static_cast<Channel *>(arg);
  int64_t now = esp_timer_get_time();
  int level = gpio_get_level(c->pin);
  if (level == 1 && c->level == 0) {
    int64_t low = now - c->edge_us;
    if (low >= kMinLowUs && low <= kMaxLowUs) pending.fetch_add(c->dir);
  }
  c->edge_us = now;
  c->level = level;
}

// Call once boot is complete. It must NOT install the GPIO ISR service:
// ESPHome's touchscreen installs it while setting up, and its
// attach_interrupt() gives up without attaching when the service already
// exists — that is what killed the touchscreen in the first attempt.
inline void setup() {
  for (auto &c : channels) {
    gpio_set_direction(c.pin, GPIO_MODE_INPUT);
    c.level = gpio_get_level(c.pin);
    c.edge_us = esp_timer_get_time();
    gpio_set_intr_type(c.pin, GPIO_INTR_ANYEDGE);
    esp_err_t err = gpio_isr_handler_add(c.pin, on_edge, &c);
    if (err != ESP_OK) {
      ESP_LOGE("knob", "GPIO%d: no ISR service (%s), knob dead", (int) c.pin, esp_err_to_name(err));
      continue;
    }
    gpio_intr_enable(c.pin);
  }
  ESP_LOGI("knob", "knob armed (GPIO8 A=%d, GPIO7 B=%d)", channels[0].level, channels[1].level);
}

// Detents since the last call, clockwise positive.
inline int take() { return pending.exchange(0); }

}  // namespace knob
