package com.example.quick_blue

import PlatformCompanionAssociation
import PlatformCompanionAssociationRequest
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the rule that Pigeon `@async` methods must always complete their
 * callback. Throwing instead escapes the generated message handler, which never
 * sends a reply, leaving the Dart future pending forever.
 *
 * Both methods reach their guard clauses before any Android framework call on an
 * unsupported SDK level, so the callbacks are observable from a JVM unit test.
 */
class QuickBluePluginAsyncCallbackTest {
    @Test
    fun `openL2cap completes its callback on an unsupported SDK instead of throwing`() {
        val plugin = QuickBluePlugin()
        var result: Result<Unit>? = null

        plugin.openL2cap("AA:BB:CC:DD:EE:FF", 0x1001L) { result = it }

        assertNotNull("openL2cap must complete its callback", result)
        assertTrue(
            "an unsupported SDK must fail the callback",
            result!!.exceptionOrNull() != null,
        )
    }

    @Test
    fun `companionAssociate completes its callback on an unsupported SDK instead of throwing`() {
        val plugin = QuickBluePlugin()
        var result: Result<PlatformCompanionAssociation?>? = null

        plugin.companionAssociate(
            PlatformCompanionAssociationRequest(
                filters = emptyList(),
                singleDevice = true,
            ),
        ) { result = it }

        assertNotNull("companionAssociate must complete its callback", result)
        assertTrue(
            "an unsupported SDK must fail the callback",
            result!!.exceptionOrNull() != null,
        )
    }
}
