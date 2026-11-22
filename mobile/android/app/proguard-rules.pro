# Yayın derlemesinde R8 küçültmesi için ek kurallar. Release APK her değişiklikten sonra emülatörde açılıp denenmeli.

# shared_preferences_android 2.5.1 (supabase_flutter üzerinden) Kotlin sınıflarını JNI ile adıyla çağırıyor; kural
# olmadan R8 kotlin.coroutines.Continuation'ı yeniden adlandırıyor ve uygulama açılışta NoSuchMethodError ile
# takılıyor (SharedPreferencesApiRegistrar.getAll). Eklentinin 2.5.2+ ve jni 1.1.2+ sürümleri bu kuralları kendisi
# getiriyor; o sürümlere geçilince bu blok kaldırılabilir.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
