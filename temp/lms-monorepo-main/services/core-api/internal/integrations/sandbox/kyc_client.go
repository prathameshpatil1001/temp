package sandbox

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

type flexibleString string

func (f *flexibleString) UnmarshalJSON(data []byte) error {
	if len(data) > 0 && (data[0] == '"' && data[len(data)-1] == '"') {
		var s string
		if err := json.Unmarshal(data, &s); err != nil {
			return err
		}
		*f = flexibleString(s)
		return nil
	}
	var n json.Number
	if err := json.Unmarshal(data, &n); err != nil {
		return err
	}
	*f = flexibleString(n.String())
	return nil
}

type SandboxError struct {
	StatusCode    int
	Code          int    `json:"code"`
	Message       string `json:"message"`
	TransactionID string `json:"transaction_id"`
	RawBody       []byte
}

func (e *SandboxError) Error() string {
	if e.Message != "" {
		return fmt.Sprintf("sandbox api error: status=%d code=%d message=%s", e.StatusCode, e.Code, e.Message)
	}
	return fmt.Sprintf("sandbox http status %d", e.StatusCode)
}

type KYCClient struct {
	httpClient   *http.Client
	baseURL      string
	apiKey       string
	apiSecret    string
	apiVersion   string
	token        string
	tokenExpiry  time.Time
	tokenMu      sync.Mutex
	lastAuthErr  error
	authLeeway   time.Duration
	defaultReqTO time.Duration
	maxRetries   int
	retryBackoff time.Duration
}

type authenticateResponse struct {
	Code int `json:"code"`
	Data struct {
		AccessToken string `json:"access_token"`
	} `json:"data"`
}

type AadhaarGenerateOTPRequest struct {
	Entity        string `json:"@entity"`
	AadhaarNumber string `json:"aadhaar_number"`
	Consent       string `json:"consent"`
	Reason        string `json:"reason"`
}

type AadhaarGenerateOTPData struct {
	Entity      string `json:"@entity"`
	ReferenceID int64  `json:"reference_id"`
	Message     string `json:"message"`
}

type AadhaarGenerateOTPResponse struct {
	Code          int                    `json:"code"`
	Timestamp     int64                  `json:"timestamp"`
	TransactionID string                 `json:"transaction_id"`
	Data          AadhaarGenerateOTPData `json:"data"`
}

type AadhaarVerifyOTPRequest struct {
	Entity      string `json:"@entity"`
	ReferenceID string `json:"reference_id"`
	OTP         string `json:"otp"`
}

type AadhaarAddress struct {
	Entity      string         `json:"@entity"`
	Country     string         `json:"country"`
	District    string         `json:"district"`
	House       string         `json:"house"`
	Landmark    string         `json:"landmark"`
	Pincode     flexibleString `json:"pincode"`
	PostOffice  string         `json:"post_office"`
	State       string         `json:"state"`
	Street      string         `json:"street"`
	Subdistrict string         `json:"subdistrict"`
	VTC         string         `json:"vtc"`
}

type AadhaarVerifyOTPData struct {
	Entity      string         `json:"@entity"`
	ReferenceID int64          `json:"reference_id"`
	Status      string         `json:"status"`
	Message     string         `json:"message"`
	CareOf      string         `json:"care_of"`
	FullAddress string         `json:"full_address"`
	DateOfBirth string         `json:"date_of_birth"`
	EmailHash   string         `json:"email_hash"`
	Gender      string         `json:"gender"`
	Name        string         `json:"name"`
	Address     AadhaarAddress `json:"address"`
	YearOfBirth flexibleString `json:"year_of_birth"`
	MobileHash  string         `json:"mobile_hash"`
	ShareCode   string         `json:"share_code"`
}

type AadhaarVerifyOTPResponse struct {
	Code          int                  `json:"code"`
	Timestamp     int64                `json:"timestamp"`
	TransactionID string               `json:"transaction_id"`
	Data          AadhaarVerifyOTPData `json:"data"`
}

type PANVerifyRequest struct {
	Entity       string `json:"@entity"`
	PAN          string `json:"pan"`
	NameAsPerPAN string `json:"name_as_per_pan"`
	DateOfBirth  string `json:"date_of_birth"`
	Consent      string `json:"consent"`
	Reason       string `json:"reason"`
	UseCache     bool   `json:"-"` // Controls x-accept-cache header; not sent in JSON body
}

type PANVerifyData struct {
	Entity             string `json:"@entity"`
	PAN                string `json:"pan"`
	Category           string `json:"category"`
	Status             string `json:"status"`
	Remarks            string `json:"remarks"`
	NameAsPerPANMatch  bool   `json:"name_as_per_pan_match"`
	DateOfBirthMatch   bool   `json:"date_of_birth_match"`
	AadhaarSeedingStat string `json:"aadhaar_seeding_status"`
}

type PANVerifyResponse struct {
	Code          int           `json:"code"`
	Timestamp     int64         `json:"timestamp"`
	TransactionID string        `json:"transaction_id"`
	Data          PANVerifyData `json:"data"`
}

func NewKYCClient(baseURL, apiKey, apiSecret string) *KYCClient {
	return &KYCClient{
		httpClient:   &http.Client{Timeout: 20 * time.Second},
		baseURL:      strings.TrimSuffix(baseURL, "/"),
		apiKey:       apiKey,
		apiSecret:    apiSecret,
		apiVersion:   "2.0",
		authLeeway:   2 * time.Minute,
		defaultReqTO: 20 * time.Second,
		maxRetries:   3,
		retryBackoff: 1 * time.Second,
	}
}

