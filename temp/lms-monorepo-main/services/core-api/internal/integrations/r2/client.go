package r2

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type Client struct {
	bucket        string
	publicBaseURL string
	client        *s3.Client
	presignClient *s3.PresignClient
}

func NewClient(ctx context.Context, accountID, accessKeyID, secretAccessKey, bucket, publicBaseURL string) (*Client, error) {
	if accountID == "" || accessKeyID == "" || secretAccessKey == "" || bucket == "" {
		return nil, fmt.Errorf("missing required r2 configuration")
	}

	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID)
	awsCfg, err := config.LoadDefaultConfig(
		ctx,
		config.WithRegion("auto"),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKeyID, secretAccessKey, "")),
	)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = true
	})

	return &Client{
		bucket:        bucket,
		publicBaseURL: strings.TrimRight(publicBaseURL, "/"),
		client:        client,
		presignClient: s3.NewPresignClient(client),
	}, nil
}

func (c *Client) PresignPutObject(ctx context.Context, objectKey, contentType string, expires time.Duration) (string, error) {
	out, err := c.presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(c.bucket),
		Key:         aws.String(objectKey),
		ContentType: aws.String(contentType),
	}, s3.WithPresignExpires(expires))
	if err != nil {
		return "", fmt.Errorf("presign put object: %w", err)
	}
	return out.URL, nil
}

func (c *Client) HeadObject(ctx context.Context, objectKey string) (string, error) {
	out, err := c.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(c.bucket),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		return "", fmt.Errorf("head object: %w", err)
	}
	if out.ETag == nil {
		return "", nil
	}
	return strings.Trim(*out.ETag, "\""), nil
}

func (c *Client) ObjectURL(objectKey string) string {
	if c.publicBaseURL != "" {
		return c.publicBaseURL + "/" + url.PathEscape(objectKey)
	}
	return fmt.Sprintf("https://%s.r2.cloudflarestorage.com/%s", c.bucket, url.PathEscape(objectKey))
}

func (c *Client) Bucket() string {
	return c.bucket
}
