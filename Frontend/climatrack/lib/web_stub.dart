// Stub for non-web platforms
class DivElement {}
class LinkElement {}
class ScriptElement {}
class FileUploadInputElement {}
class FileReader {}
class Document {
  Head? get head => null;
}
class Head {}
final document = Document();

void registerViewFactory(String viewType, Function callback) {
  throw UnsupportedError('Not supported on this platform');
}