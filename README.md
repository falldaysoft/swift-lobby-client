# swift-lobby-client

swift-lobby is a very basic multiplayer game server, that I created
to help my son get started with a game he's working on.

More details on the protocol and how to use it are in the swift-lobby
project, which isn't currently public.

It's not secure and, using JSON strings over WebSockets, not performant,
compared to a more modern solution that uses something like protobufs,
but it's easy to understand and the code is very simple. Consider it a
learning tool, and maybe a starting point.

There are clients for multiple languages; this is the Swift client.

# State

Each lobby has some state that's shared when the user first joins
(via the `.hello` message) and then updated with messages like
`.setPlayerProperties` and `.addToList`.

`LobbyClient` tracks the state for you, so you can look at the 
`players`, `lobbyProperties` and `lists` properties without having
to process the messages to update them.

