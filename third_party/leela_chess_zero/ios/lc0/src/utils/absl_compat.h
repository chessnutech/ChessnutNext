/*
  Compatibility header to replace absl dependencies on iOS/Android.
  These are simplified implementations sufficient for lc0's usage.
*/

#pragma once

#include <cstdlib>
#include <functional>
#include <type_traits>
#include <utility>

// ABSL_UNREACHABLE replacement
#if !defined(ABSL_UNREACHABLE)
#if defined(__clang__) || defined(__GNUC__)
#define ABSL_UNREACHABLE() __builtin_unreachable()
#else
#define ABSL_UNREACHABLE() std::abort()
#endif
#endif

// Minimal replacement for absl::Cleanup
namespace absl {

template <typename Callable>
class Cleanup {
public:
  Cleanup(Callable callback) : callback_(std::move(callback)), engaged_(true) {}

  Cleanup(Cleanup&& other) noexcept
      : callback_(std::move(other.callback_)), engaged_(other.engaged_) {
    other.engaged_ = false;
  }

  Cleanup(const Cleanup&) = delete;
  Cleanup& operator=(const Cleanup&) = delete;
  Cleanup& operator=(Cleanup&&) = delete;

  ~Cleanup() {
    if (engaged_) {
      callback_();
    }
  }

  void Cancel() { engaged_ = false; }

private:
  Callable callback_;
  bool engaged_;
};

// Deduction guide for C++17+
template <typename Callable>
Cleanup(Callable) -> Cleanup<std::decay_t<Callable>>;

}  // namespace absl

