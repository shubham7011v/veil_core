package firebase

import (
	"context"

	"firebase.google.com/go/v4/auth"
)

type Adapter struct {
	client *auth.Client
}

func NewAdapter(client *auth.Client) *Adapter {
	return &Adapter{client: client}
}

func (a *Adapter) VerifyToken(ctx context.Context, tokenString string) (uid, name, picture string, err error) {
	token, err := a.client.VerifyIDToken(ctx, tokenString)
	if err != nil {
		return "", "", "", err
	}

	uid = token.UID
	if val, ok := token.Claims["name"].(string); ok {
		name = val
	}
	if val, ok := token.Claims["picture"].(string); ok {
		picture = val
	}
	return uid, name, picture, nil
}
