package http

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/razorpay"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/loan"
)

type RazorpayHandler struct {
	loanService loan.Service
	client      *razorpay.Client
}

func NewRazorpayHandler(loanService loan.Service, client *razorpay.Client) *RazorpayHandler {
	return &RazorpayHandler{
		loanService: loanService,
		client:      client,
	}
}

type webhookEvent struct {
	Event   string                 `json:"event"`
	Payload map[string]interface{} `json:"payload"`
}

func (h *RazorpayHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Verify signature if secret is provided
	// For now, we skip or use a simple check if the user hasn't provided the secret yet
	// In production, signature verification is mandatory.

	var event webhookEvent
	if err := json.Unmarshal(body, &event); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	log.Printf("received razorpay webhook: %s", event.Event)

	switch event.Event {
	case "payment.captured":
		h.handlePaymentCaptured(r.Context(), event.Payload)
	case "payment.failed":
		h.handlePaymentFailed(r.Context(), event.Payload)
	}

	w.WriteHeader(http.StatusOK)
}

func (h *RazorpayHandler) handlePaymentCaptured(ctx context.Context, payload map[string]interface{}) {
	payment, ok := payload["payment"].(map[string]interface{})
	if !ok {
		return
	}

	entity, ok := payment["entity"].(map[string]interface{})
	if !ok {
		return
	}

	orderID, _ := entity["order_id"].(string)
	paymentID, _ := entity["id"].(string)

	if orderID == "" || paymentID == "" {
		return
	}

	if err := h.loanService.ProcessPaymentFromWebhook(ctx, orderID, paymentID); err != nil {
		log.Printf("failed to process payment from webhook: %v", err)
	}
}

func (h *RazorpayHandler) handlePaymentFailed(ctx context.Context, payload map[string]interface{}) {
	// Log and update order status to FAILED
}
