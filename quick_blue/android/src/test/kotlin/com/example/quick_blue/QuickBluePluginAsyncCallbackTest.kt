package com.example.quick_blue

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

/**
 * Guards the rule that Pigeon `@async` methods must always resolve their Dart
 * future, either by returning or by throwing (Pigeon 29+ catches `Throwable`
 * around the suspend call and replies with the wrapped error). A guard that
 * returns without completing — or that crashes the dispatcher — would leave the
 * Dart future pending forever.
 *
 * Both methods reach their guard clauses before any Android framework call on
 * an unsupported SDK level, so the failure paths are observable from a JVM unit
 * test.
 */
class QuickBluePluginAsyncCallbackTest {
    @Test
    fun `openL2cap fails on an unsupported SDK instead of hanging`() = runBlocking {
        val plugin = QuickBluePlugin()

        try {
            plugin.openL2cap("AA:BB:CC:DD:EE:FF", 0x1001L)
            fail("an unsupported SDK must fail openL2cap")
        } catch (expected: FlutterError) {
            assertEquals("UnsupportedAndroidVersion", expected.code)
        }
    }

    @Test
    fun `companionAssociate fails on an unsupported SDK instead of hanging`() = runBlocking {
        val plugin = QuickBluePlugin()

        try {
            plugin.companionAssociate(
                PlatformCompanionAssociationRequest(
                    filters = emptyList(),
                    singleDevice = true,
                ),
            )
            fail("an unsupported SDK must fail companionAssociate")
        } catch (expected: FlutterError) {
            assertEquals("UnsupportedAndroidVersion", expected.code)
        }
    }
}
