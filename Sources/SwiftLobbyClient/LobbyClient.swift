//
//  LobbyClient.swift
//
//  Created by Steve Tibbett on 2022-06-26.
//

import Foundation

class LobbyClient: NSObject, URLSessionWebSocketDelegate {
    var webSocketTask: URLSessionWebSocketTask?
    var url: URL
    
    init(server: URL, lobbyCode: String? = nil) {
        
        var url = server.appendingPathComponent("ws")
        if let lobbyCode = lobbyCode {
            url = url.appendingPathComponent(lobbyCode)
        }
        
        self.url = url

        super.init()

        connect()
    }
    
    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        let webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
    }
    
    // MARK: WebSocket Delegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Web Socket did connect")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Web Socket did disconnect")
    }

    func send(_ message: IncomingPlayerMessage) async {
        let data = try! JSONEncoder().encode(message)
        let str = String(data: data, encoding: .utf8)
        print("Sending \(String(describing: str))")
        do {
            try await webSocketTask?.send(.data(data))
        } catch {
            print("Error: \(error)")
        }
    }
}
