// Govee characteristic and keep-alive behavior adapted from Govee-Sync.
// Copyright (c) 2025 Adil Rahmani. MIT license; see THIRD_PARTY_NOTICES.md.
@preconcurrency import CoreBluetooth
import Foundation
import GoveeKit
import OSLog

@MainActor
final class BluetoothService: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    var onDiscovery: ((String, String) -> Void)?
    var onConnection: ((String, Bool, String?) -> Void)?
    var onStatus: ((String) -> Void)?
    var onReply: ((String, Data, Bool) -> Void)?
    var onEncryptedSession: ((String) -> Void)?
    var onReconnecting: ((String) -> Void)?
    private let logger = Logger(subsystem: "community.goveemac.app", category: "Bluetooth")
    private var manager: CBCentralManager?
    private var wantsScan = false
    private var peripherals: [String: CBPeripheral] = [:]
    private var characteristics: [String: CBCharacteristic] = [:]
    private var connecting: Set<String> = []
    private var timeouts: [String: Task<Void, Never>] = [:]
    private var keepAlive: Task<Void, Never>?
    private var pending: [String: [Data]] = [:]
    private let controlID = CBUUID(string: BLEProtocol.controlCharacteristic)
    private let notifyID = CBUUID(string: BLEProtocol.notifyCharacteristic)
    private var subscribed: Set<String> = []
    private var sessions: [String: BLESessionCipher] = [:]
    private var authProbes: [String: Task<Void, Never>] = [:]
    private var ready: Set<String> = []
    private var reconnectIDs: [String] = []
    private let authCipher = try! BLESessionCipher(key: BLESessionCipher.authenticationKey)

    func scan() {
        wantsScan = true
        if manager == nil {
            manager = CBCentralManager(delegate: self, queue: nil)
        } else if manager?.state == .poweredOn { beginScan() }
        else { reportState() }
    }

    func stopScan() { wantsScan = false; manager?.stopScan() }

    func reconnect(ids: [String]) {
        reconnectIDs = ids
        guard !ids.isEmpty else { return }
        if manager == nil { manager = CBCentralManager(delegate: self, queue: nil) }
        else if manager?.state == .poweredOn { restoreConnections() }
    }

    private func restoreConnections() {
        let identifiers = reconnectIDs.compactMap(UUID.init(uuidString:))
        reconnectIDs = []
        for peripheral in manager?.retrievePeripherals(withIdentifiers: identifiers) ?? [] {
            let id = peripheral.identifier.uuidString
            peripherals[id] = peripheral
            onReconnecting?(id)
            connect(id: id)
        }
    }

    private func beginScan() {
        manager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        onStatus?("Looking for nearby Govee Bluetooth lights…")
    }

    func connect(id: String) {
        guard let peripheral = peripherals[id], manager?.state == .poweredOn else {
            onConnection?(id, false, "Scan for Bluetooth lights again, then connect."); return
        }
        guard !connecting.contains(id), characteristics[id] == nil else { return }
        connecting.insert(id)
        stopScan()
        logger.notice("Connecting to Bluetooth light")
        manager?.connect(peripheral)
        timeouts[id]?.cancel()
        timeouts[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled, let self, !self.ready.contains(id) else { return }
            self.fail(peripheral, message: "The light did not answer the control handshake. Close Govee Home, move closer, and retry. This model may use a different protocol.")
        }
    }

    func disconnect(id: String) {
        guard let peripheral = peripherals[id] else { return }
        cleanup(id)
        manager?.cancelPeripheralConnection(peripheral)
        onConnection?(id, false, nil)
    }

    func refresh(id: String) {
        guard ready.contains(id) else { return }
        for command: UInt8 in [0x01, 0x04, 0x05] { try? write(BLEProtocol.query(command), id: id) }
    }

    func send(_ command: LightCommand, to id: String) throws {
        // Newer RGBIC models use a percent scale. Values above 100 can disconnect them.
        let name = peripherals[id]?.name ?? ""
        let percent = sessions[id] != nil || name.contains("H6098") || name.contains("H6099")
        let extended = sessions[id] != nil && (name.contains("H6098") || name.contains("H6099"))
        guard let packet = BLEProtocol.encode(command, percentBrightness: percent, extendedColor: extended) else {
            throw ConnectionError.message("This command is not supported over Bluetooth.")
        }
        logger.notice("Sending Bluetooth command \(command.key, privacy: .public)")
        try write(packet, id: id)
    }

    private func write(_ packet: Data, id: String) throws {
        let wirePacket = try sessions[id]?.encrypt(packet) ?? packet
        try writeWire(wirePacket, id: id)
    }

    private func writeWire(_ packet: Data, id: String) throws {
        guard let peripheral = peripherals[id], peripheral.state == .connected,
              let characteristic = characteristics[id] else {
            throw ConnectionError.message("Connect to the Bluetooth light first.")
        }
        // Prefer write-without-response as used by Govee-Sync. Respect BLE backpressure.
        if characteristic.properties.contains(.writeWithoutResponse) {
            if peripheral.canSendWriteWithoutResponse {
                peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
            } else {
                guard (pending[id]?.count ?? 0) < 32 else { throw ConnectionError.message("The Bluetooth light is busy. Try again in a moment.") }
                pending[id, default: []].append(packet)
            }
        } else if characteristic.properties.contains(.write) {
            peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        } else { throw ConnectionError.message("The light’s control characteristic is not writable.") }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        guard let characteristic = characteristics[id] else { return }
        while peripheral.canSendWriteWithoutResponse, !(pending[id] ?? []).isEmpty {
            let data = pending[id]!.removeFirst()
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            restoreConnections()
            if wantsScan { beginScan() }
        }
        else {
            reportState()
            for id in Set(characteristics.keys).union(connecting) {
                cleanup(id); onConnection?(id, false, nil)
            }
        }
    }

    private func reportState() {
        switch manager?.state {
        case .poweredOff: onStatus?("Bluetooth is off. Turn it on in System Settings.")
        case .unauthorized: onStatus?("Allow Govee Mac in System Settings → Privacy & Security → Bluetooth.")
        case .unsupported: onStatus?("Bluetooth LE is unavailable on this Mac.")
        default: onStatus?("Waiting for Bluetooth…")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        let lower = name.lowercased()
        guard lower.contains("govee") || lower.contains("ihoment") || name.range(of: "H[0-9A-F]{4}", options: .regularExpression) != nil else { return }
        let id = peripheral.identifier.uuidString
        peripherals[id] = peripheral
        onDiscovery?(id, name)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.notice("Bluetooth link connected; discovering services")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Bluetooth connect failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        let id = peripheral.identifier.uuidString
        cleanup(id)
        onConnection?(id, false, error?.localizedDescription ?? "Could not connect to this light.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.notice("Bluetooth link disconnected: \(error?.localizedDescription ?? "requested by app", privacy: .public)")
        let id = peripheral.identifier.uuidString
        cleanup(id)
        onConnection?(id, false, error?.localizedDescription)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { fail(peripheral, message: error.localizedDescription); return }
        for service in peripheral.services ?? [] {
            logger.info("Bluetooth service \(service.uuid.uuidString, privacy: .public)")
            peripheral.discoverCharacteristics([controlID, notifyID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { fail(peripheral, message: error.localizedDescription); return }
        let id = peripheral.identifier.uuidString
        for char in service.characteristics ?? [] {
            logger.notice("Bluetooth characteristic \(char.uuid.uuidString, privacy: .public), properties \(char.properties.rawValue)")
            if char.uuid == notifyID && (char.properties.contains(.notify) || char.properties.contains(.indicate)) {
                peripheral.setNotifyValue(true, for: char)
            }
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == controlID }),
              characteristic.properties.contains(.writeWithoutResponse) || characteristic.properties.contains(.write) else { return }
        characteristics[id] = characteristic
        // Do not call a writable characteristic a working transport. Wait for a reply.
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let id = peripheral.identifier.uuidString
        if let error { logger.error("Bluetooth notification setup: \(error.localizedDescription, privacy: .public)"); return }
        logger.notice("Bluetooth notifications active: \(characteristic.isNotifying)")
        if characteristic.isNotifying {
            subscribed.insert(id)
            for command: UInt8 in [0x01, 0x04, 0x05] { try? write(BLEProtocol.query(command), id: id) }
            authProbes[id] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, !self.ready.contains(id) else { return }
                self.logger.notice("Plain status unanswered; trying legacy encrypted session negotiation")
                do {
                    let request = BLEProtocol.packet(head: 0xE7, command: 0x01, payload: [])!
                    try self.writeWire(self.authCipher.encrypt(request), id: id)
                } catch { self.logger.error("Session negotiation failed") }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { logger.error("Bluetooth reply failed: \(error.localizedDescription, privacy: .public)"); return }
        guard var data = characteristic.value else { return }
        // Only log framing and length; never device identity or session material.
        logger.debug("Bluetooth reply length \(data.count)")
        let id = peripheral.identifier.uuidString
        if sessions[id] == nil, data.count == 20, let handshake = try? authCipher.decrypt(data),
           handshake[0] == 0xE7, handshake[1] == 0x01, handshake.reduce(0, ^) == 0 {
            do {
                let cipher = try BLESessionCipher(key: Data(handshake[2..<18]))
                let finish = BLEProtocol.packet(head: 0xE7, command: 0x02, payload: [])!
                try writeWire(authCipher.encrypt(finish), id: id)
                sessions[id] = cipher
                onEncryptedSession?(id)
                logger.notice("Legacy encrypted Bluetooth session established")
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, self.sessions[id] != nil else { return }
                    for command: UInt8 in [0x01, 0x04, 0x05] { try? self.write(BLEProtocol.query(command), id: id) }
                }
            } catch { logger.error("Invalid encrypted session response") }
            return
        }
        if let cipher = sessions[id], data.count == 20 {
            guard let plaintext = try? cipher.decrypt(data), plaintext.reduce(0, ^) == 0 else { return }
            data = plaintext
        }
        if data.count >= 3, data[0] == 0xAA {
            logger.debug("Bluetooth state reply command \(data[1]), value/mode \(data[2])")
            if !ready.contains(id) {
                ready.insert(id)
                connecting.remove(id)
                timeouts.removeValue(forKey: id)?.cancel()
                authProbes.removeValue(forKey: id)?.cancel()
                onConnection?(id, true, nil)
                startKeepAlive()
            }
            let name = peripherals[id]?.name ?? ""
            onReply?(id, data, sessions[id] != nil || name.contains("H6098") || name.contains("H6099"))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { onConnection?(peripheral.identifier.uuidString, true, "Bluetooth write failed: \(error.localizedDescription)") }
    }

    private func startKeepAlive() {
        guard keepAlive == nil else { return }
        keepAlive = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                for id in self.ready { try? self.write(BLEProtocol.keepAlive, id: id) }
            }
        }
    }

    private func cleanup(_ id: String) {
        characteristics.removeValue(forKey: id)
        pending.removeValue(forKey: id)
        subscribed.remove(id)
        sessions.removeValue(forKey: id)
        ready.remove(id)
        authProbes.removeValue(forKey: id)?.cancel()
        connecting.remove(id)
        timeouts.removeValue(forKey: id)?.cancel()
        if characteristics.isEmpty { keepAlive?.cancel(); keepAlive = nil }
    }

    private func fail(_ peripheral: CBPeripheral, message: String) {
        let id = peripheral.identifier.uuidString
        cleanup(id)
        manager?.cancelPeripheralConnection(peripheral)
        onConnection?(id, false, message)
    }
}
