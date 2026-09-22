package com.chessnut.chessnutnext

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** A resource context for Vision only; does not change the device language. */
internal object VisionNotificationLanguage {
    private const val PREFS = "chessnut_vision_notification"
    private const val LANGUAGE_KEY = "app_language"
    private val supportedLanguages = setOf(
        "en", "ja", "ko", "de", "fr", "ru", "pt", "es", "it", "nl",
        "pl", "ro", "cs", "ar", "he", "iw"
    )

    fun setPreference(context: Context, languageTag: String) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (preferences.getString(LANGUAGE_KEY, "system") != languageTag) {
            preferences.edit().putString(LANGUAGE_KEY, languageTag).apply()
        }
    }

    fun localizedContext(context: Context): Context {
        val tag = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(LANGUAGE_KEY, "system") ?: "system"
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(resolve(tag, Locale.getDefault()))
        }
        return context.createConfigurationContext(configuration)
    }

    /** Mirrors AppLanguagePreference's supported languages and Chinese variants. */
    fun resolve(preference: String, systemLocale: Locale): Locale {
        val candidate = if (preference == "system") systemLocale else Locale.forLanguageTag(preference)
        if (candidate.language == "zh") {
            val traditional = candidate.script == "Hant" || candidate.country in setOf("TW", "HK", "MO")
            return Locale.forLanguageTag(if (traditional) "zh-Hant" else "zh-CN")
        }
        if (candidate.language in supportedLanguages) {
            return Locale.forLanguageTag(if (candidate.language == "iw") "he" else candidate.language)
        }
        return Locale.ENGLISH
    }
}
