//
//  PlayerMessages.swift
//  
//
//  Created by Steve Tibbett on 2022-04-15.
//

import Foundation

/***
 Messages that clients can send to the server.  The first
 connected client "owns" the lobby.
 */
public enum IncomingPlayerMessage: Codable, Equatable {
    /// Client Ping
    case ping
    /// Message from the user to show to all users
    case say(text: String)
    // Message from the user to show to another specific user
    case directSay(text: String, toPlayer: Int)
    /// Set properties for this player; properties are merged with the
    /// player's properties.  This sends the playerUpdated message
    /// to everyone connected.
    case setPlayerProperties(properties: [String:String])
    /// Set properties for the lobby.  This is merged with the existing
    /// lobby properties, and if changed, broadcast to all connections.
    case setLobbyProperties(properties: [String:String])
    /// Set the display name for this user.
    case setPlayerName(name: String)
    /// Broadcast a message to connected clients.  This is for
    /// application-specific data.
    case broadcast(data: [String:String])
    /// Kick a user out of the lobby.  Can only be performed by
    /// the lobby owner.
    case kick(playerNum: Int)
    /// Vote to kick a player.  The server decides what to do with the votes.
    case voteKick(playerNum: Int)
    /// Change who owns the room.  Can only be performed
    /// by the current owner.
    case transferOwner(playerNum: Int)
    /// Run a server-side script action
    case action(name: String, params: [String:String])
    /// Append a dictionary to a list
    case addToList(name: String, value: [String:String])
    /// Clear a list
    case resetList(name: String)
}

// Sent in the "hello" message to let the client know about
// all the current players.
public struct PlayerInfo: Codable, Equatable {
    public var name: String
    public var playerNum: Int
    public var properties: [String: String]
}

/**
 Messages that the server can send to clients.
 */
public enum OutgoingPlayerMessage: Codable, Equatable {
    /// Send a message to all clients, payload is up to the client.
    case broadcast(data: [String:String])
    /// Message to just this player
    case directSay(text: String, date: Date, fromPlayerNum: Int)
    // Unexpected error
    case error(message: String)
    /// Every connected player will get this message first
    case hello(lobbyCode: String, playerNum: Int, players: [PlayerInfo], lobbyProperties: [String:String], lists: [String:[[String:String]]])
    /// If the player tried to connect to a nonexistent lobby, this is returned and the connection is closed
    case lobbyNotFound
    /// A player has joined.
    case playerJoined(player: PlayerInfo)
    /// A player has changed their display name.
    case playerChangedName(playerNum: Int, newName: String)
    /// This player is no longer connected.
    case playerDeparted(playerNum: Int)
    /// Lobby property update:  Clients should merge this with local state.
    case lobbyPropertiesUpdated(properties: [String:String])
    /// Who owns the lobby has changed
    case lobbyOwnerChanged(playerNum: Int)
    /// A player has changed their properties; merge this with the local properties for this player.
    case playerPropertiesUpdated(playerNum: Int, properties: [String:String])
    // The server will send this in response to a ping
    case pong
    /// Message to all players in the room
    case say(text: String, date: Date, fromPlayerNum: Int)
    /// Append a dictionary to a list
    case addToList(name: String, value: [String:String])
    /// Clear a list
    case resetList(name: String)
}

