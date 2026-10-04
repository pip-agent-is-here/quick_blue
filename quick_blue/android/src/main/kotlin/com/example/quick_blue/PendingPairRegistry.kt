package com.example.quick_blue


/**
 * Tracks the pending pairing callbacks for the engine and fails them when a
 * device never reaches a terminal bond state.
 *
 * [scheduleTimeout] receives the timeout action for a registration; the
 * production wiring posts it on the main thread, and tests fire it directly so
 * the timeout path is deterministic. The action is only ever actuated while the
 * callback is still registered, so a completed or removed pairing ignores it.
 */
class PendingPairRegistry(
    private val scheduleTimeout: (() -> Unit) -> Unit,
) {
    private val pending = mutableMapOf<String, MutableList<(Result<Unit>) -> Unit>>()

    fun register(deviceAddress: String, callback: (Result<Unit>) -> Unit) {
        synchronized(this) {
            pending.getOrPut(deviceAddress) { mutableListOf() }.add(callback)
        }
        scheduleTimeout {
            failIfPending(
                deviceAddress,
                callback,
                "Timed out waiting for pairing with $deviceAddress",
            )
        }
    }

    fun remove(deviceAddress: String, callback: (Result<Unit>) -> Unit) {
        synchronized(this) {
            pending[deviceAddress]?.let { callbacks ->
                callbacks.remove(callback)
                if (callbacks.isEmpty()) {
                    pending.remove(deviceAddress)
                }
            }
        }
    }

    /** Completes every callback registered for [deviceAddress] with [result]. */
    fun complete(deviceAddress: String, result: Result<Unit>) {
        val callbacks = synchronized(this) {
            pending.remove(deviceAddress)?.toList() ?: emptyList()
        }
        callbacks.forEach { it(result) }
    }

    fun fail(deviceAddress: String, message: String) {
        complete(deviceAddress, Result.failure(FlutterError("BondFailed", message, null)))
    }

    /** Fails every still-registered callback, e.g. on engine detach. */
    fun failAll(messageFor: (deviceAddress: String) -> String) {
        val abandoned = synchronized(this) {
            val snapshot = pending.mapValues { it.value.toList() }
            pending.clear()
            snapshot
        }
        abandoned.forEach { (deviceAddress, callbacks) ->
            callbacks.forEach { it(Result.failure(FlutterError("BondFailed", messageFor(deviceAddress), null))) }
        }
    }

    private fun failIfPending(deviceAddress: String, callback: (Result<Unit>) -> Unit, message: String) {
        val stillPending = synchronized(this) {
            val callbacks = pending[deviceAddress]
            if (callbacks == null || !callbacks.remove(callback)) {
                false
            } else {
                if (callbacks.isEmpty()) {
                    pending.remove(deviceAddress)
                }
                true
            }
        }
        if (stillPending) {
            callback(Result.failure(FlutterError("BondFailed", message, null)))
        }
    }
}
