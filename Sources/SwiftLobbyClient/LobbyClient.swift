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
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    var url: URL
    var delegate: LobbyClientDelegate
    var shouldReconnect = true
    
    public var players = [PlayerInfo]()
    public var ourPlayerNum: Int?
    public var lobbyCode: String?
    public var lobbyProperties = [String : String]()
    public var lists = [String : [[String : String]]]()
    
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
                        if case .lobbyNotFound = message {
                            self.shouldReconnect = false
                        }
                        DispatchQueue.main.async {
                            self.processMessage(message)
                            self.delegate.lobbyDidReceiveMessage(lobbyClient: self, message: message)
                        }
                    }
                default:
                    fatalError()
                }
            }
            
            switch self.connectionStatus {
            case .connected:
                fallthrough
            case .connecting:
                fallthrough
            case .reconnecting:
                self.receiveMessage()
            default:
                print("Not listening, not connected")
            }
        }
    }
    
    /**
     Update lobby state if required for this message.
     */
    private func processMessage(_ message: OutgoingPlayerMessage) {
        // Keeping the empty cases (not using `default`) so the switch has to be
        // exhaustive, we don't want to miss any new properties.
        switch message {
        case .hello(let lobbyCode, let playerNum, let players, let lobbyProperties, let lists):
            self.lobbyCode = lobbyCode
            self.ourPlayerNum = playerNum
            self.players = players
            self.lobbyProperties = lobbyProperties
            self.lists = lists
        case .playerPropertiesUpdated(let playerNum, let properties):
            if let playerIndex = self.players.firstIndex(where: { $0.playerNum == playerNum }) {
                self.players[playerIndex].properties = properties
            }
        case .addToList(let name, let value):
            lists[name]?.append(value)
        case .playerChangedName(let playerNum, let newName):
            if let playerIndex = self.players.firstIndex(where: { $0.playerNum == playerNum }) {
                self.players[playerIndex].name = newName
            }
        case .playerDeparted(let playerNum):
            self.players = self.players.filter { $0.playerNum != playerNum}
        case .resetList(let listName):
            lists[listName] = [[String:String]]()
        case .broadcast(data: _):
            break
        case .directSay(text: _, date: _, fromPlayerNum: _):
            break
        case .error(message: _):
            break
        case .lobbyNotFound:
            break
        case .playerJoined(player: let player):
            self.players.append(player)
        case .lobbyPropertiesUpdated(properties: let properties):
            var props = self.lobbyProperties
            for (key, value) in properties {
                props[key] = value
            }
            self.lobbyProperties = props
        case .lobbyOwnerChanged(playerNum: _):
            break
        case .pong:
            break
        case .say(text: _, date: _, fromPlayerNum: _):
            break
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
