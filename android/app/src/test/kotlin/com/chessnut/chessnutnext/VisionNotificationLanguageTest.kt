package com.chessnut.chessnutnext

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class VisionNotificationLanguageTest {
    @Test
    fun explicitAppLanguageOverridesSystemLanguageForEverySupportedLocale() {
        val tags = listOf(
            "en", "zh-CN", "zh-Hant", "ja", "ko", "de", "fr", "ru", "pt",
            "es", "it", "nl", "pl", "ro", "cs", "ar", "he"
        )
        for (tag in tags) {
            assertEquals(tag, VisionNotificationLanguage.resolve(tag, Locale.JAPANESE).toLanguageTag())
        }
    }

    @Test
    fun followSystemUsesCurrentSystemLocaleAndFallsBackLikeTheApp() {
        assertEquals("fr", VisionNotificationLanguage.resolve("system", Locale.CANADA_FRENCH).toLanguageTag())
        assertEquals("de", VisionNotificationLanguage.resolve("system", Locale.GERMAN).toLanguageTag())
        assertEquals("en", VisionNotificationLanguage.resolve("system", Locale.forLanguageTag("sv-SE")).toLanguageTag())
    }

    @Test
    fun chineseVariantsMatchFlutterLanguageResolution() {
        for (tag in listOf("zh-Hant", "zh-TW", "zh-HK", "zh-MO")) {
            assertEquals("zh-Hant", VisionNotificationLanguage.resolve("system", Locale.forLanguageTag(tag)).toLanguageTag())
        }
        for (tag in listOf("zh", "zh-Hans", "zh-CN", "zh-SG")) {
            assertEquals("zh-CN", VisionNotificationLanguage.resolve("system", Locale.forLanguageTag(tag)).toLanguageTag())
        }
    }

    @Test
    fun explicitLanguageDoesNotChangeWhenSystemLanguageChanges() {
        assertEquals("es", VisionNotificationLanguage.resolve("es", Locale.ENGLISH).toLanguageTag())
        assertEquals("es", VisionNotificationLanguage.resolve("es", Locale.CHINESE).toLanguageTag())
    }
}
