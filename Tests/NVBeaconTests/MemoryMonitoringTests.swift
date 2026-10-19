import Foundation
import Testing
@testable import NVBeacon

@Test func memorySectionDoesNotContaminateGPUOrProcessParsing() throws {
    let output = """
    0, NVIDIA Test GPU, GPU-111, 50, 24576, 32768, 60
    __GPUUSAGE_PROCESS_SECTION__
    GPU-111, 1001, 501, python, 24576
    __NVBEACON_MEMORY_SECTION__
    MemTotal:       67108864 kB
    MemFree:          524288 kB
    MemAvailable:   16777216 kB
    Cached:         12582912 kB
    SwapTotal:       8388608 kB
    SwapFree:        6291456 kB
    __GPUUSAGE_PS_SECTION__
    1001 alice python train.py
    """

    let gpus = try SSHMetricsFetcher.parseSnapshot(output)
    let memory = try #require(SSHMetricsFetcher.parseHostMemory(output))
    #expect(gpus.count == 1)
    #expect(gpus[0].processes.first?.user == "alice")
    #expect(memory.usedKiB == 50331648)
    #expect(memory.availableKiB == 16777216)
    #expect(memory.usagePercent == 75)
    #expect(memory.usageRatio == 0.75)
    #expect(memory.swapUsedKiB == 2097152)
    #expect(memory.swapUsageRatio == 0.25)
    #expect(HostMemoryReading.capacityText(kibibytes: memory.totalKiB) == "64.0 GiB")
}

@Test(arguments: [
    "",
    "MemTotal: 100 kB\nMemFree: 20 kB",
    "MemTotal: 0 kB\nMemAvailable: 0 kB",
    "MemTotal: 100 kB\nMemAvailable: 101 kB",
    "MemTotal: 100 kB\nMemAvailable: -1 kB",
    "MemTotal: 100 kB\nMemAvailable: unknown kB",
    "MemTotal: 100 MB\nMemAvailable: 50 MB",
    "MemTotal: 100 kB\nMemAvailable: 50 kB\nMemAvailable: 30 kB"
]) func unavailableMemoryDoesNotInterruptGPUMonitoring(_ meminfo: String) throws {
    let output = """
    0, NVIDIA Test GPU, GPU-111, 50, 24576, 32768, 60
    __GPUUSAGE_PROCESS_SECTION__
    __NVBEACON_MEMORY_SECTION__
    \(meminfo)
    """
    #expect(SSHMetricsFetcher.parseHostMemory(output) == nil)
    #expect(try SSHMetricsFetcher.parseSnapshot(output).count == 1)
}

@Test func oldSnapshotWithoutMemorySectionStillParses() throws {
    let output = "0, NVIDIA Test GPU, GPU-111, 50, 24576, 32768, 60"
    #expect(SSHMetricsFetcher.parseHostMemory(output) == nil)
    #expect(try SSHMetricsFetcher.parseSnapshot(output).count == 1)
}

@Test(arguments: [
    ("SwapTotal: 0 kB\nSwapFree: 0 kB", Optional(0)),
    ("SwapTotal: 100 kB\nSwapFree: 0 kB", Optional(100)),
    ("SwapTotal: 100 kB\nSwapFree: 101 kB", nil),
    ("SwapTotal: 100 kB\nSwapFree: -1 kB", nil),
    ("SwapTotal: 100 kB\nSwapFree: unknown kB", nil),
    ("SwapTotal: 100 kB", nil),
    ("", nil)
]) func swapHandlesDisabledFullAndUnavailableData(_ swap: String, _ expectedUsed: Int?) throws {
    let output = """
    __NVBEACON_MEMORY_SECTION__
    MemTotal: 1000 kB
    MemAvailable: 200 kB
    \(swap)
    """
    let memory = try #require(SSHMetricsFetcher.parseHostMemory(output))
    #expect(memory.swapUsedKiB == expectedUsed)
    #expect(memory.usagePercent == 80)
    if expectedUsed == 0 {
        #expect(memory.swapUsageRatio == 0)
    }
}
