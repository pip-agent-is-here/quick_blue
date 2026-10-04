package com.example.quick_blue

import org.junit.Assert.assertEquals
import org.junit.Test

class BleScanFilterSpecTest {
    @Test
    fun `no filters produce a single null spec`() {
        assertEquals(
            listOf(BleScanFilterSpec(null, null, null, null, null)),
            scanFilterSpecs(null, null, null),
        )
    }

    @Test
    fun `empty collections behave like no filters`() {
        assertEquals(
            scanFilterSpecs(null, null, null),
            scanFilterSpecs(emptyList(), emptyMap(), emptyMap()),
        )
    }

    @Test
    fun `entries combine as a cross product`() {
        val specs = scanFilterSpecs(
            serviceUuids = listOf("180d", "180f"),
            serviceData = mapOf("180a" to byteArrayOf(1)),
            manufacturerData = mapOf(0x0059L to byteArrayOf(2)),
        )

        assertEquals(2, specs.size)
        assertEquals(
            setOf("180d", "180f"),
            specs.map { it.serviceUuid }.toSet(),
        )
        specs.forEach {
            assertEquals("180a", it.serviceDataUuid)
            assertEquals(0x0059L, it.manufacturerId)
        }
    }

    @Test
    fun `every manufacturer entry participates instead of silently dropping the rest`() {
        val specs = scanFilterSpecs(
            serviceUuids = null,
            serviceData = null,
            manufacturerData = mapOf(
                0x004CL to byteArrayOf(1),
                0x0075L to byteArrayOf(2),
            ),
        )

        assertEquals(
            "both manufacturer filters must be applied",
            setOf(0x004CL, 0x0075L),
            specs.map { it.manufacturerId }.toSet(),
        )
    }

    @Test
    fun `multiple service data entries produce one spec per uuid`() {
        val specs = scanFilterSpecs(
            serviceUuids = null,
            serviceData = mapOf(
                "180a" to byteArrayOf(1),
                "180b" to byteArrayOf(2, 3),
            ),
            manufacturerData = null,
        )

        assertEquals(2, specs.size)
    }
}
