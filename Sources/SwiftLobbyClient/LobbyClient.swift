//
//  LobbyClient.swift
//
//  Created by Steve Tibbett on 2022-06-26.
//

import Foundation
import Combine

public enum LobbyConnectionStatus {
    case notConnected
    case connecting
    case connected
    case failed(localizedMessage: String?)
    case reconnecting
}

public protocol LobbyClientDelegate {
    func lobbyDidReceiveMessage(lobbyClient: LobbyClient, message: OutgoingPlayerMessage)
    func lobbyDidDisconnect(lobbyClient: LobbyClient)
    func lobbyStatusDidChange(lobbyClient: LobbyClient, status: LobbyConnectionStatus)
}

public class LobbyClient: NSObject, URLSessionWebSocketDelegate {
    
    public var connectionStatus = LobbyConnectionStatus.notConnected {
        didSet {
            let status = self.connectionStatus
            DispatchQueue.main.async {
                self.delegate.lobbyStatusDidChange(lobbyClient: self, status: status)
            }
        }
    }
    
    var webSocketTask: URLSessionWebSocketTask?
    var url: URL
    var delegate: LobbyClientDelegate
    
    public init(server: URL, lobbyCode: String? = nil, delegate: LobbyClientDelegate) {
        var url = server.appendingPathComponent("ws")
        if let lobbyCode = lobbyCode {
            url = url.appendingPathComponent(lobbyCode)
        }
        
        self.delegate = delegate
        self.url = url

        super.init()

        connect()
    }
    
    public func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
    }
    
    public func disconnect() {
        webSocketTask?.cancel()
    }
    
    func receiveMessage() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        webSocketTask?.receive { result in
            switch result {
            case .failure(let error):
                self.connectionStatus = .failed(localizedMessage: error.localizedDescription)
            case .success(let message):
                switch message {
                case .string(let string):
                    if let data = string.data(using: .utf8),
                        let message = try? decoder.decode(OutgoingPlayerMessage.self, from: data) {
                        DispatchQueue.main.async {
                            self.delegate.lobbyDidReceiveMessage(lobbyClient: self, message: message)
                        }
                    }
                default:
                    fatalError()
                }
            }
            self.receiveMessage()
        }
    }
    
    // MARK: WebSocket Delegate
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.webSocketTask = webSocketTask
        self.connectionStatus = .connected
        self.receiveMessage()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.connectionStatus = .notConnected
        DispatchQueue.main.async {
            self.delegate.lobbyDidDisconnect(lobbyClient: self)
        }
    }

    
    public func send(_ message: IncomingPlayerMessage) async {
        do {
            let data = try! JSONEncoder().encode(message)
            try await webSocketTask?.send(.string(String(data: data, encoding: .utf8)!))
        } catch {
            disconnect()
            delegate.lobbyStatusDidChange(lobbyClient: self, status: .failed(localizedMessage: error.localizedDescription))
        }
    }
}
