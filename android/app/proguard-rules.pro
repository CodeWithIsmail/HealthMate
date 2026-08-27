# R8 rules for the release build.
#
# google_mlkit_text_recognition is bundled with the Latin recogniser only —
# that is all `lib/core/privacy/text_scanner.dart` asks for. The plugin's Java
# shim, however, names the option classes for every script it *can* recognise
# (Chinese, Devanagari, Japanese, Korean) in a single `initialize` switch. Those
# artifacts are not on the classpath, so R8 hits unresolved references and
# aborts `:app:minifyReleaseWithR8`.
#
# Debug builds skip R8 entirely, which is why this only ever breaks --release.
#
# Suppressing the warnings is the correct fix rather than adding the missing
# dependencies: pulling in four more recogniser models to satisfy code paths
# that are never taken would add tens of megabytes to the APK. If Bangla support
# is ever added it will not come from these — ML Kit has no Bengali recogniser
# (see docs/privacy-redaction.md, "Known limitations").
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
