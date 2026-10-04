package com.example.quick_blue

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression coverage for the L2CAP connection lifecycle.
 *
 * A connection attempt that fails — or a socket closed before it ever connects —
 * must settle the pending `openL2cap` call instead of leaving the Dart future
 * pending forever, and the terminal callbacks (error/closed) must fire at most
 * once, with an explicit closure never surfacing as an error.
 */
class L2CapStreamDelegateTest {

    private class FakeL2CapSocket(
        private val connectFailure: IOException? = null,
        private val input: InputStream = ByteArrayInputStream(ByteArray(0)),
    ) : L2CapSocket {
        override fun connect() {
            connectFailure?.let { throw it }
        }

        override fun close() {}

        override val inputStream: InputStream get() = input
        override val outputStream: OutputStream get() = ByteArrayOutputStream()
    }

    @Test
    fun `a failing connect fails the pending open`() {
        val opened = CountDownLatch(1)
        val terminal = CountDownLatch(1)
        val openResults = mutableListOf<Result<Unit>>()
        val errors = mutableListOf<Exception>()
        var closedCount = 0

        L2CapStreamDelegate(
            socket = FakeL2CapSocket(connectFailure = IOException("PSM rejected")),
            onOpenSettled = {
                openResults += it
                opened.countDown()
            },
            closedCallback = {
                closedCount++
                terminal.countDown()
            },
            streamCallback = {},
            errorCallback = { errors += it },
            ioDispatcher = Dispatchers.Unconfined,
            callbackDispatcher = Dispatchers.Unconfined,
        )

        assertTrue("the pending open must settle", opened.await(5, TimeUnit.SECONDS))
        assertTrue("the socket must report closed", terminal.await(5, TimeUnit.SECONDS))
        assertEquals(1, openResults.size)
        assertTrue(
            "a failed connection must fail the open",
            openResults.single().isFailure,
        )
        assertEquals(1, errors.size)
        assertEquals(1, closedCount)
    }

    @Test
    fun `closing while connecting fails the open without a spurious error`() {
        val connecting = CountDownLatch(1)
        val opened = CountDownLatch(1)
        val terminal = CountDownLatch(1)
        val openResults = mutableListOf<Result<Unit>>()
        val errors = mutableListOf<Exception>()
        var closedCount = 0

        val callbackExecutor = Executors.newSingleThreadExecutor()
        try {
            val socket = object : L2CapSocket {
                override fun connect() {
                    // Blocks until close() interrupts the connection attempt, exactly
                    // like BluetoothSocket.connect() when the socket is closed.
                    connecting.await()
                    throw IOException("socket closed")
                }

                override fun close() {
                    connecting.countDown()
                }

                override val inputStream: InputStream
                    get() = ByteArrayInputStream(ByteArray(0))
                override val outputStream: OutputStream
                    get() = ByteArrayOutputStream()
            }

            val delegate = L2CapStreamDelegate(
                socket = socket,
                onOpenSettled = {
                    openResults += it
                    opened.countDown()
                },
                closedCallback = {
                    closedCount++
                    terminal.countDown()
                },
                streamCallback = {},
                errorCallback = { errors += it },
                ioDispatcher = Dispatchers.IO,
                callbackDispatcher = callbackExecutor.asCoroutineDispatcher(),
            )

            delegate.close()

            assertTrue("the socket must report closed", terminal.await(5, TimeUnit.SECONDS))
            assertTrue("the pending open must settle", opened.await(5, TimeUnit.SECONDS))
            assertEquals(1, openResults.size)
            assertTrue(
                "a close during connect must fail the open",
                openResults.single().isFailure,
            )
            assertEquals(1, closedCount)
            assertTrue(
                "an explicit close must not surface as an error: $errors",
                errors.isEmpty(),
            )
        } finally {
            callbackExecutor.shutdownNow()
        }
    }

    @Test
    fun `a failure after the open reports error then closed exactly once`() {
        val opened = CountDownLatch(1)
        val terminal = CountDownLatch(1)
        val openResults = mutableListOf<Result<Unit>>()
        val errors = mutableListOf<Exception>()
        var closedCount = 0

        val socket = object : L2CapSocket {
            override fun connect() {}

            override fun close() {}

            override val inputStream: InputStream
                get() = object : InputStream() {
                    override fun read(): Int = throw IllegalStateException("read failed")
                }
            override val outputStream: OutputStream
                get() = ByteArrayOutputStream()
        }

        val delegate = L2CapStreamDelegate(
            socket = socket,
            onOpenSettled = {
                openResults += it
                opened.countDown()
            },
            closedCallback = {
                closedCount++
                terminal.countDown()
            },
            streamCallback = {},
            errorCallback = { errors += it },
            ioDispatcher = Dispatchers.Unconfined,
            callbackDispatcher = Dispatchers.Unconfined,
        )

        assertTrue("the open must settle", opened.await(5, TimeUnit.SECONDS))
        assertTrue("the socket must report closed", terminal.await(5, TimeUnit.SECONDS))
        assertTrue("a successful connect must open the socket", openResults.single().isSuccess)
        assertEquals(1, errors.size)
        assertEquals(1, closedCount)

        // A later close must not emit a second terminal event.
        delegate.close()
        assertEquals(1, errors.size)
        assertEquals(1, closedCount)
    }
}
