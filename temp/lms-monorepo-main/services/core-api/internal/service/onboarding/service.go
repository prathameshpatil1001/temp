package onboarding

import (
	"context"
	"log"
	"math/rand"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	onboardingv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/onboardingv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/util"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error)
	UpdateBorrowerProfile(ctx context.Context, req *onboardingv1.UpdateBorrowerProfileRequest) (*onboardingv1.UpdateBorrowerProfileResponse, error)
}

type service struct {
	queries generated.Querier
	redis   redis.Cmdable
	cfg     config.Config
}

func NewService(queries generated.Querier, redis redis.Cmdable, cfg config.Config) Service {
	return &service{queries: queries, redis: redis, cfg: cfg}
}

func (s *service) CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)

	targetUserID, err := resolveTargetBorrowerUser(ctx, s.queries, callerUserID, role, req.GetBorrowerUserId())
	if err != nil {
		return nil, err
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	if user.Role != generated.UserRoleBorrower {
		return nil, status.Error(codes.PermissionDenied, "only borrower can complete this onboarding")
	}

	firstName := strings.TrimSpace(req.GetFirstName())
	lastName := strings.TrimSpace(req.GetLastName())
	addressLine1 := strings.TrimSpace(req.GetAddressLine1())
	city := strings.TrimSpace(req.GetCity())
	state := strings.TrimSpace(req.GetState())
	pincode := strings.TrimSpace(req.GetPincode())
	if firstName == "" || lastName == "" || addressLine1 == "" || city == "" || state == "" || pincode == "" {
		return nil, status.Error(codes.InvalidArgument, "all profile fields are required")
	}

	dob, err := time.Parse("2006-01-02", req.GetDateOfBirth())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "date_of_birth must be YYYY-MM-DD")
	}

	if req.GetProfileCompletenessPercent() < 0 || req.GetProfileCompletenessPercent() > 100 {
		return nil, status.Error(codes.InvalidArgument, "profile_completeness_percent must be between 0 and 100")
	}

	gender, err := mapProtoBorrowerGender(req.GetGender())
	if err != nil {
		return nil, err
	}

	employmentType, err := mapProtoBorrowerEmploymentType(req.GetEmploymentType())
	if err != nil {
		return nil, err
	}

	var monthlyIncome pgtype.Numeric
	if err := monthlyIncome.Scan(strings.TrimSpace(req.GetMonthlyIncome())); err != nil {
		return nil, status.Error(codes.InvalidArgument, "monthly_income must be a valid decimal")
	}

	_, err = s.queries.CreateBorrowerProfile(ctx, generated.CreateBorrowerProfileParams{
		UserID:                     pgtype.UUID{Bytes: targetUserID, Valid: true},
		FirstName:                  firstName,
		LastName:                   lastName,
		DateOfBirth:                pgtype.Date{Time: dob, Valid: true},
		Gender:                     gender,
		AddressLine1:               addressLine1,
		City:                       city,
		State:                      state,
		Pincode:                    pincode,
		EmploymentType:             employmentType,
		MonthlyIncome:              monthlyIncome,
		ProfileCompletenessPercent: req.GetProfileCompletenessPercent(),
		CibilScore:                 int32(700 + rand.Intn(201)),
	})
	if err != nil {
		lowerErr := strings.ToLower(err.Error())
		if strings.Contains(lowerErr, "duplicate") || strings.Contains(lowerErr, "unique") {
			return nil, status.Error(codes.AlreadyExists, "borrower profile already exists")
		}
		return nil, status.Error(codes.Internal, "failed to create borrower profile")
	}

	if err := s.queries.ActivateUser(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true}); err != nil {
		return nil, status.Error(codes.Internal, "failed to activate user")
	}

	deviceID := strings.TrimSpace(req.GetDeviceId())
	if deviceID == "" {
		deviceID = "onboarding"
	}

	tokens, err := util.MintTokens(ctx, s.queries, s.redis, s.cfg.JWTKey, targetUserID, string(user.Role), deviceID)
	if err != nil {
		log.Printf("CompleteBorrowerOnboarding: token minting failed user=%s: %v", targetUserID, err)
		return nil, status.Error(codes.Internal, "failed to issue tokens")
	}

	return &onboardingv1.CompleteBorrowerOnboardingResponse{
		Success:      true,
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	}, nil
}

