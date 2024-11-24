import CoreLocation
import Foundation
import Logging
import NIOCore
import NIOPosix

struct SimData: Sendable {
    static var empty: Self {
        .init(simName: "",
              latitudeDeg: 0,
              longitudeDeg: 0,
              altitudeMSL_m: 0,
              trackTrueDeg: 0,
              groundSpeedMps: 0,
              date: Date(timeIntervalSinceReferenceDate: 0))
    }

    let simName: String
    let latitudeDeg: Double
    let longitudeDeg: Double
    let altitudeMSL_m: Double
    let trackTrueDeg: Double
    let groundSpeedMps: Double
    let date: Date

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitudeDeg, longitude: longitudeDeg)
    }

    var trackTrue: Bearing {
        .init(angle: trackTrueDeg, reference: .true)
    }

    var groundspeed: Measurement<UnitSpeed> {
        .init(value: groundSpeedMps, unit: .metersPerSecond)
    }

    var altitudeMSL: Measurement<UnitLength> {
        .init(value: altitudeMSL_m, unit: .meters)
    }

    var location: CLLocation {
        .init(coordinate: coordinate,
              altitude: altitudeMSL_m,
              horizontalAccuracy: 1.0,
              verticalAccuracy: 1.0,
              course: trackTrueDeg,
              speed: groundSpeedMps,
              timestamp: Date())
    }

    init(simName: String, latitudeDeg: Double, longitudeDeg: Double, altitudeMSL_m: Double, trackTrueDeg: Double, groundSpeedMps: Double, date: Date = .init()) {
        self.simName = simName
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.altitudeMSL_m = altitudeMSL_m
        self.trackTrueDeg = trackTrueDeg
        self.groundSpeedMps = groundSpeedMps
        self.date = date
    }
}

final actor SimReceiver {
    private static let logger = Logger(label: "codes.tim.IP-Inbound.SimReceiver")

    private let port: Int
    private var group: EventLoopGroup?
    private var channel: Channel?

    private let continuation: AsyncStream<SimData>.Continuation
    let stream: AsyncStream<SimData>

    init(port: Int = 49002) {
        self.port = port

        var continuation: AsyncStream<SimData>.Continuation!
        stream = AsyncStream { c in continuation = c }
        self.continuation = continuation
    }

    func start() async {
        // Check if we need to cleanup first
        if channel != nil || group != nil {
            await stop()
        }

        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let bootstrap = DatagramBootstrap(group: group!)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.recvAllocator, value: FixedSizeRecvByteBufferAllocator(capacity: 2048))
            .channelInitializer { channel in
                channel.pipeline
                    .addHandler(SimHandler(continuation: self.continuation))
            }
        do {
            channel = try await bootstrap.bind(host: "0.0.0.0", port: port).get()
            Self.logger.info("UDP server started", metadata: [
                "port": "\(port)"
            ])
        } catch let error as IOError where error.errnoCode == 48 {
            Self.logger.warning("Port already in use. Simulator data will not be available.", metadata: [
                "port": "\(port)"
            ])
            // Cleanup resources
            try? await group?.shutdownGracefully()
            group = nil
        } catch {
            Self.logger.error("Error starting UDP server", metadata: [
                "error": "\(error)"
            ])
            // Cleanup resources
            try? await group?.shutdownGracefully()
            group = nil
        }
    }

    func stop() async {
        // Capture current resources before setting to nil
        let currentChannel = channel
        let currentGroup = group

        // Clear references immediately
        channel = nil
        group = nil

        do {
            if let currentChannel {
                try await currentChannel.close()
            }

            if let currentGroup {
                try await currentGroup.shutdownGracefully()
            }
            Self.logger.info("UDP server stopped")
        } catch {
            Self.logger.error("Error stopping UDP server", metadata: [
                "error": "\(error)"
            ])
        }

        // Don't finish the continuation - we want to keep the stream alive
        // but just not yield any data when there's no connection
    }
}

private final class SimHandler: Sendable, ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>

    private static let logger = Logger(label: "codes.tim.IP-Inbound.SimHandler")

    private let continuation: AsyncStream<SimData>.Continuation

    init(continuation: AsyncStream<SimData>.Continuation) {
        self.continuation = continuation
    }

    func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data
        if let string = buffer.readString(length: buffer.readableBytes) {
            handle(data: string)
        }
    }

    private func handle(data: String) {
        guard data.hasPrefix("XGPS") else { return }

        let payload = data.dropFirst(4),
            fields = payload.split(
                separator: ",",
                omittingEmptySubsequences: false
            )
        guard fields.count == 6 else {
            Self.logger.info("Ignoring UDP message: fields.count != 6", metadata: [
                "fields.count": "\(fields.count)"
            ])
            return
        }

        guard let longitude = Double(fields[1]) else {
            Self.logger.info("Ignoring UDP message: Invalid longitude (field 1)", metadata: [
                "fields[1]": "\(fields[1])"
            ])
            return
        }
        guard let latitude = Double(fields[2]) else {
            Self.logger.info("Ignoring UDP message: Invalid latitude (field 2)", metadata: [
                             "fields[2]": "\(fields[2])"
            ])
            return
        }
        guard let altitude = Double(fields[3]) else {
            Self.logger.info("Ignoring UDP message: Invalid altitude (field 3)", metadata: [
                "fields[3]": "\(fields[3])"
            ])
            return
        }
        guard let track = Double(fields[4]) else {
            Self.logger.info("Ignoring UDP message: Invalid track (field 4)", metadata: [
                "fields[4]": "\(fields[4])"
            ])
            return
        }
        guard let groundspeed = Double(fields[5]) else {
            Self.logger.info("Ignoring UDP message: Invalid groundspeed (field 5)", metadata: [
                "fields[5]": "\(fields[5])"
            ])
            return
        }

        let data = SimData(
            simName: String(fields[0]),
            latitudeDeg: latitude,
            longitudeDeg: longitude,
            altitudeMSL_m: altitude,
            trackTrueDeg: track,
            groundSpeedMps: groundspeed
        )
        continuation.yield(data)
    }
}
