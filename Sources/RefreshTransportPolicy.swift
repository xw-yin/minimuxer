import Foundation
public import MinimuxerCommon

public enum RefreshTransport: String, Sendable {
    case coreDevice = "COREDEVICE_LOCALDEVVPN"
    case lockdownIPSec = "LOCKDOWN_IPSEC"
    case lockdownLegacy = "LOCKDOWN_LEGACY"
    case remotePairing = "REMOTE_PAIRING"
    case proxy = "UPSTREAM_PROXY"
    case unavailable = "FAILED_NO_VALID_TRANSPORT"
}

public struct RefreshTransportDecision: Sendable {
    public let transport: RefreshTransport
    public let reason: String
}

public enum RefreshTransportPolicy {
    public static func select(modernOS: Bool, mode: DeviceConnectionMode,
                              pairing: PairingProtocol, utun: Bool, ipsec: Bool,
                              coreDeviceSupported: Bool) -> RefreshTransportDecision {
        if pairing == .unknown {
            return .init(transport: .unavailable, reason: "No valid pairing record")
        }
        if mode == .remoteServer {
            return .init(transport: .proxy, reason: "Explicit upstream remote-server configuration")
        }
        guard mode == .localVPN, utun else {
            return .init(transport: .unavailable, reason: "Local VPN requires a reachable utun route; IPSec alone is not an upstream local-VPN route")
        }
        if modernOS {
            guard pairing == .rppairing else {
                return .init(transport: .unavailable, reason: "iOS 17.0+ requires Remote Pairing (rppairing); Lockdown is not supported on iOS 17+")
            }
            return .init(transport: .remotePairing, reason: "RemotePairing over local VPN")
        } else {
            guard pairing == .lockdown else {
                return .init(transport: .unavailable, reason: "iOS < 17 requires Lockdown pairing; Remote Pairing is only supported on iOS 17+")
            }
            return .init(transport: .lockdownLegacy, reason: "Standard Lockdown over local VPN")
        }
    }
}
