//
//  OTLPServer.swift
//  Droppy
//
//  Simple HTTP server for receiving OTLP telemetry from coding agents
//

import Foundation
import Network

/// HTTP server that receives OTLP telemetry data on configurable port
class OTLPServer {

    // MARK: - Types

    typealias TelemetryHandler = (Data, String) -> Void

    // MARK: - Properties

    private let port: UInt16
    private let handler: TelemetryHandler
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.droppy.otlp", qos: .userInitiated)

    // MARK: - Init

    init(port: UInt16, handler: @escaping TelemetryHandler) {
        self.port = port
        self.handler = handler
    }

    deinit {
        stop()
    }

    // MARK: - Server Control

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                print("OTLPServer: Invalid port \(port)")
                return
            }

            listener = try NWListener(using: parameters, on: nwPort)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("OTLPServer: Listening on port \(self?.port ?? 0)")
                case .failed(let error):
                    print("OTLPServer: Failed - \(error)")
                    self?.listener?.cancel()
                case .cancelled:
                    print("OTLPServer: Cancelled")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)

        } catch {
            print("OTLPServer: Failed to start - \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveData(from: connection)
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }

            if let data = data, !data.isEmpty {
                let (path, body) = self.parseHTTPRequest(data)
                let bodyText = String(data: body, encoding: .utf8) ?? "nil"

                // Debug: write to file
                let debugMsg = "[\(Date())] Received \(data.count) bytes, path=\(path), body=\(bodyText.prefix(200))\n"
                if let debugData = debugMsg.data(using: .utf8) {
                    let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("droppy_otlp_debug.txt")
                    if FileManager.default.fileExists(atPath: debugFile.path) {
                        if let handle = try? FileHandle(forWritingTo: debugFile) {
                            handle.seekToEndOfFile()
                            handle.write(debugData)
                            handle.closeFile()
                        }
                    } else {
                        try? debugData.write(to: debugFile)
                    }
                }

                // Call handler with telemetry data
                self.handler(body, path)

                // Send HTTP 200 OK response
                self.sendResponse(to: connection)
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                // Continue receiving for keep-alive connections
                self.receiveData(from: connection)
            }
        }
    }

    // MARK: - HTTP Parsing

    private func parseHTTPRequest(_ data: Data) -> (path: String, body: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            return ("", Data())
        }

        // Parse first line for HTTP method and path
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return ("", Data())
        }

        // Extract path: "POST /v1/logs HTTP/1.1" -> "/v1/logs"
        let parts = requestLine.split(separator: " ")
        let path = parts.count > 1 ? String(parts[1]) : ""

        // Find body after header delimiter
        if let headerEnd = text.range(of: "\r\n\r\n") {
            let bodyString = String(text[headerEnd.upperBound...])
            return (path, bodyString.data(using: .utf8) ?? Data())
        }

        return (path, Data())
    }

    // MARK: - HTTP Response

    private func sendResponse(to connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Length: 0\r
        Connection: close\r
        \r

        """

        guard let responseData = response.data(using: .utf8) else {
            connection.cancel()
            return
        }

        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("OTLPServer: Send error - \(error)")
            }
            connection.cancel()
        })
    }
}
