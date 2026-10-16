#pragma once
// Diagnostic only, not included by minuteur.yaml: records every edge on the
// knob pins so their real pulse shapes can be measured, and logs them as
// "A0+123 A1+4100 ..." (channel, level read after the edge, µs since the
// previous edge). Used on 2026-10-16 to design knob.h's filter.
//
// To use it: include it instead of knob.h, call knob_probe::setup() where
// knob::setup() is called, and knob_probe::drain() from a 200 ms interval;
// raise sleep_after so the device stays awake, and read the serial log.
//
// A storm guard cuts a channel's interrupt after kStormEdges edges within
// kStormWindowUs, so slow or ringing edges cannot starve the CPU (the
// suspected cause of the dead touchscreen with the reverted interrupt reader).
// The main loop re-arms it after logging.

#include <atomic>
#include <cstdint>
#include <cstdio>

#include <driver/gpio.h>
#include <esp_log.h>
#include <esp_timer.h>

namespace knob_probe {

constexpr int kStormEdges = 40;
constexpr int64_t kStormWindowUs = 20000;
constexpr size_t kRing = 1024;

struct Event {
  uint8_t ch;     // 0 = A (GPIO8, clockwise), 1 = B (GPIO7, anticlockwise)
  uint8_t level;  // level read right after the edge
  uint32_t t_us;  // low 32 bits of esp_timer_get_time()
};

struct Channel {
  gpio_num_t pin;
  uint8_t index;
  volatile int64_t window_start_us;
  volatile int window_edges;
  std::atomic<bool> storm{false};
};

inline Channel channels[2] = {{GPIO_NUM_8, 0, 0, 0}, {GPIO_NUM_7, 1, 0, 0}};
inline Event ring[kRing];
inline std::atomic<size_t> head{0};  // written by the ISR
inline size_t tail = 0;              // read by the main loop
inline std::atomic<uint32_t> dropped{0};

inline void on_edge(void *arg) {
  auto *c = static_cast<Channel *>(arg);
  int64_t now = esp_timer_get_time();
  if (now - c->window_start_us > kStormWindowUs) {
    c->window_start_us = now;
    c->window_edges = 0;
  }
  if (++c->window_edges > kStormEdges) {
    gpio_intr_disable(c->pin);
    c->storm = true;
    return;
  }
  size_t h = head.load(std::memory_order_relaxed);
  if (h - tail >= kRing) {
    dropped.fetch_add(1);
    return;
  }
  ring[h % kRing] = {c->index, (uint8_t) gpio_get_level(c->pin), (uint32_t) now};
  head.store(h + 1, std::memory_order_release);
}

// Once boot is complete, after ESPHome's touchscreen has installed the GPIO
// ISR service. Never install it here: ESPHome's attach_interrupt() gives up
// when it already exists, and the touchscreen goes dead.
inline void setup() {
  for (auto &c : channels) {
    gpio_set_direction(c.pin, GPIO_MODE_INPUT);
    gpio_set_intr_type(c.pin, GPIO_INTR_ANYEDGE);
    gpio_isr_handler_add(c.pin, on_edge, &c);
    gpio_intr_enable(c.pin);
  }
  ESP_LOGI("probe", "knob probe armed on GPIO8 (A) and GPIO7 (B)");
}

// Logs the recorded edges as "A0+123 A1+4100 ...": channel, level after the
// edge, microseconds since the previous edge on any channel.
inline void drain() {
  static uint32_t last_t = 0;
  char line[200];
  size_t len = 0;
  int n = 0;
  size_t h = head.load(std::memory_order_acquire);
  while (tail != h) {
    const Event &e = ring[tail % kRing];
    uint32_t dt = e.t_us - last_t;
    last_t = e.t_us;
    int w = snprintf(line + len, sizeof(line) - len, "%c%u+%u ", e.ch ? 'B' : 'A',
                     (unsigned) e.level, (unsigned) (dt > 9999999 ? 9999999 : dt));
    if (w > 0) len += (size_t) w;
    tail++;
    if (++n == 12 || len > sizeof(line) - 24) {
      ESP_LOGI("probe", "%s", line);
      len = 0;
      n = 0;
    }
  }
  if (len) ESP_LOGI("probe", "%s", line);
  uint32_t d = dropped.exchange(0);
  if (d) ESP_LOGW("probe", "%u edges dropped (ring full)", (unsigned) d);
  for (auto &c : channels) {
    if (c.storm.exchange(false)) {
      ESP_LOGW("probe", "storm on %c: >%d edges in %lld us, interrupt re-armed",
               c.index ? 'B' : 'A', kStormEdges, (long long) kStormWindowUs);
      c.window_edges = 0;
      gpio_intr_enable(c.pin);
    }
  }
}

}  // namespace knob_probe
