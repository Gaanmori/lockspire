import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de subida para Google Play (Play App Signing: Google firma lo que
// llega a los usuarios con su propia clave). Vive fuera del repositorio;
// android/key.properties dice dónde está y está en .gitignore. Ver
// docs/release-android.md.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.lockspire.lockspire"
    // flutter_secure_storage exige compileSdk >= 37 (ver docs/STATE.md) —
    // se fija explícito en vez de usar flutter.compileSdkVersion, que
    // todavía apunta a 36 en esta versión del Flutter SDK.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lockspire.lockspire"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sin key.properties (CI, otros equipos) se firma con la clave de
            // depuración para poder probar el build release; Google Play
            // rechaza ese paquete, así que no puede publicarse por error.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                logger.warn("Lockspire: sin android/key.properties, release se firma con la clave de depuración.")
                signingConfigs.getByName("debug")
            }
            // Reglas propias de R8 además de las de Flutter (ver el archivo).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Autofill nativo (ADR 0011) — androidx.credentials:provider, para
    // LockspireCredentialProviderService. Versión estable confirmada en
    // uso de producción (Bitwarden, código fuente leído directamente vía
    // GitHub, no solo documentación) antes de fijarla acá. Nota: la rama
    // de desarrollo de androidx (androidx-main) ya tiene un
    // GetCredentialResponse(List<Credential>) que esta versión 1.6.0
    // todavía no tiene — usar siempre el constructor de un solo
    // Credential mientras se mantenga esta versión (confirmado con el
    // compilador real, no solo con la documentación).
    implementation("androidx.credentials:credentials:1.6.0")

    // Borrado del portapapeles (hallazgo S4): Android congela las apps en
    // segundo plano, así que un temporizador en Dart no corre hasta volver
    // a abrir Lockspire. WorkManager lo ejecuta el sistema.
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // Sugerencias de autofill en la barra del teclado (ADR 0026):
    // InlineSuggestionUi, la plantilla estándar que usan los teclados.
    implementation("androidx.autofill:autofill:1.1.0")

    // Tests JVM del código nativo sin Android (AutofillMatcher, revisión
    // 2026-09-28, T1).
    testImplementation("junit:junit:4.13.2")
}
