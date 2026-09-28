// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

package com.lockspire.lockspire

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.text.InputType
import android.view.View
import android.service.autofill.InlinePresentation
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import kotlin.random.Random

/**
 * Sistema de Autofill legado de Android (existe desde Android 8) —
 * además de [LockspireCredentialProviderService] (Credential Manager),
 * ver docs/adr/0011-autofill-android-credential-provider.md. Necesario
 * porque Credential Manager todavía no tiene soporte equivalente para
 * campos dentro de un `WebView` — confirmado en verificación manual
 * real: el login de Crunchyroll (dentro de un WebView) solo funcionó
 * con este camino, no con Credential Manager.
 *
 * Mismo principio que el resto de autofill: servicio nativo delgado,
 * nunca lee ni desencripta la bóveda — solo detecta qué campos hay que
 * llenar y arma un `PendingIntent` hacia [AutofillActivity], donde
 * ocurre todo lo sensible (desbloqueo, matching, guardado), igual que
 * [LockspireCredentialProviderService].
 */
class LockspireAutofillService : AutofillService() {

    private companion object {
        const val MAX_DIRECT_ACCOUNTS = 5
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        fillCallback: FillCallback,
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            fillCallback.onSuccess(null)
            return
        }

        val fields = findAutofillFields(structure)
        if (fields.usernameId == null && fields.passwordId == null) {
            fillCallback.onSuccess(null)
            return
        }

        // Nombre sin "packageName" a propósito — esa variable ya existe
        // como el `packageName` del propio Context (Lockspire), y
        // RemoteViews más abajo necesita justo ese, no el de la app
        // solicitante. Bug real encontrado en verificación manual:
        // llamarla igual tapaba (shadowing) el de Lockspire, y
        // RemoteViews terminaba buscando un paquete que no existía
        // (el de la app ajena) — crash real confirmado en SoundHound.
        val requestingPackage = structure.activityComponent?.packageName ?: ""
        val pendingIntent = createAutofillPendingIntent(
            usernameId = fields.usernameId,
            passwordId = fields.passwordId,
            requestingPackage = requestingPackage,
            web = fields.web,
        )

        // Sugerencia genérica gateada por autenticación — mismo patrón
        // "autenticar antes de revelar nada" que ya usa Credential
        // Manager, confirmado contra el código real de Bitwarden. Layout
        // propio con colores fijos: con `simple_list_item_1` el texto
        // salía oscuro sobre fondo oscuro en apps con tema oscuro
        // (Crunchyroll, verificación manual en el Redmi).
        val presentation = RemoteViews(packageName, R.layout.autofill_suggestion)
        val inline = InlineSuggestions(this, request)

        val responseBuilder = FillResponse.Builder()

        // Sesión de autofill (ADR 0026): tras desbloquear para rellenar, las
        // cuentas que coinciden van directo en el desplegable y el teclado.
        val accounts = AutofillSession.matching(
            context = this,
            packageName = requestingPackage,
            webDomain = fields.web?.domain,
            webScheme = fields.web?.scheme,
        ).take(MAX_DIRECT_ACCOUNTS)
        for ((index, account) in accounts.withIndex()) {
            val accountView = RemoteViews(packageName, R.layout.autofill_account).apply {
                setTextViewText(R.id.autofill_title, account.title)
                setTextViewText(R.id.autofill_subtitle, account.username)
            }
            val accountInline = inline.presentation(index, account.title, account.username)
            val builder = Dataset.Builder()
            fields.usernameId?.let {
                builder.setField(it, AutofillValue.forText(account.username), accountView, accountInline)
            }
            fields.passwordId?.let {
                builder.setField(it, AutofillValue.forText(account.password), accountView, accountInline)
            }
            responseBuilder.addDataset(builder.build())
        }

