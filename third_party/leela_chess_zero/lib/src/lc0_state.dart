/// The state of the underlying lc0 engine.
enum Lc0State {
  /// The engine is starting.
  starting,

  /// The engine is ready to accept UCI commands.
  ready,

  /// The engine has been disposed.
  disposed,

  /// The engine encountered an error during initialization.
  error,
}

