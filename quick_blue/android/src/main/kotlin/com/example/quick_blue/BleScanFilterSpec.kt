package com.example.quick_blue

/**
 * Platform-independent description of one BLE scan filter, shared by the
 * scanner and companion-association filter builders so the combination rules
 * (the cross product below) are written and tested once.
 */
data class BleScanFilterSpec(
    val serviceUuid: String?,
    val serviceDataUuid: String?,
    val serviceData: ByteArray?,
    val manufacturerId: Long?,
    val manufacturerData: ByteArray?,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BleScanFilterSpec) return false
        return serviceUuid == other.serviceUuid &&
            serviceDataUuid == other.serviceDataUuid &&
            serviceData.contentEquals(other.serviceData) &&
            manufacturerId == other.manufacturerId &&
            manufacturerData.contentEquals(other.manufacturerData)
    }

    override fun hashCode(): Int {
        var result = serviceUuid?.hashCode() ?: 0
        result = 31 * result + (serviceDataUuid?.hashCode() ?: 0)
        result = 31 * result + (serviceData?.contentHashCode() ?: 0)
        result = 31 * result + (manufacturerId?.hashCode() ?: 0)
        result = 31 * result + (manufacturerData?.contentHashCode() ?: 0)
        return result
    }
}

/**
 * Cross product of every provided filter entry. Every manufacturer-data entry
 * participates: a caller passing two entries must get two filters, not a
 * silently-dropped second entry.
 */
fun scanFilterSpecs(
    serviceUuids: List<String>?,
    serviceData: Map<String, ByteArray>?,
    manufacturerData: Map<Long, ByteArray>?,
): List<BleScanFilterSpec> {
    val serviceUuidOptions = serviceUuids.orEmpty().ifEmpty { listOf(null) }
    val serviceDataOptions: List<Pair<String, ByteArray>?> =
        serviceData.orEmpty().entries.map { it.key to it.value }.ifEmpty { listOf(null) }
    val manufacturerOptions: List<Pair<Long, ByteArray>?> =
        manufacturerData.orEmpty().entries.map { it.key to it.value }.ifEmpty { listOf(null) }

    return serviceUuidOptions.flatMap { serviceUuid ->
        serviceDataOptions.flatMap { entry ->
            manufacturerOptions.map { manufacturerEntry ->

                BleScanFilterSpec(
                    serviceUuid = serviceUuid,
                    serviceDataUuid = entry?.first,
                    serviceData = entry?.second,
                    manufacturerId = manufacturerEntry?.first,
                    manufacturerData = manufacturerEntry?.second,
                )
            }
        }
    }
}