// UpdateBorrowerProfile updates an existing borrower profile.
// Borrower can update their own; staff roles can supply borrower_user_id.
func (s *service) UpdateBorrowerProfile(ctx context.Context, req *onboardingv1.UpdateBorrowerProfileRequest) (*onboardingv1.UpdateBorrowerProfileResponse, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)

	targetUserID, err := resolveTargetBorrowerUser(ctx, s.queries, callerUserID, role, req.GetBorrowerUserId())
	if err != nil {
		return nil, err
	}

	// Verify the borrower profile already exists before updating.
	existingProfile, err := s.queries.GetBorrowerProfileByUserID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "borrower profile not found — complete onboarding first")
	}

	firstName := strings.TrimSpace(req.GetFirstName())
	lastName := strings.TrimSpace(req.GetLastName())
	addressLine1 := strings.TrimSpace(req.GetAddressLine1())
	city := strings.TrimSpace(req.GetCity())
	state := strings.TrimSpace(req.GetState())
	pincode := strings.TrimSpace(req.GetPincode())
	if firstName == "" || lastName == "" || addressLine1 == "" || city == "" || state == "" || pincode == "" {
		return nil, status.Error(codes.InvalidArgument, "all profile fields are required")
	}

	dob, err := time.Parse("2006-01-02", req.GetDateOfBirth())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "date_of_birth must be YYYY-MM-DD")
	}

	if req.GetProfileCompletenessPercent() < 0 || req.GetProfileCompletenessPercent() > 100 {
		return nil, status.Error(codes.InvalidArgument, "profile_completeness_percent must be between 0 and 100")
	}

	gender, err := mapProtoBorrowerGender(req.GetGender())
	if err != nil {
		return nil, err
	}

	employmentType, err := mapProtoBorrowerEmploymentType(req.GetEmploymentType())
	if err != nil {
		return nil, err
	}

	var monthlyIncome pgtype.Numeric
	if err := monthlyIncome.Scan(strings.TrimSpace(req.GetMonthlyIncome())); err != nil {
		return nil, status.Error(codes.InvalidArgument, "monthly_income must be a valid decimal")
	}

	cibilScore := existingProfile.CibilScore
	if req.GetCibilScore() != 0 {
		cibilScore = req.GetCibilScore()
	}

	if err := s.queries.UpdateBorrowerProfile(ctx, generated.UpdateBorrowerProfileParams{
		UserID:                     pgtype.UUID{Bytes: targetUserID, Valid: true},
		FirstName:                  firstName,
		LastName:                   lastName,
		DateOfBirth:                pgtype.Date{Time: dob, Valid: true},
		Gender:                     gender,
		AddressLine1:               addressLine1,
		City:                       city,
		State:                      state,
		Pincode:                    pincode,
		EmploymentType:             employmentType,
		MonthlyIncome:              monthlyIncome,
		ProfileCompletenessPercent: req.GetProfileCompletenessPercent(),
		CibilScore:                 cibilScore,
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to update borrower profile")
	}

	return &onboardingv1.UpdateBorrowerProfileResponse{Success: true}, nil
}

func resolveTargetBorrowerUser(ctx context.Context, queries generated.Querier, callerUserID uuid.UUID, role, borrowerUserID string) (uuid.UUID, error) {
	trimmed := strings.TrimSpace(borrowerUserID)
	switch role {
	case "borrower":
		if trimmed != "" && trimmed != callerUserID.String() {
			return uuid.UUID{}, status.Error(codes.PermissionDenied, "borrower can only onboard own profile")
		}
		return callerUserID, nil
	case "officer", "dst", "manager", "admin":
		if trimmed == "" {
			return uuid.UUID{}, status.Error(codes.InvalidArgument, "borrower_user_id is required for assisted onboarding")
		}
		targetUserID, err := uuid.Parse(trimmed)
		if err != nil {
			return uuid.UUID{}, status.Error(codes.InvalidArgument, "borrower_user_id must be a valid uuid")
		}
		user, err := queries.GetUserByID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
		if err != nil {
			return uuid.UUID{}, status.Error(codes.NotFound, "borrower user not found")
		}
		if user.Role != generated.UserRoleBorrower {
			return uuid.UUID{}, status.Error(codes.InvalidArgument, "target user is not a borrower")
		}
		return targetUserID, nil
	default:
		return uuid.UUID{}, status.Error(codes.PermissionDenied, "role cannot complete onboarding")
	}
}

func mapProtoBorrowerGender(gender onboardingv1.BorrowerGender) (generated.BorrowerGender, error) {
	switch gender {
	case onboardingv1.BorrowerGender_BORROWER_GENDER_MALE:
		return generated.BorrowerGenderMALE, nil
	case onboardingv1.BorrowerGender_BORROWER_GENDER_FEMALE:
		return generated.BorrowerGenderFEMALE, nil
	case onboardingv1.BorrowerGender_BORROWER_GENDER_OTHER:
		return generated.BorrowerGenderOTHER, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid borrower gender")
	}
}

func mapProtoBorrowerEmploymentType(employmentType onboardingv1.BorrowerEmploymentType) (generated.BorrowerEmploymentType, error) {
	switch employmentType {
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_SALARIED:
		return generated.BorrowerEmploymentTypeSALARIED, nil
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_SELF_EMPLOYED:
		return generated.BorrowerEmploymentTypeSELFEMPLOYED, nil
	case onboardingv1.BorrowerEmploymentType_BORROWER_EMPLOYMENT_TYPE_BUSINESS:
		return generated.BorrowerEmploymentTypeBUSINESS, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid borrower employment type")
	}
}