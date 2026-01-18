package room

import (
	"log"
	"veil_server/protocol"
)

// ActionHandler defines the signature for processing a game action
type ActionHandler func(action GameAction)

// Middleware defines the signature for an action middleware
type Middleware func(next ActionHandler) ActionHandler

// AuthMiddleware ensures the client is a member of the room
func (r *Room) AuthMiddleware(next ActionHandler) ActionHandler {
	return func(action GameAction) {
		if !r.clients[action.Client] {
			log.Printf("Rejected action from non-member client %s in room %s", action.Client.ID, r.ID)
			return
		}
		next(action)
	}
}

// ValidationMiddleware ensures the message type is valid for a game room
func (r *Room) ValidationMiddleware(next ActionHandler) ActionHandler {
	return func(action GameAction) {
		if !isValidGameMessageType(action.Message.Type) {
			log.Printf("Invalid message type %s from client %s", action.Message.Type, action.Client.ID)
			r.sendErrorToClient(action.Client, protocol.ErrCodeInvalidMsg, "Invalid message type")
			return
		}
		next(action)
	}
}

// RateLimitMiddleware enforces per-client message frequency limits
func (r *Room) RateLimitMiddleware(next ActionHandler) ActionHandler {
	return func(action GameAction) {
		if !action.Client.canPerformAction() {
			log.Printf("Rate limited client %s", action.Client.ID)
			r.sendErrorToClient(action.Client, protocol.ErrCodeRateLimited, "Too many actions")
			return
		}
		next(action)
	}
}

// applyMiddlewares wraps the core handler with provided middlewares in order
func applyMiddlewares(handler ActionHandler, middlewares ...Middleware) ActionHandler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		handler = middlewares[i](handler)
	}
	return handler
}
