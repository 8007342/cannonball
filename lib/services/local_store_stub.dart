class LocalStore {
  static final Map<String, String> _values = {};
  String? read(String key) => _values[key];
  void write(String key, String value) => _values[key] = value;
}
