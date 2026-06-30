/// Web stub for VoiceService.
/// speech_to_text does not support web. All methods are no-ops.
class VoiceService {
  bool get isAvailable => false;
  bool get isListening => false;
  String get lastWords => '';

  void Function(String text, bool isFinal)? onPartial;
  void Function(String message)? onError;
  void Function()? onDone;

  Future<bool> initialize() async => false;
  Future<void> startListening({String localeId = 'ar-EG'}) async {}
  Future<String> stop() async => '';
  Future<void> cancel() async {}
  Future<String?> listen({String localeId = 'ar-EG'}) async => null;
}