        val lockspireInline = inline.presentation(accounts.size, "Lockspire", null)
        val datasetBuilder = Dataset.Builder()
        fields.usernameId?.let {
            datasetBuilder.setField(it, null, presentation, lockspireInline)
        }
        fields.passwordId?.let {
            datasetBuilder.setField(it, null, presentation, lockspireInline)
        }
        val dataset = datasetBuilder
            .setAuthentication(pendingIntent.intentSender)
            .build()

        responseBuilder.addDataset(dataset)
        if (fields.usernameId != null && fields.passwordId != null) {
            responseBuilder.setSaveInfo(
                SaveInfo.Builder(
                    SaveInfo.SAVE_DATA_TYPE_USERNAME or SaveInfo.SAVE_DATA_TYPE_PASSWORD,
                    arrayOf(fields.usernameId, fields.passwordId),
                ).build(),
            )
        }
        fillCallback.onSuccess(responseBuilder.build())
    }

    override fun onSaveRequest(request: SaveRequest, saveCallback: SaveCallback) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure != null) {
            val fields = findAutofillFields(structure)
            val username = fields.usernameId?.let { findTypedValue(structure, it) }
            val password = fields.passwordId?.let { findTypedValue(structure, it) }
            val requestingPackage = structure.activityComponent?.packageName ?: ""

            if (!username.isNullOrEmpty() && !password.isNullOrEmpty()) {
                // No hay PendingIntent de por medio acá (a diferencia de
                // onFillRequest) — el framework espera que
                // SaveCallback.onSuccess() se llame ya mismo, la
                // confirmación real ocurre de forma asíncrona en la
                // Activity que se abre a continuación (mismo patrón que
                // el modo "crear" de Credential Manager: nunca
                // autoguardado silencioso, ver ADR 0005/0011).
                val intent = Intent(this, AutofillActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(AutofillActivity.EXTRA_LEGACY_SAVE_USERNAME, username)
                    putExtra(AutofillActivity.EXTRA_LEGACY_SAVE_PASSWORD, password)
                    putExtra(AutofillActivity.EXTRA_REQUESTING_PACKAGE, requestingPackage)
                    putWebExtras(fields.web)
                }
                startActivity(intent)
            }
        }
        saveCallback.onSuccess()
    }

    /** Valor, vista del desplegable y, si el teclado las pide, sugerencia en línea. */
    @Suppress("DEPRECATION")
    private fun Dataset.Builder.setField(
        id: AutofillId,
        value: AutofillValue?,
        view: RemoteViews,
        inline: InlinePresentation?,
    ) {
        if (inline != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            setValue(id, value, view, inline)
        } else {
            setValue(id, value, view)
        }
    }

    private fun createAutofillPendingIntent(
        usernameId: AutofillId?,
        passwordId: AutofillId?,
        requestingPackage: String,
        web: WebPage?,
    ): PendingIntent {
        val intent = Intent(this, AutofillActivity::class.java).apply {
            usernameId?.let { putExtra(AutofillActivity.EXTRA_LEGACY_USERNAME_ID, it) }
            passwordId?.let { putExtra(AutofillActivity.EXTRA_LEGACY_PASSWORD_ID, it) }
            putExtra(AutofillActivity.EXTRA_REQUESTING_PACKAGE, requestingPackage)
            putWebExtras(web)
        }
        return PendingIntent.getActivity(
            this,
            Random.nextInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    /**
     * Dominio (y esquema, Android 9+) de la página web que pide autofill,
     * tal como lo informan el navegador o el `WebView` (ADR 0020). Solo se
     * pasa a Dart, que es quien decide; el servicio no interpreta nada.
     */
    private data class WebPage(val domain: String, val scheme: String?)

    private fun Intent.putWebExtras(web: WebPage?) {
        if (web == null) return
        putExtra(AutofillActivity.EXTRA_WEB_DOMAIN, web.domain)
        web.scheme?.let { putExtra(AutofillActivity.EXTRA_WEB_SCHEME, it) }
    }

    private data class FoundFields(
        val usernameId: AutofillId?,
        val passwordId: AutofillId?,
        val web: WebPage?,
    )

    /**
     * Heurística en tres capas, en este orden: (1) `AutofillHints`
     * explícitos, (2) atributos HTML (`type`/`name`/`id` del `<input>`
     * — necesario para el WebView de Crunchyroll, donde no siempre hay
     * hints explícitos), (3) `inputType` como último recurso.
     */
    private fun findAutofillFields(structure: AssistStructure): FoundFields {
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null
        // El dominio más cercano al campo de contraseña: el del nodo web que
        // lo contiene (un WebView puede convivir con vistas nativas).
        var web: WebPage? = null
        var passwordWeb: WebPage? = null

        fun visit(node: AssistStructure.ViewNode, inheritedWeb: WebPage?) {
            val nodeDomain = node.webDomain
            val currentWeb = if (!nodeDomain.isNullOrBlank()) {
                WebPage(
                    domain = nodeDomain,
                    scheme = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        node.webScheme
                    } else {
                        null
                    },
                )
            } else {
                inheritedWeb
            }
            if (web == null && currentWeb != null) web = currentWeb
            val id = node.autofillId
            if (id != null) {
                // Hints no estándar en apps reales (confirmado en
                // verificación manual: SoundHound declara "passwordAuto",
                // no el "password" oficial de Android) — se matchea por
                // substring en vez de exigir el string exacto.
                val hints = node.autofillHints?.map { it.lowercase() }
                val isPasswordHint = hints?.any { it.contains("password") } == true
                val isUsernameHint =
                    hints?.any {
                        it.contains("username") || it.contains("email")
                    } == true

                val html = node.htmlInfo
                val htmlType = html?.attributes?.firstOrNull { it.first == "type" }?.second
                val htmlNameOrId = (
                    html?.attributes?.firstOrNull { it.first == "name" }?.second
                        ?: html?.attributes?.firstOrNull { it.first == "id" }?.second
                    )?.lowercase() ?: ""
                val isPasswordHtml = htmlType == "password"
                val isUsernameHtml = (htmlType == "email" || htmlType == "text") &&
                    (
                        htmlNameOrId.contains("user") ||
                            htmlNameOrId.contains("email") ||
                            htmlNameOrId.contains("login")
                        )

                // TYPE_TEXT_VARIATION_* no son banderas independientes —
                // son valores excluyentes entre sí dentro del sub-campo
                // de 4 bits TYPE_MASK_VARIATION. Bug real encontrado en
                // verificación manual: comparar con AND-distinto-de-cero
                // (en vez de aislar el sub-campo primero e igualar exacto)
                // daba falsos positivos cruzados entre password/email,
                // invirtiendo qué campo era cuál.
                val variation = node.inputType and InputType.TYPE_MASK_VARIATION
                val isPasswordInputType =
                    variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                        variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                val isUsernameInputType =
                    variation == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                        variation == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS

                if (passwordId == null && (isPasswordHint || isPasswordHtml || isPasswordInputType)) {
                    passwordId = id
                    passwordWeb = currentWeb
                } else if (usernameId == null && (isUsernameHint || isUsernameHtml || isUsernameInputType)) {
                    usernameId = id
                }
            }
            for (i in 0 until node.childCount) {
                visit(node.getChildAt(i), currentWeb)
            }
        }

        for (i in 0 until structure.windowNodeCount) {
            visit(structure.getWindowNodeAt(i).rootViewNode, null)
        }
        return FoundFields(usernameId, passwordId, passwordWeb ?: web)
    }

    private fun findTypedValue(structure: AssistStructure, target: AutofillId): String? {
        var result: String? = null

        fun visit(node: AssistStructure.ViewNode) {
            if (result != null) return
            if (node.autofillId == target) {
                result = node.autofillValue?.let { if (it.isText) it.textValue.toString() else null }
                return
            }
            for (i in 0 until node.childCount) {
                visit(node.getChildAt(i))
            }
        }

        for (i in 0 until structure.windowNodeCount) {
            visit(structure.getWindowNodeAt(i).rootViewNode)
        }
        return result
    }
}
