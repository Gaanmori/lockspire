# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico

# WorkManager instancia su base de datos Room (WorkDatabase_Impl) por
# reflexión con el constructor sin argumentos. En modo completo, R8 lo quitaba
# y la app se cerraba al arrancar en frío ("Lockspire sigue sin funcionar"):
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> [].
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
