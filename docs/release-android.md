# Publicar Lockspire en Google Play

Google Play usa **Play App Signing**: Google guarda la clave con la que se firma la app que llega a los usuarios. Nosotros solo tenemos la **clave de subida**, con la que firmamos el AAB que subimos. Si se pierde o se filtra, Google permite cambiarla desde Play Console, así que perderla no deja la app huérfana.

## 1. Crear la clave de subida (una sola vez)

- La clave vive **fuera del repositorio**, en `%USERPROFILE%\.lockspire\`.
- Haga una copia de respaldo en un lugar seguro, por ejemplo su propia bóveda de Lockspire. Guarde también la contraseña.
- `keytool` pide la contraseña y los datos del certificado. No escriba la contraseña en la línea de comandos.

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.lockspire" | Out-Null
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore "$env:USERPROFILE\.lockspire\upload-keystore.jks" `
  -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

## 2. Decirle a Gradle dónde está

Cree `app/android/key.properties`. Está en `.gitignore`: **nunca** lo suba al repositorio.

```properties
storeFile=C:/Users/<usuario>/.lockspire/upload-keystore.jks
storePassword=<contraseña>
keyAlias=upload
keyPassword=<contraseña>
```

- Con PKCS12, las dos contraseñas son la misma.
- Sin este archivo, el build release se firma con la clave de depuración. Sirve para probar, pero Google Play lo rechaza.

## 3. Generar el AAB

Desde `app/`, con las credenciales OAuth como en los builds de siempre:

```powershell
flutter build appbundle --release --dart-define-from-file=google_oauth_secrets.json --dart-define-from-file=microsoft_oauth_secrets.json --dart-define=LOCKSPIRE_STORE=play
```

- Resultado: `app/build/app/outputs/bundle/release/app-release.aab`.
- Antes de cada subida, suba el número después del `+` en `version:` de `pubspec.yaml` (el `versionCode`). Play no acepta dos subidas con el mismo número.

## 4. Google Drive con la firma de Google

- El login de Google en Android comprueba la huella SHA-1 de la firma de la app. La app instalada desde Play lleva la firma **de Google**, no la de depuración ni la de subida.
- Cuando suba el primer AAB, vaya a Play Console → Configuración → Integridad de la app → Firma de apps y copie la **huella SHA-1 de la clave de firma de apps**.
- En Google Cloud → APIs y servicios → Credenciales, cree otro cliente OAuth de tipo Android: paquete `com.lockspire.lockspire` y esa SHA-1.
- Conviene crear otro con la SHA-1 de la clave de subida, para probar el AAB instalado a mano. Esa huella se obtiene con:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.lockspire\upload-keystore.jks" -alias upload
```

- El cliente de depuración que ya existe sigue sirviendo para `flutter run`.
- OneDrive no depende de la firma: su redirección (`com.lockspire.lockspire://oauth2redirect`) es la misma en todos los builds.