func (c *KYCClient) GenerateAadhaarOTP(ctx context.Context, req AadhaarGenerateOTPRequest) (*AadhaarGenerateOTPResponse, []byte, error) {
	body, respBody, err := c.postJSONWithRetry(ctx, "/kyc/aadhaar/okyc/otp", req, nil)
	if err != nil {
		return nil, respBody, err
	}
	var out AadhaarGenerateOTPResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, respBody, fmt.Errorf("decode aadhaar otp generate response: %w", err)
	}
	return &out, respBody, nil
}

func (c *KYCClient) VerifyAadhaarOTP(ctx context.Context, req AadhaarVerifyOTPRequest) (*AadhaarVerifyOTPResponse, []byte, error) {
	body, respBody, err := c.postJSONWithRetry(ctx, "/kyc/aadhaar/okyc/otp/verify", req, nil)
	if err != nil {
		return nil, respBody, err
	}
	var out AadhaarVerifyOTPResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, respBody, fmt.Errorf("decode aadhaar otp verify response: %w", err)
	}
	return &out, respBody, nil
}

func (c *KYCClient) VerifyPAN(ctx context.Context, req PANVerifyRequest) (*PANVerifyResponse, []byte, error) {
	headers := make(map[string]string)
	if req.UseCache {
		headers["x-accept-cache"] = "true"
	}
	body, respBody, err := c.postJSONWithRetry(ctx, "/kyc/pan/verify", req, headers)
	if err != nil {
		return nil, respBody, err
	}
	var out PANVerifyResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, respBody, fmt.Errorf("decode pan verify response: %w", err)
	}
	return &out, respBody, nil
}

func (c *KYCClient) postJSONWithRetry(ctx context.Context, path string, payload any, extraHeaders map[string]string) ([]byte, []byte, error) {
	var lastErr error
	var lastRespBody []byte

	for attempt := 0; attempt <= c.maxRetries; attempt++ {
		if attempt > 0 {
			backoff := c.retryBackoff * time.Duration(1<<(attempt-1))
			select {
			case <-time.After(backoff):
			case <-ctx.Done():
				return nil, lastRespBody, ctx.Err()
			}
		}

		body, respBody, err := c.postJSON(ctx, path, payload, extraHeaders)
		if err == nil {
			return body, respBody, nil
		}

		lastErr = err
		lastRespBody = respBody

		if !isRetryableError(err) {
			break
		}
	}

	return nil, lastRespBody, lastErr
}

func isRetryableError(err error) bool {
	if err == nil {
		return false
	}
	var sandboxErr *SandboxError
	if errors.As(err, &sandboxErr) {
		return sandboxErr.StatusCode >= 500
	}
	errStr := err.Error()
	if strings.Contains(errStr, "call sandbox endpoint") {
		return true
	}
	return false
}

func (c *KYCClient) postJSON(ctx context.Context, path string, payload any, extraHeaders map[string]string) ([]byte, []byte, error) {
	b, err := json.Marshal(payload)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal request: %w", err)
	}

	token, err := c.getAccessToken(ctx)
	if err != nil {
		return nil, nil, err
	}

	endpoint := c.baseURL + path
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(b))
	if err != nil {
		return nil, nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("x-api-version", c.apiVersion)
	req.Header.Set("authorization", token)
	for k, v := range extraHeaders {
		req.Header.Set(k, v)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("call sandbox endpoint: %w", err)
	}
	defer resp.Body.Close()

	respBody := new(bytes.Buffer)
	if _, err := respBody.ReadFrom(resp.Body); err != nil {
		return nil, nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		sandboxErr := &SandboxError{
			StatusCode: resp.StatusCode,
			RawBody:    respBody.Bytes(),
		}
		_ = json.Unmarshal(respBody.Bytes(), sandboxErr)
		return nil, respBody.Bytes(), sandboxErr
	}

	return respBody.Bytes(), respBody.Bytes(), nil
}

func (c *KYCClient) getAccessToken(ctx context.Context) (string, error) {
	c.tokenMu.Lock()
	defer c.tokenMu.Unlock()

	now := time.Now()
	if c.token != "" && now.Add(c.authLeeway).Before(c.tokenExpiry) {
		return c.token, nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/authenticate", nil)
	if err != nil {
		return "", fmt.Errorf("create auth request: %w", err)
	}
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("x-api-secret", c.apiSecret)
	req.Header.Set("x-api-version", c.apiVersion)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		c.lastAuthErr = err
		return "", fmt.Errorf("authenticate request failed: %w", err)
	}
	defer resp.Body.Close()

	body := new(bytes.Buffer)
	if _, err := body.ReadFrom(resp.Body); err != nil {
		return "", fmt.Errorf("read auth response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("authenticate http status %d", resp.StatusCode)
	}

	var authResp authenticateResponse
	if err := json.Unmarshal(body.Bytes(), &authResp); err != nil {
		return "", fmt.Errorf("decode authenticate response: %w", err)
	}
	if strings.TrimSpace(authResp.Data.AccessToken) == "" {
		return "", fmt.Errorf("empty access token from authenticate")
	}

	c.token = authResp.Data.AccessToken
	c.tokenExpiry = time.Now().Add(24 * time.Hour)
	return c.token, nil
}