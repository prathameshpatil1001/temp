package razorpay

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/razorpay/razorpay-go"
)

type Client struct {
	keyID     string
	keySecret string
	client    *razorpay.Client
}

func NewClient(keyID, keySecret string) *Client {
	return &Client{
		keyID:     keyID,
		keySecret: keySecret,
		client:    razorpay.NewClient(keyID, keySecret),
	}
}

func (c *Client) CreateOrder(amountPaise int64, receipt string) (string, error) {
	data := map[string]interface{}{
		"amount":   amountPaise,
		"currency": "INR",
		"receipt":  receipt,
	}
	body, err := c.client.Order.Create(data, nil)
	if err != nil {
		return "", fmt.Errorf("razorpay order creation failed: %w", err)
	}

	orderID, ok := body["id"].(string)
	if !ok {
		return "", errors.New("invalid response from razorpay: missing order id")
	}

	return orderID, nil
}

func (c *Client) VerifySignature(orderID, paymentID, signature string) error {
	data := orderID + "|" + paymentID
	h := hmac.New(sha256.New, []byte(c.keySecret))
	h.Write([]byte(data))
	expectedSignature := hex.EncodeToString(h.Sum(nil))

	if expectedSignature != signature {
		return errors.New("invalid razorpay signature")
	}
	return nil
}

func (c *Client) VerifyWebhookSignature(body []byte, signature string) error {
	h := hmac.New(sha256.New, []byte(c.keySecret)) // Use webhook secret if different, but often same
	h.Write(body)
	expectedSignature := hex.EncodeToString(h.Sum(nil))

	if expectedSignature != signature {
		return errors.New("invalid razorpay webhook signature")
	}
	return nil
}
