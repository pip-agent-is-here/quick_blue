package com.example.quick_blue

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingPairRegistryTest {
    private val scheduled: MutableList<() -> Unit> = mutableListOf()

    private fun registry(): PendingPairRegistry =
        PendingPairRegistry(scheduleTimeout = { action -> scheduled.add(action) })

    @Test
    fun `complete fails every callback for the device and forgets them`() {
        val registry = registry()
        val results = mutableListOf<Result<Unit>>()
        registry.register("AA:BB:CC:DD:EE:01") { results.add(it) }
        registry.register("AA:BB:CC:DD:EE:01") { results.add(it) }

        registry.complete(
            "AA:BB:CC:DD:EE:01",
            Result.success(Unit),
        )

        assertEquals(2, results.size)
        assertTrue(results.all { it.isSuccess })
        registry.complete("AA:BB:CC:DD:EE:01", Result.success(Unit))
        assertEquals("no callback runs twice", 2, results.size)
    }

    @Test
    fun `the timeout only fires while the callback is still pending`() {
        val registry = registry()
        val results = mutableListOf<Result<Unit>>()
        registry.register("AA:BB:CC:DD:EE:01") { results.add(it) }

        registry.complete(
            "AA:BB:CC:DD:EE:01",
            Result.success(Unit),
        )
        scheduled.forEach { it() }

        assertTrue(
            "a completed pairing must not be failed by its timeout",
            results.none { it.isFailure },
        )
    }

    @Test
    fun `a timeout fails the pending callback exactly once`() {
        val registry = registry()
        val results = mutableListOf<Result<Unit>>()
        registry.register("AA:BB:CC:DD:EE:01") { results.add(it) }

        scheduled.single().invoke()
        scheduled.single().invoke()

        assertEquals(1, results.size)
        assertTrue(results.single().isFailure)
        assertEquals("BondFailed", (results.single().exceptionOrNull() as FlutterError).code)

        // A later timeout for the same registration is a no-op.
        scheduled.last().invoke()
        assertEquals(1, results.size)
    }

    @Test
    fun `remove stops the timeout from failing the callback`() {
        val registry = registry()
        val results = mutableListOf<Result<Unit>>()
        val callback: (Result<Unit>) -> Unit = { results.add(it) }
        registry.register("AA:BB:CC:DD:EE:01", callback)

        registry.remove("AA:BB:CC:DD:EE:01", callback)
        scheduled.forEach { it() }

        assertTrue(results.isEmpty())
    }

    @Test
    fun `failAll fails every device on engine detach`() {
        val registry = registry()
        val a = mutableListOf<Result<Unit>>()
        val b = mutableListOf<Result<Unit>>()
        registry.register("AA:BB:CC:DD:EE:01") { a.add(it) }
        registry.register("AA:BB:CC:DD:EE:02") { b.add(it) }
        val pending = scheduled.toList()

        registry.failAll { device -> "Engine detached while pairing $device" }
        pending.forEach { it() }

        assertTrue(a.single().isFailure)
        assertTrue(b.single().isFailure)
        assertEquals(
            "Engine detached while pairing AA:BB:CC:DD:EE:01",
            (a.single().exceptionOrNull() as FlutterError).message,
        )
        // A stale timeout after failAll is a no-op.
        assertEquals(2, a.size + b.size)
    }

    @Test
    fun `each device times out independently`() {
        val registry = registry()
        val a = mutableListOf<Result<Unit>>()
        val b = mutableListOf<Result<Unit>>()
        registry.register("AA:BB:CC:DD:EE:01") { a.add(it) }
        registry.register("AA:BB:CC:DD:EE:02") { b.add(it) }

        scheduled.first().invoke()

        assertTrue(a.single().isFailure)
        assertTrue(b.isEmpty())
    }
}
