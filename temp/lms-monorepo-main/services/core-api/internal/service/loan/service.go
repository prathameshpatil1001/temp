package loan

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/audit"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/razorpay"
	loanv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/loanv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	CreateLoanProduct(ctx context.Context, req *loanv1.CreateLoanProductRequest) (*loanv1.CreateLoanProductResponse, error)
	UpdateLoanProduct(ctx context.Context, req *loanv1.UpdateLoanProductRequest) (*loanv1.UpdateLoanProductResponse, error)
	DeleteLoanProduct(ctx context.Context, req *loanv1.DeleteLoanProductRequest) (*loanv1.DeleteLoanProductResponse, error)
	GetLoanProduct(ctx context.Context, req *loanv1.GetLoanProductRequest) (*loanv1.GetLoanProductResponse, error)
	ListLoanProducts(ctx context.Context, req *loanv1.ListLoanProductsRequest) (*loanv1.ListLoanProductsResponse, error)
	UpsertProductEligibilityRule(ctx context.Context, req *loanv1.UpsertProductEligibilityRuleRequest) (*loanv1.UpsertProductEligibilityRuleResponse, error)
	ReplaceProductFees(ctx context.Context, req *loanv1.ReplaceProductFeesRequest) (*loanv1.ReplaceProductFeesResponse, error)
	ReplaceProductRequiredDocuments(ctx context.Context, req *loanv1.ReplaceProductRequiredDocumentsRequest) (*loanv1.ReplaceProductRequiredDocumentsResponse, error)
	CreateLoanApplication(ctx context.Context, req *loanv1.CreateLoanApplicationRequest) (*loanv1.CreateLoanApplicationResponse, error)
	GetLoanApplication(ctx context.Context, req *loanv1.GetLoanApplicationRequest) (*loanv1.GetLoanApplicationResponse, error)
	ListLoanApplications(ctx context.Context, req *loanv1.ListLoanApplicationsRequest) (*loanv1.ListLoanApplicationsResponse, error)
	UpdateLoanApplicationStatus(ctx context.Context, req *loanv1.UpdateLoanApplicationStatusRequest) (*loanv1.UpdateLoanApplicationStatusResponse, error)
	UpdateLoanApplicationTerms(ctx context.Context, req *loanv1.UpdateLoanApplicationTermsRequest) (*loanv1.UpdateLoanApplicationTermsResponse, error)
	AssignLoanApplicationOfficer(ctx context.Context, req *loanv1.AssignLoanApplicationOfficerRequest) (*loanv1.AssignLoanApplicationOfficerResponse, error)
	AddApplicationCoapplicant(ctx context.Context, req *loanv1.AddApplicationCoapplicantRequest) (*loanv1.AddApplicationCoapplicantResponse, error)
	UpsertApplicationCollateral(ctx context.Context, req *loanv1.UpsertApplicationCollateralRequest) (*loanv1.UpsertApplicationCollateralResponse, error)
	UpsertLoanVehicle(ctx context.Context, req *loanv1.UpsertLoanVehicleRequest) (*loanv1.UpsertLoanVehicleResponse, error)
	UpsertLoanRealEstate(ctx context.Context, req *loanv1.UpsertLoanRealEstateRequest) (*loanv1.UpsertLoanRealEstateResponse, error)
	AddApplicationDocument(ctx context.Context, req *loanv1.AddApplicationDocumentRequest) (*loanv1.AddApplicationDocumentResponse, error)
	UpdateApplicationDocumentVerification(ctx context.Context, req *loanv1.UpdateApplicationDocumentVerificationRequest) (*loanv1.UpdateApplicationDocumentVerificationResponse, error)
	AddBureauScore(ctx context.Context, req *loanv1.AddBureauScoreRequest) (*loanv1.AddBureauScoreResponse, error)
	CreateLoan(ctx context.Context, req *loanv1.CreateLoanRequest) (*loanv1.CreateLoanResponse, error)
	GetLoan(ctx context.Context, req *loanv1.GetLoanRequest) (*loanv1.GetLoanResponse, error)
	ListLoans(ctx context.Context, req *loanv1.ListLoansRequest) (*loanv1.ListLoansResponse, error)
	AddEmiScheduleItem(ctx context.Context, req *loanv1.AddEmiScheduleItemRequest) (*loanv1.AddEmiScheduleItemResponse, error)
	ListEmiSchedule(ctx context.Context, req *loanv1.ListEmiScheduleRequest) (*loanv1.ListEmiScheduleResponse, error)
	RecordPayment(ctx context.Context, req *loanv1.RecordPaymentRequest) (*loanv1.RecordPaymentResponse, error)
	ListPayments(ctx context.Context, req *loanv1.ListPaymentsRequest) (*loanv1.ListPaymentsResponse, error)
	RescheduleLoan(ctx context.Context, req *loanv1.RescheduleLoanRequest) (*loanv1.RescheduleLoanResponse, error)
	InitiatePayment(ctx context.Context, req *loanv1.InitiatePaymentRequest) (*loanv1.InitiatePaymentResponse, error)
	VerifyPayment(ctx context.Context, req *loanv1.VerifyPaymentRequest) (*loanv1.VerifyPaymentResponse, error)
	ProcessPaymentFromWebhook(ctx context.Context, orderID, paymentID string) error
}

type service struct {
	queries  generated.Querier
	audit    audit.AuditService
	razorpay *razorpay.Client
}

func NewService(queries generated.Querier, audit audit.AuditService, razorpay *razorpay.Client) Service {
	return &service{queries: queries, audit: audit, razorpay: razorpay}
}

func (s *service) CreateLoanProduct(ctx context.Context, req *loanv1.CreateLoanProductRequest) (*loanv1.CreateLoanProductResponse, error) {
	arg, err := buildCreateLoanProductParams(req)
	if err != nil {
		return nil, err
	}
	row, err := s.queries.CreateLoanProduct(ctx, arg)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create loan product")
	}
	return &loanv1.CreateLoanProductResponse{Product: mapLoanProduct(row, nil, nil, nil)}, nil
}

func (s *service) UpdateLoanProduct(ctx context.Context, req *loanv1.UpdateLoanProductRequest) (*loanv1.UpdateLoanProductResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	arg, err := buildUpdateLoanProductParams(productID, req)
	if err != nil {
		return nil, err
	}
	row, err := s.queries.UpdateLoanProduct(ctx, arg)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan product not found")
		}
		return nil, status.Error(codes.Internal, "failed to update loan product")
	}
	return &loanv1.UpdateLoanProductResponse{Product: mapLoanProduct(row, nil, nil, nil)}, nil
}

func (s *service) DeleteLoanProduct(ctx context.Context, req *loanv1.DeleteLoanProductRequest) (*loanv1.DeleteLoanProductResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	if err := s.queries.SoftDeleteLoanProduct(ctx, uuidToPg(productID)); err != nil {
		return nil, status.Error(codes.Internal, "failed to delete loan product")
	}
	return &loanv1.DeleteLoanProductResponse{Success: true}, nil
}

func (s *service) GetLoanProduct(ctx context.Context, req *loanv1.GetLoanProductRequest) (*loanv1.GetLoanProductResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	row, err := s.queries.GetLoanProductByID(ctx, uuidToPg(productID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan product not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan product")
	}
	rule, _ := s.queries.GetProductEligibilityRuleByProductID(ctx, row.ID)
	fees, _ := s.queries.ListProductFeesByProductID(ctx, row.ID)
	docs, _ := s.queries.ListProductRequiredDocumentsByProductID(ctx, row.ID)

	return &loanv1.GetLoanProductResponse{Product: mapLoanProduct(row, &rule, fees, docs)}, nil
}

func (s *service) ListLoanProducts(ctx context.Context, req *loanv1.ListLoanProductsRequest) (*loanv1.ListLoanProductsResponse, error) {
	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())
	rows, err := s.queries.ListLoanProducts(ctx, generated.ListLoanProductsParams{
		Column1: req.GetIncludeDeleted(),
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list loan products")
	}
	items := make([]*loanv1.LoanProduct, 0, len(rows))
	for _, row := range rows {
		rule, _ := s.queries.GetProductEligibilityRuleByProductID(ctx, row.ID)
		fees, _ := s.queries.ListProductFeesByProductID(ctx, row.ID)
		docs, _ := s.queries.ListProductRequiredDocumentsByProductID(ctx, row.ID)
		items = append(items, mapLoanProduct(row, &rule, fees, docs))
	}
	return &loanv1.ListLoanProductsResponse{Items: items}, nil
}

func (s *service) UpsertProductEligibilityRule(ctx context.Context, req *loanv1.UpsertProductEligibilityRuleRequest) (*loanv1.UpsertProductEligibilityRuleResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	minIncome, err := parseNumeric(req.GetMinMonthlyIncome(), "min_monthly_income")
	if err != nil {
		return nil, err
	}
	if req.GetMinAge() < 18 {
		return nil, status.Error(codes.InvalidArgument, "min_age must be >= 18")
	}
	if req.GetMinBureauScore() < 0 || req.GetMinBureauScore() > 900 {
		return nil, status.Error(codes.InvalidArgument, "min_bureau_score must be between 0 and 900")
	}
	row, err := s.queries.UpsertProductEligibilityRule(ctx, generated.UpsertProductEligibilityRuleParams{
		LoanProductID:          uuidToPg(productID),
		MinAge:                 req.GetMinAge(),
		MinMonthlyIncome:       minIncome,
		MinBureauScore:         req.GetMinBureauScore(),
		AllowedEmploymentTypes: req.GetAllowedEmploymentTypes(),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save eligibility rule")
	}
	return &loanv1.UpsertProductEligibilityRuleResponse{Rule: mapEligibilityRule(row)}, nil
}

func (s *service) ReplaceProductFees(ctx context.Context, req *loanv1.ReplaceProductFeesRequest) (*loanv1.ReplaceProductFeesResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	if err := s.queries.DeleteProductFeesByProductID(ctx, uuidToPg(productID)); err != nil {
		return nil, status.Error(codes.Internal, "failed to replace product fees")
	}
	items := make([]*loanv1.ProductFee, 0, len(req.GetItems()))
	for _, item := range req.GetItems() {
		value, err := parseNumeric(item.GetValue(), "value")
		if err != nil {
			return nil, err
		}
		row, err := s.queries.CreateProductFee(ctx, generated.CreateProductFeeParams{
			LoanProductID: uuidToPg(productID),
			FeeType:       toDBFeeType(item.GetType()),
			CalcMethod:    toDBFeeCalcMethod(item.GetCalcMethod()),
			Value:         value,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to create product fee")
		}
		items = append(items, mapProductFee(row))
	}
	return &loanv1.ReplaceProductFeesResponse{Items: items}, nil
}

func (s *service) ReplaceProductRequiredDocuments(ctx context.Context, req *loanv1.ReplaceProductRequiredDocumentsRequest) (*loanv1.ReplaceProductRequiredDocumentsResponse, error) {
	productID, err := parseUUID(req.GetProductId(), "product_id")
	if err != nil {
		return nil, err
	}
	if err := s.queries.DeleteProductRequiredDocumentsByProductID(ctx, uuidToPg(productID)); err != nil {
		return nil, status.Error(codes.Internal, "failed to replace required documents")
	}
	items := make([]*loanv1.ProductRequiredDocument, 0, len(req.GetItems()))
	for _, item := range req.GetItems() {
		row, err := s.queries.CreateProductRequiredDocument(ctx, generated.CreateProductRequiredDocumentParams{
			LoanProductID:   uuidToPg(productID),
			RequirementType: toDBRequirementType(item.GetRequirementType()),
			IsMandatory:     item.GetIsMandatory(),
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to create required document")
		}
		items = append(items, mapRequiredDocument(row))
	}
	return &loanv1.ReplaceProductRequiredDocumentsResponse{Items: items}, nil
}

func (s *service) CreateLoanApplication(ctx context.Context, req *loanv1.CreateLoanApplicationRequest) (*loanv1.CreateLoanApplicationResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	productID, err := parseUUID(req.GetLoanProductId(), "loan_product_id")
	if err != nil {
		return nil, err
	}
	branchID, err := parseUUID(req.GetBranchId(), "branch_id")
	if err != nil {
		return nil, err
	}

	primaryBorrowerIDStr := strings.TrimSpace(req.GetPrimaryBorrowerProfileId())
	var borrowerProfileID uuid.UUID
	if role == "borrower" && primaryBorrowerIDStr == "" {
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil {
			return nil, status.Error(codes.FailedPrecondition, "borrower profile not found")
		}
		borrowerProfileID = uuid.UUID(profile.ID.Bytes)
	} else {
		borrowerProfileID, err = parseUUID(primaryBorrowerIDStr, "primary_borrower_profile_id")
		if err != nil {
			return nil, err
		}
	}

	reqAmount, err := parseNumeric(req.GetRequestedAmount(), "requested_amount")
	if err != nil {
		return nil, err
	}
	if req.GetTenureMonths() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "tenure_months must be > 0")
	}

	channel := deriveCreatedByChannel(role)
	if channel == generated.ApplicationCreatedByChannel("") {
		return nil, status.Error(codes.PermissionDenied, "role cannot create loan application")
	}
	if role == "dst" || role == "officer" {
		callerBranchID, err := s.branchForUserRole(ctx, callerUserID, role)
		if err != nil {
			return nil, err
		}
		if callerBranchID != branchID {
			return nil, status.Error(codes.PermissionDenied, "you can only create applications in your assigned branch")
		}
	}

	branchRow, err := s.queries.GetBankBranchByID(ctx, uuidToPg(branchID))
	if err != nil || !branchRow.ID.Valid {
		return nil, status.Error(codes.InvalidArgument, "branch_id not found")
	}

	product, err := s.queries.GetLoanProductByID(ctx, uuidToPg(productID))
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "loan_product_id not found")
	}
	if product.IsDeleted || !product.IsActive {
		return nil, status.Error(codes.FailedPrecondition, "loan product is not active")
	}
	if role == "borrower" && product.Category != generated.LoanProductCategoryPERSONAL {
		return nil, status.Error(codes.FailedPrecondition, "borrower can directly create applications only for personal loan products; use loan query for other products")
	}
	minAmount, maxAmount, requestedAmount, err := numericTriplet(product.MinAmount, product.MaxAmount, reqAmount)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid product amount configuration")
	}
	if requestedAmount < minAmount || requestedAmount > maxAmount {
		return nil, status.Errorf(codes.FailedPrecondition, "requested_amount must be between %s and %s", numericToString(product.MinAmount), numericToString(product.MaxAmount))
	}

	eligibilityRule, err := s.queries.GetProductEligibilityRuleByProductID(ctx, uuidToPg(productID))
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "eligibility rules are not configured for this product")
	}

	borrowerProfile, err := s.queries.GetBorrowerProfileByID(ctx, uuidToPg(borrowerProfileID))
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "primary_borrower_profile_id not found")
	}
	if role == "officer" || role == "dst" {
		if !borrowerProfile.IsAadhaarVerified || !borrowerProfile.IsPanVerified {
			return nil, status.Error(codes.FailedPrecondition, "borrower kyc must be complete before staff can create loan application")
		}
	}

	borrowerAge := ageFromDate(borrowerProfile.DateOfBirth.Time)
	if borrowerAge < int(eligibilityRule.MinAge) {
		return nil, status.Errorf(codes.FailedPrecondition, "borrower does not satisfy min_age (%d)", eligibilityRule.MinAge)
	}
	minIncome, borrowerIncome, err := numericPair(eligibilityRule.MinMonthlyIncome, borrowerProfile.MonthlyIncome)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to evaluate income eligibility")
	}
	if borrowerIncome < minIncome {
		return nil, status.Errorf(codes.FailedPrecondition, "borrower does not satisfy min_monthly_income (%s)", numericToString(eligibilityRule.MinMonthlyIncome))
	}
	if len(eligibilityRule.AllowedEmploymentTypes) > 0 && !containsFold(eligibilityRule.AllowedEmploymentTypes, string(borrowerProfile.EmploymentType)) {
		return nil, status.Error(codes.FailedPrecondition, "borrower employment_type is not eligible for this product")
	}
	latestScore, err := s.queries.GetLatestActiveBureauScoreByBorrowerProfile(ctx, uuidToPg(borrowerProfileID))
	if err == nil {
		if latestScore.Score < eligibilityRule.MinBureauScore {
			return nil, status.Errorf(codes.FailedPrecondition, "borrower does not satisfy min_bureau_score (%d)", eligibilityRule.MinBureauScore)
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Error(codes.Internal, "failed to evaluate bureau score eligibility")
	}

	ref := generateReferenceNumber()
	statusValue := toDBApplicationStatus(req.GetStatus())
	if statusValue == generated.LoanApplicationStatus("") {
		statusValue = generated.LoanApplicationStatusDRAFT
	}

	row, err := s.queries.CreateLoanApplication(ctx, generated.CreateLoanApplicationParams{
		ReferenceNumber:          ref,
		PrimaryBorrowerProfileID: uuidToPg(borrowerProfileID),
		LoanProductID:            uuidToPg(productID),
		BranchID:                 uuidToPg(branchID),
		RequestedAmount:          reqAmount,
		TenureMonths:             req.GetTenureMonths(),
		OfferedInterestRate:      product.BaseInterestRate,
		Status:                   statusValue,
		AssignedOfficerUserID:    pgtype.UUID{},
		EscalationReason:         pgtype.Text{},
		CreatedByUserID:          uuidToPg(callerUserID),
		CreatedByRole:            generated.UserRole(role),
		CreatedByChannel:              channel,
		ProductSnapshotJson:           []byte(buildProductSnapshotJSON(product)),
		DisbursementAccountNumber:     pgText(req.GetDisbursementAccountNumber()),
		DisbursementIfscCode:          pgText(req.GetDisbursementIfscCode()),
		DisbursementBankName:          pgText(req.GetDisbursementBankName()),
		DisbursementAccountHolderName: pgText(req.GetDisbursementAccountHolderName()),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create loan application")
	}

	// Auto-assign a random active officer from the branch.
	officerUserIDs, err := s.queries.ListOfficerUserIDsByBranchID(ctx, uuidToPg(branchID))
	if err == nil && len(officerUserIDs) > 0 {
		picked := officerUserIDs[rand.Intn(len(officerUserIDs))]
		_ = s.queries.AssignLoanApplicationOfficer(ctx, generated.AssignLoanApplicationOfficerParams{
			ID:                    row.ID,
			AssignedOfficerUserID: picked,
		})
		row.AssignedOfficerUserID = picked
	}

	return &loanv1.CreateLoanApplicationResponse{Application: mapLoanApplicationBase(row, "", "")}, nil
}

func (s *service) GetLoanApplication(ctx context.Context, req *loanv1.GetLoanApplicationRequest) (*loanv1.GetLoanApplicationResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	view, err := s.queries.GetLoanApplicationViewByID(ctx, uuidToPg(applicationID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan application not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan application")
	}
	if err := s.ensureCanAccessApplication(ctx, view.PrimaryBorrowerProfileID, view.BranchID, view.ID); err != nil {
		return nil, err
	}

	coapps, _ := s.queries.ListApplicationCoapplicants(ctx, view.ID)
	collateral, _ := s.queries.GetApplicationCollateralByApplicationID(ctx, view.ID)
	vehicle, _ := s.queries.GetLoanVehicleByApplicationID(ctx, view.ID)
	realEstate, _ := s.queries.GetLoanRealEstateByApplicationID(ctx, view.ID)
	docs, _ := s.queries.ListApplicationDocumentsByApplicationID(ctx, view.ID)
	bureauScores, _ := s.queries.ListBureauScoresByApplicationID(ctx, view.ID)

	resp := &loanv1.GetLoanApplicationResponse{
		Application:  mapLoanApplicationView(view),
		Coapplicants: mapCoapplicants(coapps),
		Documents:    mapDocuments(docs),
		BureauScores: mapBureauScores(bureauScores),
	}
	if collateral.ID.Valid {
		resp.Collateral = mapCollateral(collateral)
	}
	if vehicle.ID.Valid {
		resp.Vehicle = mapVehicle(vehicle)
	}
	if realEstate.ID.Valid {
		resp.RealEstate = mapRealEstate(realEstate)
	}
	return resp, nil
}

func (s *service) ListLoanApplications(ctx context.Context, req *loanv1.ListLoanApplicationsRequest) (*loanv1.ListLoanApplicationsResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())

	items := make([]*loanv1.LoanApplication, 0)
	switch role {
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil {
			return nil, status.Error(codes.FailedPrecondition, "borrower profile not found")
		}
		rows, err := s.queries.ListLoanApplicationsForBorrowerProfile(ctx, generated.ListLoanApplicationsForBorrowerProfileParams{
			PrimaryBorrowerProfileID: profile.ID,
			Limit:                    limit,
			Offset:                   offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan applications")
		}
		for _, row := range rows {
			items = append(items, mapLoanApplicationRowForBorrower(row))
		}
	case "officer":
		rows, err := s.queries.ListLoanApplicationsByAssignedOfficer(ctx, generated.ListLoanApplicationsByAssignedOfficerParams{
			AssignedOfficerUserID: uuidToPg(callerUserID),
			Limit:                 limit,
			Offset:                offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan applications")
		}
		for _, row := range rows {
			items = append(items, mapLoanApplicationRowForOfficer(row))
		}
	case "dst":
		rows, err := s.queries.ListLoanApplicationsByCreatedByUserID(ctx, generated.ListLoanApplicationsByCreatedByUserIDParams{
			CreatedByUserID: uuidToPg(callerUserID),
			Limit:           limit,
			Offset:          offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan applications")
		}
		for _, row := range rows {
			items = append(items, mapLoanApplicationRowForDst(row))
		}
	case "manager":
		branchID, err := s.branchForUserRole(ctx, callerUserID, role)
		if err != nil {
			return nil, err
		}
		if req.GetBranchId() != "" {
			requestBranchID, err := parseUUID(req.GetBranchId(), "branch_id")
			if err != nil {
				return nil, err
			}
			if requestBranchID != branchID {
				return nil, status.Error(codes.PermissionDenied, "cannot list applications outside your branch")
			}
		}
		rows, err := s.queries.ListLoanApplicationsByBranchID(ctx, generated.ListLoanApplicationsByBranchIDParams{
			BranchID: uuidToPg(branchID),
			Limit:    limit,
			Offset:   offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan applications")
		}
		for _, row := range rows {
			items = append(items, mapLoanApplicationRowForBranch(row))
		}
	case "admin":
		if req.GetBranchId() != "" {
			branchID, err := parseUUID(req.GetBranchId(), "branch_id")
			if err != nil {
				return nil, err
			}
			rows, err := s.queries.ListLoanApplicationsByBranchID(ctx, generated.ListLoanApplicationsByBranchIDParams{
				BranchID: uuidToPg(branchID),
				Limit:    limit,
				Offset:   offset,
			})
			if err != nil {
				return nil, status.Error(codes.Internal, "failed to list loan applications")
			}
			for _, row := range rows {
				items = append(items, mapLoanApplicationRowForBranch(row))
			}
		} else {
			rows, err := s.queries.ListAllLoanApplications(ctx, generated.ListAllLoanApplicationsParams{Limit: limit, Offset: offset})
			if err != nil {
				return nil, status.Error(codes.Internal, "failed to list loan applications")
			}
			for _, row := range rows {
				items = append(items, mapLoanApplicationRowForAdmin(row))
			}
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "role cannot list loan applications")
	}
	return &loanv1.ListLoanApplicationsResponse{Items: items}, nil
}

func (s *service) UpdateLoanApplicationStatus(ctx context.Context, req *loanv1.UpdateLoanApplicationStatusRequest) (*loanv1.UpdateLoanApplicationStatusResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan application not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch application")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	statusValue := toDBApplicationStatus(req.GetStatus())
	if statusValue == generated.LoanApplicationStatus("") {
		return nil, status.Error(codes.InvalidArgument, "status is required")
	}
	if role == "officer" {
		if !appRow.AssignedOfficerUserID.Valid || appRow.AssignedOfficerUserID.Bytes != callerUserID {
			return nil, status.Error(codes.PermissionDenied, "officer can only update assigned applications")
		}
	}
	if role == "dst" {
		if appRow.CreatedByUserID.Bytes != callerUserID {
			return nil, status.Error(codes.PermissionDenied, "dst can only update applications they created")
		}
	}
	if err := validateApplicationStatusTransition(appRow.Status, statusValue, role); err != nil {
		return nil, err
	}

	if statusValue == generated.LoanApplicationStatusSUBMITTED {
		product, err := s.queries.GetLoanProductByID(ctx, appRow.LoanProductID)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to fetch loan product")
		}

		if product.IsRequiringCollateral {
			_, err := s.queries.GetApplicationCollateralByApplicationID(ctx, appRow.ID)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					return nil, status.Error(codes.FailedPrecondition, "collateral is required for this product")
				}
				return nil, status.Error(codes.Internal, "failed to fetch collateral details")
			}
		}

		switch product.Category {
case generated.LoanProductCategoryVEHICLE:
			_, err := s.queries.GetLoanVehicleByApplicationID(ctx, appRow.ID)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					return nil, status.Error(codes.FailedPrecondition, "vehicle details are required for vehicle loans")
				}
				return nil, status.Error(codes.Internal, "failed to fetch vehicle details")
			}
		case generated.LoanProductCategoryHOME:
			_, err := s.queries.GetLoanRealEstateByApplicationID(ctx, appRow.ID)
			if err != nil {
				if errors.Is(err, pgx.ErrNoRows) {
					return nil, status.Error(codes.FailedPrecondition, "real estate details are required for home loans")
				}
				return nil, status.Error(codes.Internal, "failed to fetch real estate details")
			}
		}
	}

	if err := s.queries.UpdateLoanApplicationStatus(ctx, generated.UpdateLoanApplicationStatusParams{
		ID:     appRow.ID,
		Status: statusValue,
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to update application status")
	}

	// Audit Log for status change
	if s.audit != nil {
		s.audit.Record(ctx, audit.AuditEntry{
			ActorID:      callerUserID,
			ActorRole:    role,
			Action:       "LOAN_APPLICATION_STATUS_CHANGED",
			ResourceType: "LOAN_APPLICATION",
			ResourceID:   uuid.UUID(appRow.ID.Bytes),
			Changes: map[string]any{
				"status": map[string]string{
					"old": string(appRow.Status),
					"new": string(statusValue),
				},
			},
		})
	}

	if strings.TrimSpace(req.GetEscalationReason()) != "" {
		if err := s.queries.UpdateLoanApplicationEscalation(ctx, generated.UpdateLoanApplicationEscalationParams{
			ID:               appRow.ID,
			EscalationReason: pgText(req.GetEscalationReason()),
		}); err != nil {
			return nil, status.Error(codes.Internal, "failed to update escalation reason")
		}
	}
	return &loanv1.UpdateLoanApplicationStatusResponse{Success: true}, nil
}

func (s *service) UpdateLoanApplicationTerms(ctx context.Context, req *loanv1.UpdateLoanApplicationTermsRequest) (*loanv1.UpdateLoanApplicationTermsResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	if role != "officer" && role != "manager" && role != "admin" {
		return nil, status.Error(codes.PermissionDenied, "role cannot update loan terms")
	}
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan application not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch application")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	if role == "officer" {
		if !appRow.AssignedOfficerUserID.Valid || appRow.AssignedOfficerUserID.Bytes != callerUserID {
			return nil, status.Error(codes.PermissionDenied, "officer can only update assigned applications")
		}
	}
	if appRow.Status == generated.LoanApplicationStatusMANAGERAPPROVED || appRow.Status == generated.LoanApplicationStatusDISBURSED {
		return nil, status.Error(codes.FailedPrecondition, "loan terms cannot be updated after manager approval")
	}
	if req.GetTenureMonths() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "tenure_months must be > 0")
	}
	rate, err := parseNumeric(req.GetOfferedInterestRate(), "offered_interest_rate")
	if err != nil {
		return nil, err
	}
	rf, err := numericToFloat64(rate)
	if err != nil || rf < 0 || rf > 100 {
		return nil, status.Error(codes.InvalidArgument, "offered_interest_rate must be between 0 and 100")
	}
	updated, err := s.queries.UpdateLoanApplicationTerms(ctx, generated.UpdateLoanApplicationTermsParams{
		ID:                  appRow.ID,
		TenureMonths:        req.GetTenureMonths(),
		OfferedInterestRate: rate,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan terms")
	}
	return &loanv1.UpdateLoanApplicationTermsResponse{Application: mapLoanApplicationBase(updated, "", "")}, nil
}

func (s *service) AssignLoanApplicationOfficer(ctx context.Context, req *loanv1.AssignLoanApplicationOfficerRequest) (*loanv1.AssignLoanApplicationOfficerResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	officerUserID, err := parseUUID(req.GetOfficerUserId(), "officer_user_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan application not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan application")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	officerProfile, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(officerUserID))
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "officer profile not found")
	}
	if !officerProfile.BranchID.Valid || officerProfile.BranchID.Bytes != appRow.BranchID.Bytes {
		return nil, status.Error(codes.InvalidArgument, "officer must belong to the same branch as application")
	}
	if err := s.queries.AssignLoanApplicationOfficer(ctx, generated.AssignLoanApplicationOfficerParams{
		ID:                    appRow.ID,
		AssignedOfficerUserID: uuidToPg(officerUserID),
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to assign officer")
	}
	return &loanv1.AssignLoanApplicationOfficerResponse{Success: true}, nil
}

func (s *service) AddApplicationCoapplicant(ctx context.Context, req *loanv1.AddApplicationCoapplicantRequest) (*loanv1.AddApplicationCoapplicantResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	coBorrowerID, err := parseUUID(req.GetBorrowerProfileId(), "borrower_profile_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan application not found")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	consentAt := pgtype.Timestamptz{}
	if strings.TrimSpace(req.GetConsentAcceptedAt()) != "" {
		t, err := parseRFC3339(req.GetConsentAcceptedAt(), "consent_accepted_at")
		if err != nil {
			return nil, err
		}
		consentAt = pgTimestamptz(t)
	}
	row, err := s.queries.CreateApplicationCoapplicant(ctx, generated.CreateApplicationCoapplicantParams{
		ApplicationID:     appRow.ID,
		BorrowerProfileID: uuidToPg(coBorrowerID),
		Relationship:      toDBCoapplicantRelationship(req.GetRelationship()),
		ConsentAcceptedAt: consentAt,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to add coapplicant")
	}
	return &loanv1.AddApplicationCoapplicantResponse{Item: mapCoapplicant(row)}, nil
}

func (s *service) UpsertApplicationCollateral(ctx context.Context, req *loanv1.UpsertApplicationCollateralRequest) (*loanv1.UpsertApplicationCollateralResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan application not found")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}

	product, err := s.queries.GetLoanProductByID(ctx, appRow.LoanProductID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch loan product")
	}
	if product.Category == generated.LoanProductCategoryVEHICLE {
		return nil, status.Error(codes.FailedPrecondition, "manual collateral creation is not allowed for vehicle loans, use vehicle details instead")
	}

	estimated, err := parseNumeric(req.GetEstimatedValue(), "estimated_value")
	if err != nil {
		return nil, err
	}
	details := []byte("{}")
	if strings.TrimSpace(req.GetCollateralDetailsJson()) != "" {
		details = []byte(req.GetCollateralDetailsJson())
	}
	row, err := s.queries.UpsertApplicationCollateral(ctx, generated.UpsertApplicationCollateralParams{
		ApplicationID:      appRow.ID,
		AssetType:          toDBCollateralAssetType(req.GetAssetType()),
		EstimatedValue:     estimated,
		VerificationStatus: toDBCollateralVerificationStatus(req.GetVerificationStatus()),
		CollateralDetails:  details,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save collateral")
	}
	return &loanv1.UpsertApplicationCollateralResponse{Collateral: mapCollateral(row)}, nil
}

func (s *service) UpsertLoanVehicle(ctx context.Context, req *loanv1.UpsertLoanVehicleRequest) (*loanv1.UpsertLoanVehicleResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan application not found")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	price, err := parseNumeric(req.GetOnRoadPrice(), "on_road_price")
	if err != nil {
		return nil, err
	}
	row, err := s.queries.UpsertLoanVehicle(ctx, generated.UpsertLoanVehicleParams{
		ApplicationID:               appRow.ID,
		Make:                        req.GetMake(),
		Model:                       req.GetModel(),
		Variant:                     req.GetVariant(),
		ManufactureYear:             req.GetManufactureYear(),
		VehicleIdentificationNumber: req.GetVehicleIdentificationNumber(),
		EngineNumber:                req.GetEngineNumber(),
		InsuranceID:                 pgText(req.GetInsuranceId()),
		OnRoadPrice:                 price,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save vehicle details")
	}

	_, err = s.queries.UpsertApplicationCollateral(ctx, generated.UpsertApplicationCollateralParams{
		ApplicationID:      appRow.ID,
		AssetType:          generated.CollateralAssetTypeVEHICLE,
		EstimatedValue:     price,
		VerificationStatus: generated.CollateralVerificationStatusPENDING,
		CollateralDetails:  []byte("{}"),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to auto-create collateral for vehicle")
	}

	return &loanv1.UpsertLoanVehicleResponse{Vehicle: mapVehicle(row)}, nil
}

func (s *service) UpsertLoanRealEstate(ctx context.Context, req *loanv1.UpsertLoanRealEstateRequest) (*loanv1.UpsertLoanRealEstateResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan application not found")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	areaSqft, err := parseNumeric(req.GetAreaSqft(), "area_sqft")
	if err != nil {
		return nil, err
	}
	agreement, err := parseNumeric(req.GetAgreementValue(), "agreement_value")
	if err != nil {
		return nil, err
	}
	row, err := s.queries.UpsertLoanRealEstate(ctx, generated.UpsertLoanRealEstateParams{
		ApplicationID:      appRow.ID,
		PropType:           toDBPropertyType(req.GetPropType()),
		Status:             toDBPropertyStatus(req.GetStatus()),
		AddressLine1:       req.GetAddressLine_1(),
		Pincode:            req.GetPincode(),
		AreaSqft:           areaSqft,
		DeedDocumentNumber: pgText(req.GetDeedDocumentNumber()),
		AgreementValue:     agreement,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save real estate details")
	}
	return &loanv1.UpsertLoanRealEstateResponse{RealEstate: mapRealEstate(row)}, nil
}

func (s *service) AddApplicationDocument(ctx context.Context, req *loanv1.AddApplicationDocumentRequest) (*loanv1.AddApplicationDocumentResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	borrowerProfileID, err := parseUUID(req.GetBorrowerProfileId(), "borrower_profile_id")
	if err != nil {
		return nil, err
	}
	mediaFileID, err := parseUUID(req.GetMediaFileId(), "media_file_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan application not found")
	}
	if err := s.ensureCanAccessApplication(ctx, appRow.PrimaryBorrowerProfileID, appRow.BranchID, appRow.ID); err != nil {
		return nil, err
	}
	if _, err := s.queries.GetBorrowerProfileByID(ctx, uuidToPg(borrowerProfileID)); err != nil {
		return nil, status.Error(codes.InvalidArgument, "borrower_profile_id not found")
	}
	participantCheck, err := s.queries.IsApplicationBorrowerParticipant(ctx, generated.IsApplicationBorrowerParticipantParams{
		ID:                       appRow.ID,
		PrimaryBorrowerProfileID: uuidToPg(borrowerProfileID),
	})
	if err != nil {
		log.Printf("AddApplicationDocument: borrower participation check failed: %v", err)
		return nil, status.Error(codes.Internal, "failed to validate borrower participation")
	}
	if !participantCheck {
		return nil, status.Error(codes.InvalidArgument, "borrower_profile_id is not part of this application")
	}
	userID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := s.queries.GetActiveMediaFileByIDAndUser(ctx, generated.GetActiveMediaFileByIDAndUserParams{
		ID:     uuidToPg(mediaFileID),
		UserID: uuidToPg(userID),
	}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.InvalidArgument, "media_file_id not found for current user")
		}
		log.Printf("AddApplicationDocument: media file validation failed: %v", err)
		return nil, status.Error(codes.Internal, "failed to validate media file")
	}
	requiredDocID := pgtype.UUID{}
	if strings.TrimSpace(req.GetRequiredDocId()) != "" {
		docID, err := parseUUID(req.GetRequiredDocId(), "required_doc_id")
		if err != nil {
			return nil, err
		}
		if _, err := s.queries.GetProductRequiredDocumentByIDAndProduct(ctx, generated.GetProductRequiredDocumentByIDAndProductParams{
			ID:            uuidToPg(docID),
			LoanProductID: appRow.LoanProductID,
		}); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, status.Error(codes.InvalidArgument, "required_doc_id is not valid for this application product")
			}
			log.Printf("AddApplicationDocument: required document validation failed: %v", err)
			return nil, status.Error(codes.Internal, "failed to validate required document")
		}
		requiredDocID = uuidToPg(docID)
	}
	qualityFlags := req.GetQualityFlags()
	if qualityFlags == nil {
		qualityFlags = []string{}
	}
	row, err := s.queries.CreateApplicationDocument(ctx, generated.CreateApplicationDocumentParams{
		ApplicationID:      appRow.ID,
		BorrowerProfileID:  uuidToPg(borrowerProfileID),
		RequiredDocID:      requiredDocID,
		MediaFileID:        uuidToPg(mediaFileID),
		QualityFlags:       qualityFlags,
		VerificationStatus: toDBDocumentVerificationStatus(req.GetVerificationStatus()),
		RejectionReason:    pgtype.Text{},
	})
	if err != nil {
		log.Printf("AddApplicationDocument: document creation failed: %v", err)
		return nil, status.Error(codes.Internal, "failed to add document")
	}
	return &loanv1.AddApplicationDocumentResponse{Document: mapDocument(row)}, nil
}

func (s *service) UpdateApplicationDocumentVerification(ctx context.Context, req *loanv1.UpdateApplicationDocumentVerificationRequest) (*loanv1.UpdateApplicationDocumentVerificationResponse, error) {
	documentID, err := parseUUID(req.GetDocumentId(), "document_id")
	if err != nil {
		return nil, err
	}
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	doc, err := s.queries.GetApplicationDocumentByID(ctx, uuidToPg(documentID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "document not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch document")
	}

	if doc.VerificationStatus != generated.DocumentVerificationStatusPENDING {
		return nil, status.Error(codes.FailedPrecondition, "document verification status cannot be changed once set")
	}

	appRow, err := s.queries.GetLoanApplicationByID(ctx, doc.ApplicationID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch loan application")
	}

	switch role {
	case "admin":
	case "officer":
		if !appRow.AssignedOfficerUserID.Valid || appRow.AssignedOfficerUserID.Bytes != callerUserID {
			return nil, status.Error(codes.PermissionDenied, "only the assigned officer can verify documents")
		}
	case "manager":
		branch, bErr := s.branchForUserRole(ctx, callerUserID, role)
		if bErr != nil {
			return nil, bErr
		}
		if branch != uuid.UUID(appRow.BranchID.Bytes) {
			return nil, status.Error(codes.PermissionDenied, "manager can only verify documents in their branch")
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "only officers and managers can verify documents")
	}

	updated, err := s.queries.UpdateApplicationDocumentVerification(ctx, generated.UpdateApplicationDocumentVerificationParams{
		ID:                 uuidToPg(documentID),
		VerificationStatus: toDBDocumentVerificationStatus(req.GetVerificationStatus()),
		RejectionReason:    pgText(req.GetRejectionReason()),
		ReviewedByUserID:   uuidToPg(callerUserID),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update document verification")
	}
	return &loanv1.UpdateApplicationDocumentVerificationResponse{Document: mapDocument(updated)}, nil
}

func (s *service) AddBureauScore(ctx context.Context, req *loanv1.AddBureauScoreRequest) (*loanv1.AddBureauScoreResponse, error) {
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	borrowerProfileID, err := parseUUID(req.GetBorrowerProfileId(), "borrower_profile_id")
	if err != nil {
		return nil, err
	}
	expiresAt, err := parseRFC3339(req.GetExpiresAt(), "expires_at")
	if err != nil {
		return nil, err
	}
	if !expiresAt.After(time.Now().UTC()) {
		return nil, status.Error(codes.InvalidArgument, "expires_at must be in the future")
	}
	row, err := s.queries.CreateBureauScore(ctx, generated.CreateBureauScoreParams{
		BorrowerProfileID: uuidToPg(borrowerProfileID),
		ApplicationID:     uuidToPg(applicationID),
		Provider:          toDBBureauProvider(req.GetProvider()),
		Score:             req.GetScore(),
		FetchedAt:         pgNow(),
		ExpiresAt:         pgTimestamptz(expiresAt),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to add bureau score")
	}
	return &loanv1.AddBureauScoreResponse{Item: mapBureauScore(row)}, nil
}

func (s *service) CreateLoan(ctx context.Context, req *loanv1.CreateLoanRequest) (*loanv1.CreateLoanResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	applicationID, err := parseUUID(req.GetApplicationId(), "application_id")
	if err != nil {
		return nil, err
	}
	appRow, err := s.queries.GetLoanApplicationByID(ctx, uuidToPg(applicationID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan application not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch application")
	}

	// Permission checks
	switch role {
	case "admin":
		// Admins can do anything
	case "manager":
		branchID, err := s.branchForUserRole(ctx, callerUserID, role)
		if err != nil {
			return nil, err
		}
		if branchID != uuid.UUID(appRow.BranchID.Bytes) {
			return nil, status.Error(codes.PermissionDenied, "manager can only create loans for their own branch")
		}
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil {
			return nil, status.Error(codes.PermissionDenied, "borrower profile not found")
		}
		if profile.ID.Bytes != appRow.PrimaryBorrowerProfileID.Bytes {
			return nil, status.Error(codes.PermissionDenied, "only the primary borrower can accept and disburse the loan")
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "unauthorized to create loan")
	}

	if appRow.Status != generated.LoanApplicationStatusMANAGERAPPROVED {
		return nil, status.Error(codes.FailedPrecondition, "loan can be created only after manager approval")
	}
	approvedCount, err := s.queries.CountApprovedRequiredDocsByApplication(ctx, appRow.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check document approvals")
	}
	totalCount, err := s.queries.CountMandatoryRequiredDocsByApplication(ctx, appRow.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check required documents")
	}
	if approvedCount < totalCount {
		return nil, status.Errorf(codes.FailedPrecondition, "all mandatory documents must be approved before creating a loan (%d/%d approved)", approvedCount, totalCount)
	}
	if _, err := s.queries.GetLoanByApplicationID(ctx, appRow.ID); err == nil {
		return nil, status.Error(codes.FailedPrecondition, "loan already exists for this application")
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Error(codes.Internal, "failed to validate existing loan")
	}
	principal, err := parseNumeric(req.GetPrincipalAmount(), "principal_amount")
	if err != nil {
		return nil, err
	}
	if principal.Exp != appRow.RequestedAmount.Exp || string(principal.Int.Bytes()) != string(appRow.RequestedAmount.Int.Bytes()) {
		// Better way to compare pgtype.Numeric is via float conversion or using a helper
		pf, _ := numericToFloat64(principal)
		af, _ := numericToFloat64(appRow.RequestedAmount)
		if math.Abs(pf-af) > 0.01 {
			return nil, status.Errorf(codes.InvalidArgument, "principal_amount (%s) does not match the approved amount (%s)", req.GetPrincipalAmount(), numericToString(appRow.RequestedAmount))
		}
	}
	if !appRow.OfferedInterestRate.Valid {
		return nil, status.Error(codes.FailedPrecondition, "offered_interest_rate is not set on application")
	}
	rate := appRow.OfferedInterestRate
	principalF, err := numericToFloat64(principal)
	if err != nil || principalF <= 0 {
		return nil, status.Error(codes.InvalidArgument, "principal_amount must be > 0")
	}
	rateF, err := numericToFloat64(rate)
	if err != nil || rateF < 0 || rateF > 100 {
		return nil, status.Error(codes.FailedPrecondition, "invalid offered_interest_rate on application")
	}
	emiF := calculateReducingEMI(principalF, rateF, int(appRow.TenureMonths))
	emi, err := float64ToNumeric(emiF)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to compute emi")
	}
	outstanding := principal
	loanRow, err := s.queries.CreateLoan(ctx, generated.CreateLoanParams{
		ApplicationID:      uuidToPg(applicationID),
		PrincipalAmount:    principal,
		InterestRate:       rate,
		EmiAmount:          emi,
		OutstandingBalance: outstanding,
		Status:             toDBLoanStatus(req.GetStatus()),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create loan")
	}
	if err := s.queries.UpdateLoanApplicationStatus(ctx, generated.UpdateLoanApplicationStatusParams{
		ID:     appRow.ID,
		Status: generated.LoanApplicationStatusDISBURSED,
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to mark application disbursed")
	}
	if err := s.generateInitialEmiSchedule(ctx, loanRow.ID, loanRow.CreatedAt.Time.UTC(), int(appRow.TenureMonths), emi); err != nil {
		return nil, err
	}
	return &loanv1.CreateLoanResponse{Loan: mapLoan(loanRow)}, nil
}

func (s *service) GetLoan(ctx context.Context, req *loanv1.GetLoanRequest) (*loanv1.GetLoanResponse, error) {
	var (
		loanRow generated.Loan
		meta    generated.GetLoanByIDWithApplicationRow
		err     error
	)
	if strings.TrimSpace(req.GetLoanId()) != "" {
		loanID, parseErr := parseUUID(req.GetLoanId(), "loan_id")
		if parseErr != nil {
			return nil, parseErr
		}
		meta, err = s.queries.GetLoanByIDWithApplication(ctx, uuidToPg(loanID))
		if err == nil {
			loanRow = generated.Loan{
				ID:                 meta.ID,
				ApplicationID:      meta.ApplicationID,
				PrincipalAmount:    meta.PrincipalAmount,
				InterestRate:       meta.InterestRate,
				EmiAmount:          meta.EmiAmount,
				OutstandingBalance: meta.OutstandingBalance,
				Status:             meta.Status,
				CreatedAt:          meta.CreatedAt,
				UpdatedAt:          meta.UpdatedAt,
			}
		}
	} else if strings.TrimSpace(req.GetApplicationId()) != "" {
		applicationID, parseErr := parseUUID(req.GetApplicationId(), "application_id")
		if parseErr != nil {
			return nil, parseErr
		}
		rowByApp, qErr := s.queries.GetLoanByApplicationIDWithApplication(ctx, uuidToPg(applicationID))
		err = qErr
		if err == nil {
			meta = generated.GetLoanByIDWithApplicationRow{
				ID:                       rowByApp.ID,
				ApplicationID:            rowByApp.ApplicationID,
				PrincipalAmount:          rowByApp.PrincipalAmount,
				InterestRate:             rowByApp.InterestRate,
				EmiAmount:                rowByApp.EmiAmount,
				OutstandingBalance:       rowByApp.OutstandingBalance,
				Status:                   rowByApp.Status,
				CreatedAt:                rowByApp.CreatedAt,
				UpdatedAt:                rowByApp.UpdatedAt,
				PrimaryBorrowerProfileID: rowByApp.PrimaryBorrowerProfileID,
				BranchID:                 rowByApp.BranchID,
				AssignedOfficerUserID:    rowByApp.AssignedOfficerUserID,
			}
			loanRow = generated.Loan{
				ID:                 rowByApp.ID,
				ApplicationID:      rowByApp.ApplicationID,
				PrincipalAmount:    rowByApp.PrincipalAmount,
				InterestRate:       rowByApp.InterestRate,
				EmiAmount:          rowByApp.EmiAmount,
				OutstandingBalance: rowByApp.OutstandingBalance,
				Status:             rowByApp.Status,
				CreatedAt:          rowByApp.CreatedAt,
				UpdatedAt:          rowByApp.UpdatedAt,
			}
		}
	} else {
		return nil, status.Error(codes.InvalidArgument, "loan_id or application_id is required")
	}
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}
	if err := s.ensureCanAccessLoan(ctx, meta.PrimaryBorrowerProfileID, meta.BranchID, meta.AssignedOfficerUserID); err != nil {
		return nil, err
	}
	return &loanv1.GetLoanResponse{Loan: mapLoan(loanRow)}, nil
}

func (s *service) ListLoans(ctx context.Context, req *loanv1.ListLoansRequest) (*loanv1.ListLoansResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())
	var rows []generated.Loan
	switch role {
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil {
			return nil, status.Error(codes.FailedPrecondition, "borrower profile not found")
		}
		rows, err = s.queries.ListLoansForBorrowerProfile(ctx, generated.ListLoansForBorrowerProfileParams{
			PrimaryBorrowerProfileID: profile.ID,
			Limit:                    limit,
			Offset:                   offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loans")
		}
	case "officer":
		rows, err = s.queries.ListLoansForAssignedOfficer(ctx, generated.ListLoansForAssignedOfficerParams{
			AssignedOfficerUserID: uuidToPg(callerUserID),
			Limit:                 limit,
			Offset:                offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loans")
		}
	case "manager", "dst":
		branchID, err := s.branchForUserRole(ctx, callerUserID, role)
		if err != nil {
			return nil, err
		}
		rows, err = s.queries.ListLoansForBranch(ctx, generated.ListLoansForBranchParams{
			BranchID: uuidToPg(branchID),
			Limit:    limit,
			Offset:   offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loans")
		}
	case "admin":
		rows, err = s.queries.ListAllLoans(ctx, generated.ListAllLoansParams{Limit: limit, Offset: offset})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loans")
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "role cannot list loans")
	}
	items := make([]*loanv1.Loan, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapLoan(row))
	}
	return &loanv1.ListLoansResponse{Items: items}, nil
}

func (s *service) AddEmiScheduleItem(ctx context.Context, req *loanv1.AddEmiScheduleItemRequest) (*loanv1.AddEmiScheduleItemResponse, error) {
	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}
	loanMeta, err := s.queries.GetLoanByIDWithApplication(ctx, uuidToPg(loanID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}
	if err := s.ensureCanAccessLoan(ctx, loanMeta.PrimaryBorrowerProfileID, loanMeta.BranchID, loanMeta.AssignedOfficerUserID); err != nil {
		return nil, err
	}
	dueDate, err := parseDate(req.GetDueDate(), "due_date")
	if err != nil {
		return nil, err
	}
	amount, err := parseNumeric(req.GetEmiAmount(), "emi_amount")
	if err != nil {
		return nil, err
	}
	row, err := s.queries.CreateEmiScheduleItem(ctx, generated.CreateEmiScheduleItemParams{
		LoanID:            uuidToPg(loanID),
		InstallmentNumber: req.GetInstallmentNumber(),
		DueDate:           dueDate,
		EmiAmount:         amount,
		Status:            toDBEmiStatus(req.GetStatus()),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create emi schedule item")
	}
	return &loanv1.AddEmiScheduleItemResponse{Item: mapEmi(row)}, nil
}

func (s *service) ListEmiSchedule(ctx context.Context, req *loanv1.ListEmiScheduleRequest) (*loanv1.ListEmiScheduleResponse, error) {
	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}
	loanMeta, err := s.queries.GetLoanByIDWithApplication(ctx, uuidToPg(loanID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}
	if err := s.ensureCanAccessLoan(ctx, loanMeta.PrimaryBorrowerProfileID, loanMeta.BranchID, loanMeta.AssignedOfficerUserID); err != nil {
		return nil, err
	}
	rows, err := s.queries.ListEmiScheduleByLoanID(ctx, uuidToPg(loanID))
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list emi schedule")
	}
	items := make([]*loanv1.EmiScheduleItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapEmi(row))
	}
	return &loanv1.ListEmiScheduleResponse{Items: items}, nil
}

func (s *service) RecordPayment(ctx context.Context, req *loanv1.RecordPaymentRequest) (*loanv1.RecordPaymentResponse, error) {
	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}
	loanRow, err := s.queries.GetLoanByIDWithApplication(ctx, uuidToPg(loanID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}
	if err := s.ensureCanAccessLoan(ctx, loanRow.PrimaryBorrowerProfileID, loanRow.BranchID, loanRow.AssignedOfficerUserID); err != nil {
		return nil, err
	}
	amount, err := parseNumeric(req.GetAmount(), "amount")
	if err != nil {
		return nil, err
	}
	amountF, _ := numericToFloat64(amount)

	emiScheduleID := pgtype.UUID{}
	if strings.TrimSpace(req.GetEmiScheduleId()) != "" {
		id, err := parseUUID(req.GetEmiScheduleId(), "emi_schedule_id")
		if err != nil {
			return nil, err
		}
		emiRow, err := s.queries.GetEmiScheduleByID(ctx, uuidToPg(id))
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, status.Error(codes.InvalidArgument, "emi_schedule_id not found")
			}
			return nil, status.Error(codes.Internal, "failed to validate emi schedule")
		}
		if emiRow.LoanID != uuidToPg(loanID) {
			return nil, status.Error(codes.InvalidArgument, "emi_schedule_id does not belong to loan_id")
		}
		// Validate amount matches schedule
		emiAmountF, _ := numericToFloat64(emiRow.EmiAmount)
		if math.Abs(amountF-emiAmountF) > 0.01 {
			return nil, status.Error(codes.InvalidArgument, "payment amount must match emi amount for scheduled payments")
		}
		emiScheduleID = uuidToPg(id)

		// Mark EMI as paid
		if err := s.queries.UpdateEmiScheduleStatus(ctx, generated.UpdateEmiScheduleStatusParams{
			ID:     emiScheduleID,
			Status: generated.EmiStatusPAID,
		}); err != nil {
			return nil, status.Error(codes.Internal, "failed to update emi status")
		}
	}

	externalID := strings.TrimSpace(req.GetExternalTransactionId())
	if externalID == "" {
		return nil, status.Error(codes.InvalidArgument, "external_transaction_id is required")
	}

	paymentRow, err := s.queries.CreatePayment(ctx, generated.CreatePaymentParams{
		LoanID:                uuidToPg(loanID),
		EmiScheduleID:         emiScheduleID,
		Amount:                amount,
		ExternalTransactionID: externalID,
		Status:                toDBPaymentStatus(req.GetStatus()),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to record payment")
	}

	// Update loan balance
	outstandingF, _ := numericToFloat64(loanRow.OutstandingBalance)
	newOutstandingF := outstandingF - amountF
	if newOutstandingF < 0 {
		newOutstandingF = 0
	}
	newOutstanding, _ := float64ToNumeric(newOutstandingF)

	if req.GetStatus() == loanv1.PaymentStatus_PAYMENT_STATUS_SUCCESS {
		err = s.queries.UpdateLoanStatusAndOutstanding(ctx, generated.UpdateLoanStatusAndOutstandingParams{
			ID:                 uuidToPg(loanID),
			Status:             loanRow.Status,
			OutstandingBalance: newOutstanding,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update loan balance")
		}

		// If unscheduled (part-payment), recalculate tenure and truncate schedule
		if !emiScheduleID.Valid {
			rateF, _ := numericToFloat64(loanRow.InterestRate)
			emiAmountF, _ := numericToFloat64(loanRow.EmiAmount)
			newTenure := calculateRemainingTenure(newOutstandingF, rateF, emiAmountF)

			// Truncate and regenerate future schedule
			if err := s.queries.DeleteUpcomingEmiSchedulesByLoanID(ctx, uuidToPg(loanID)); err != nil {
				return nil, status.Error(codes.Internal, "failed to clear future schedule")
			}

			// Find last installment
			rows, _ := s.queries.ListEmiScheduleByLoanID(ctx, uuidToPg(loanID))
			lastNum := int32(0)
			lastDate := time.Now().UTC()
			for _, r := range rows {
				if r.InstallmentNumber > lastNum {
					lastNum = r.InstallmentNumber
					lastDate = r.DueDate.Time
				}
			}

			for i := 1; i <= newTenure; i++ {
				dueDate := lastDate.AddDate(0, i, 0)
				s.queries.CreateEmiScheduleItem(ctx, generated.CreateEmiScheduleItemParams{
					LoanID:            uuidToPg(loanID),
					InstallmentNumber: lastNum + int32(i),
					DueDate:           pgtype.Date{Time: dueDate, Valid: true},
					EmiAmount:         loanRow.EmiAmount,
					Status:            generated.EmiStatusUPCOMING,
				})
			}
		}
	}

	return &loanv1.RecordPaymentResponse{Payment: mapPayment(paymentRow)}, nil
}

func (s *service) ListPayments(ctx context.Context, req *loanv1.ListPaymentsRequest) (*loanv1.ListPaymentsResponse, error) {
	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}
	loanMeta, err := s.queries.GetLoanByIDWithApplication(ctx, uuidToPg(loanID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}
	if err := s.ensureCanAccessLoan(ctx, loanMeta.PrimaryBorrowerProfileID, loanMeta.BranchID, loanMeta.AssignedOfficerUserID); err != nil {
		return nil, err
	}
	rows, err := s.queries.ListPaymentsByLoanID(ctx, uuidToPg(loanID))
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list payments")
	}
	items := make([]*loanv1.Payment, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapPayment(row))
	}
	return &loanv1.ListPaymentsResponse{Items: items}, nil
}

func (s *service) ensureCanAccessApplication(ctx context.Context, primaryBorrowerProfileID pgtype.UUID, branchID pgtype.UUID, applicationID pgtype.UUID) error {
	userID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return err
	}
	switch role {
	case "admin":
		return nil
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(userID))
		if err != nil {
			return status.Error(codes.PermissionDenied, "borrower profile not found")
		}

		// Check if primary borrower
		if profile.ID.Bytes == primaryBorrowerProfileID.Bytes {
			return nil
		}

		// Check if co-applicant
		isParticipant, err := s.queries.IsApplicationBorrowerParticipant(ctx, generated.IsApplicationBorrowerParticipantParams{
			ID:                       applicationID,
			PrimaryBorrowerProfileID: profile.ID,
		})
		if err != nil || !isParticipant {
			return status.Error(codes.PermissionDenied, "borrower is not a participant in this application")
		}
		return nil
	case "dst", "officer", "manager":
		branch, err := s.branchForUserRole(ctx, userID, role)
		if err != nil {
			return err
		}
		if branch != uuid.UUID(branchID.Bytes) {
			return status.Error(codes.PermissionDenied, "cannot access applications outside your branch")
		}
		return nil
	default:
		return status.Error(codes.PermissionDenied, "access denied")
	}
}

func (s *service) ensureCanAccessLoan(ctx context.Context, borrowerProfileID pgtype.UUID, branchID pgtype.UUID, assignedOfficerUserID pgtype.UUID) error {
	userID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return err
	}
	switch role {
	case "admin":
		return nil
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(userID))
		if err != nil || profile.ID.Bytes != borrowerProfileID.Bytes {
			return status.Error(codes.PermissionDenied, "borrower can only access own loans")
		}
		return nil
	case "officer":
		if !assignedOfficerUserID.Valid || assignedOfficerUserID.Bytes != userID {
			return status.Error(codes.PermissionDenied, "officer can only access assigned loans")
		}
		return nil
	case "manager", "dst":
		branch, err := s.branchForUserRole(ctx, userID, role)
		if err != nil {
			return err
		}
		if branch != uuid.UUID(branchID.Bytes) {
			return status.Error(codes.PermissionDenied, "cannot access loans outside your branch")
		}
		return nil
	default:
		return status.Error(codes.PermissionDenied, "access denied")
	}
}

func validateApplicationStatusTransition(from, to generated.LoanApplicationStatus, role string) error {
	if from == to {
		return nil
	}
	switch role {
	case "admin":
		return nil
	case "officer":
		switch from {
		case generated.LoanApplicationStatusDRAFT:
			if to == generated.LoanApplicationStatusSUBMITTED || to == generated.LoanApplicationStatusOFFICERREVIEW {
				return nil
			}
		case generated.LoanApplicationStatusSUBMITTED:
			if to == generated.LoanApplicationStatusOFFICERREVIEW || to == generated.LoanApplicationStatusOFFICERREJECTED {
				return nil
			}
		case generated.LoanApplicationStatusOFFICERREVIEW:
			if to == generated.LoanApplicationStatusOFFICERAPPROVED || to == generated.LoanApplicationStatusOFFICERREJECTED {
				return nil
			}
		case generated.LoanApplicationStatusOFFICERAPPROVED:
			if to == generated.LoanApplicationStatusMANAGERREVIEW {
				return nil
			}
		}
		return status.Error(codes.FailedPrecondition, "invalid officer status transition")
	case "manager":
		switch from {
		case generated.LoanApplicationStatusOFFICERAPPROVED:
			if to == generated.LoanApplicationStatusMANAGERREVIEW || to == generated.LoanApplicationStatusMANAGERAPPROVED || to == generated.LoanApplicationStatusMANAGERREJECTED {
				return nil
			}
		case generated.LoanApplicationStatusMANAGERREVIEW:
			if to == generated.LoanApplicationStatusMANAGERAPPROVED || to == generated.LoanApplicationStatusMANAGERREJECTED {
				return nil
			}
		}
		return status.Error(codes.FailedPrecondition, "invalid manager status transition")
	case "dst":
		switch from {
		case generated.LoanApplicationStatusDRAFT, generated.LoanApplicationStatusSUBMITTED:
			if to == generated.LoanApplicationStatusCANCELLED {
				return nil
			}
		}
		return status.Error(codes.FailedPrecondition, "invalid dst status transition")
	default:
		return status.Error(codes.PermissionDenied, "role cannot update status")
	}
}

func (s *service) branchForUserRole(ctx context.Context, userID uuid.UUID, role string) (uuid.UUID, error) {
	switch role {
	case "dst":
		p, err := s.queries.GetDstProfileByUserID(ctx, uuidToPg(userID))
		if err != nil {
			return uuid.UUID{}, status.Error(codes.FailedPrecondition, "dst profile not found")
		}
		return uuid.UUID(p.BranchID.Bytes), nil
	case "officer":
		p, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(userID))
		if err != nil || !p.BranchID.Valid {
			return uuid.UUID{}, status.Error(codes.FailedPrecondition, "officer is not assigned to a branch")
		}
		return uuid.UUID(p.BranchID.Bytes), nil
	case "manager":
		p, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(userID))
		if err != nil || !p.BranchID.Valid {
			return uuid.UUID{}, status.Error(codes.FailedPrecondition, "manager is not assigned to a branch")
		}
		return uuid.UUID(p.BranchID.Bytes), nil
	default:
		return uuid.UUID{}, status.Error(codes.PermissionDenied, "role does not have branch scope")
	}
}

func buildCreateLoanProductParams(req *loanv1.CreateLoanProductRequest) (generated.CreateLoanProductParams, error) {
	baseRate, err := parseNumeric(req.GetBaseInterestRate(), "base_interest_rate")
	if err != nil {
		return generated.CreateLoanProductParams{}, err
	}
	minAmount, err := parseNumeric(req.GetMinAmount(), "min_amount")
	if err != nil {
		return generated.CreateLoanProductParams{}, err
	}
	maxAmount, err := parseNumeric(req.GetMaxAmount(), "max_amount")
	if err != nil {
		return generated.CreateLoanProductParams{}, err
	}
	name := strings.TrimSpace(req.GetName())
	if name == "" {
		return generated.CreateLoanProductParams{}, status.Error(codes.InvalidArgument, "name is required")
	}
	return generated.CreateLoanProductParams{
		Name:                  name,
		Category:              toDBProductCategory(req.GetCategory()),
		InterestType:          toDBInterestType(req.GetInterestType()),
		BaseInterestRate:      baseRate,
		MinAmount:             minAmount,
		MaxAmount:             maxAmount,
		IsRequiringCollateral: req.GetIsRequiringCollateral(),
		IsActive:              req.GetIsActive(),
	}, nil
}

func buildUpdateLoanProductParams(productID uuid.UUID, req *loanv1.UpdateLoanProductRequest) (generated.UpdateLoanProductParams, error) {
	baseRate, err := parseNumeric(req.GetBaseInterestRate(), "base_interest_rate")
	if err != nil {
		return generated.UpdateLoanProductParams{}, err
	}
	minAmount, err := parseNumeric(req.GetMinAmount(), "min_amount")
	if err != nil {
		return generated.UpdateLoanProductParams{}, err
	}
	maxAmount, err := parseNumeric(req.GetMaxAmount(), "max_amount")
	if err != nil {
		return generated.UpdateLoanProductParams{}, err
	}
	name := strings.TrimSpace(req.GetName())
	if name == "" {
		return generated.UpdateLoanProductParams{}, status.Error(codes.InvalidArgument, "name is required")
	}
	return generated.UpdateLoanProductParams{
		ID:                    uuidToPg(productID),
		Name:                  name,
		Category:              toDBProductCategory(req.GetCategory()),
		InterestType:          toDBInterestType(req.GetInterestType()),
		BaseInterestRate:      baseRate,
		MinAmount:             minAmount,
		MaxAmount:             maxAmount,
		IsRequiringCollateral: req.GetIsRequiringCollateral(),
		IsActive:              req.GetIsActive(),
	}, nil
}

func mapLoanProduct(row generated.LoanProduct, rule *generated.ProductEligibilityRule, fees []generated.ProductFee, docs []generated.ProductRequiredDocument) *loanv1.LoanProduct {
	product := &loanv1.LoanProduct{
		Id:                    row.ID.String(),
		Name:                  row.Name,
		Category:              toProtoProductCategory(row.Category),
		InterestType:          toProtoInterestType(row.InterestType),
		BaseInterestRate:      numericToString(row.BaseInterestRate),
		MinAmount:             numericToString(row.MinAmount),
		MaxAmount:             numericToString(row.MaxAmount),
		IsRequiringCollateral: row.IsRequiringCollateral,
		IsActive:              row.IsActive,
		IsDeleted:             row.IsDeleted,
		CreatedAt:             timeToString(row.CreatedAt),
		UpdatedAt:             timeToString(row.UpdatedAt),
	}
	if rule != nil && rule.ID.Valid {
		product.EligibilityRule = mapEligibilityRule(*rule)
	}
	for _, fee := range fees {
		product.Fees = append(product.Fees, mapProductFee(fee))
	}
	for _, doc := range docs {
		product.RequiredDocuments = append(product.RequiredDocuments, mapRequiredDocument(doc))
	}
	return product
}

func mapEligibilityRule(row generated.ProductEligibilityRule) *loanv1.ProductEligibilityRule {
	return &loanv1.ProductEligibilityRule{
		Id:                     row.ID.String(),
		MinAge:                 row.MinAge,
		MinMonthlyIncome:       numericToString(row.MinMonthlyIncome),
		MinBureauScore:         row.MinBureauScore,
		AllowedEmploymentTypes: row.AllowedEmploymentTypes,
	}
}

func mapProductFee(row generated.ProductFee) *loanv1.ProductFee {
	return &loanv1.ProductFee{
		Id:         row.ID.String(),
		Type:       toProtoFeeType(row.FeeType),
		CalcMethod: toProtoFeeCalcMethod(row.CalcMethod),
		Value:      numericToString(row.Value),
	}
}

func mapRequiredDocument(row generated.ProductRequiredDocument) *loanv1.ProductRequiredDocument {
	return &loanv1.ProductRequiredDocument{
		Id:              row.ID.String(),
		RequirementType: toProtoRequirementType(row.RequirementType),
		IsMandatory:     row.IsMandatory,
	}
}

func mapLoanApplicationBase(row generated.LoanApplication, productName, branchName string) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          productName,
		BranchId:                 row.BranchID.String(),
		BranchName:               branchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationView(row generated.GetLoanApplicationViewByIDRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationRowForBorrower(row generated.ListLoanApplicationsForBorrowerProfileRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationRowForBranch(row generated.ListLoanApplicationsByBranchIDRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationRowForAdmin(row generated.ListAllLoanApplicationsRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationRowForOfficer(row generated.ListLoanApplicationsByAssignedOfficerRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapLoanApplicationRowForDst(row generated.ListLoanApplicationsByCreatedByUserIDRow) *loanv1.LoanApplication {
	return &loanv1.LoanApplication{
		Id:                       row.ID.String(),
		ReferenceNumber:          row.ReferenceNumber,
		PrimaryBorrowerProfileId: row.PrimaryBorrowerProfileID.String(),
		LoanProductId:            row.LoanProductID.String(),
		LoanProductName:          row.ProductName,
		BranchId:                 row.BranchID.String(),
		BranchName:               row.BranchName,
		RequestedAmount:          numericToString(row.RequestedAmount),
		TenureMonths:             row.TenureMonths,
		Status:                   toProtoApplicationStatus(row.Status),
		AssignedOfficerUserId:    row.AssignedOfficerUserID.String(),
		EscalationReason:         textToString(row.EscalationReason),
		CreatedByUserId:          row.CreatedByUserID.String(),
		CreatedByRole:            string(row.CreatedByRole),
		CreatedByChannel:         toProtoCreatedByChannel(row.CreatedByChannel),
		CreatedAt:                timeToString(row.CreatedAt),
		UpdatedAt:                timeToString(row.UpdatedAt),
		ProductSnapshotJson:      string(row.ProductSnapshotJson),
		OfferedInterestRate:           numericToString(row.OfferedInterestRate),
		DisbursementAccountNumber:     textToString(row.DisbursementAccountNumber),
		DisbursementIfscCode:          textToString(row.DisbursementIfscCode),
		DisbursementBankName:          textToString(row.DisbursementBankName),
		DisbursementAccountHolderName: textToString(row.DisbursementAccountHolderName),
	}
}

func mapCoapplicants(rows []generated.ApplicationCoapplicant) []*loanv1.ApplicationCoapplicant {
	items := make([]*loanv1.ApplicationCoapplicant, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapCoapplicant(row))
	}
	return items
}

func mapCoapplicant(row generated.ApplicationCoapplicant) *loanv1.ApplicationCoapplicant {
	return &loanv1.ApplicationCoapplicant{
		Id:                row.ID.String(),
		ApplicationId:     row.ApplicationID.String(),
		BorrowerProfileId: row.BorrowerProfileID.String(),
		Relationship:      toProtoCoapplicantRelationship(row.Relationship),
		ConsentAcceptedAt: timeToString(row.ConsentAcceptedAt),
		CreatedAt:         timeToString(row.CreatedAt),
	}
}

func mapCollateral(row generated.ApplicationCollateral) *loanv1.ApplicationCollateral {
	return &loanv1.ApplicationCollateral{
		Id:                    row.ID.String(),
		ApplicationId:         row.ApplicationID.String(),
		AssetType:             toProtoCollateralAssetType(row.AssetType),
		EstimatedValue:        numericToString(row.EstimatedValue),
		VerificationStatus:    toProtoCollateralVerificationStatus(row.VerificationStatus),
		CollateralDetailsJson: string(row.CollateralDetails),
		CreatedAt:             timeToString(row.CreatedAt),
		UpdatedAt:             timeToString(row.UpdatedAt),
	}
}

func mapVehicle(row generated.LoanVehicle) *loanv1.LoanVehicle {
	return &loanv1.LoanVehicle{
		Id:                          row.ID.String(),
		ApplicationId:               row.ApplicationID.String(),
		Make:                        row.Make,
		Model:                       row.Model,
		Variant:                     row.Variant,
		ManufactureYear:             row.ManufactureYear,
		VehicleIdentificationNumber: row.VehicleIdentificationNumber,
		EngineNumber:                row.EngineNumber,
		InsuranceId:                 textToString(row.InsuranceID),
		OnRoadPrice:                 numericToString(row.OnRoadPrice),
		CreatedAt:                   timeToString(row.CreatedAt),
		UpdatedAt:                   timeToString(row.UpdatedAt),
	}
}

func mapRealEstate(row generated.LoanRealEstate) *loanv1.LoanRealEstate {
	return &loanv1.LoanRealEstate{
		Id:                 row.ID.String(),
		ApplicationId:      row.ApplicationID.String(),
		PropType:           toProtoPropertyType(row.PropType),
		Status:             toProtoPropertyStatus(row.Status),
		AddressLine_1:      row.AddressLine1,
		Pincode:            row.Pincode,
		AreaSqft:           numericToString(row.AreaSqft),
		DeedDocumentNumber: textToString(row.DeedDocumentNumber),
		AgreementValue:     numericToString(row.AgreementValue),
		CreatedAt:          timeToString(row.CreatedAt),
		UpdatedAt:          timeToString(row.UpdatedAt),
	}
}

func mapDocuments(rows []generated.ApplicationDocument) []*loanv1.ApplicationDocument {
	items := make([]*loanv1.ApplicationDocument, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapDocument(row))
	}
	return items
}

func mapDocument(row generated.ApplicationDocument) *loanv1.ApplicationDocument {
	return &loanv1.ApplicationDocument{
		Id:                 row.ID.String(),
		ApplicationId:      row.ApplicationID.String(),
		BorrowerProfileId:  row.BorrowerProfileID.String(),
		RequiredDocId:      row.RequiredDocID.String(),
		MediaFileId:        row.MediaFileID.String(),
		QualityFlags:       row.QualityFlags,
		VerificationStatus: toProtoDocumentVerificationStatus(row.VerificationStatus),
		RejectionReason:    textToString(row.RejectionReason),
		CreatedAt:          timeToString(row.CreatedAt),
		UpdatedAt:          timeToString(row.UpdatedAt),
		ReviewedByUserId:   nullableUUIDToString(row.ReviewedByUserID),
		ReviewedAt:         timeToString(row.ReviewedAt),
	}
}

func buildProductSnapshotJSON(product generated.LoanProduct) string {
	payload := map[string]any{
		"id":                      product.ID.String(),
		"name":                    product.Name,
		"category":                string(product.Category),
		"interest_type":           string(product.InterestType),
		"base_interest_rate":      numericToString(product.BaseInterestRate),
		"min_amount":              numericToString(product.MinAmount),
		"max_amount":              numericToString(product.MaxAmount),
		"is_requiring_collateral": product.IsRequiringCollateral,
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return "{}"
	}
	return string(b)
}

func mapBureauScores(rows []generated.BureauScore) []*loanv1.BureauScore {
	items := make([]*loanv1.BureauScore, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapBureauScore(row))
	}
	return items
}

func mapBureauScore(row generated.BureauScore) *loanv1.BureauScore {
	return &loanv1.BureauScore{
		Id:                row.ID.String(),
		BorrowerProfileId: row.BorrowerProfileID.String(),
		ApplicationId:     row.ApplicationID.String(),
		Provider:          toProtoBureauProvider(row.Provider),
		Score:             row.Score,
		FetchedAt:         timeToString(row.FetchedAt),
		ExpiresAt:         timeToString(row.ExpiresAt),
	}
}

func mapLoan(row generated.Loan) *loanv1.Loan {
	return &loanv1.Loan{
		Id:                 row.ID.String(),
		ApplicationId:      row.ApplicationID.String(),
		PrincipalAmount:    numericToString(row.PrincipalAmount),
		InterestRate:       numericToString(row.InterestRate),
		EmiAmount:          numericToString(row.EmiAmount),
		OutstandingBalance: numericToString(row.OutstandingBalance),
		Status:             toProtoLoanStatus(row.Status),
		CreatedAt:          timeToString(row.CreatedAt),
		UpdatedAt:          timeToString(row.UpdatedAt),
	}
}

func mapEmi(row generated.EmiSchedule) *loanv1.EmiScheduleItem {
	return &loanv1.EmiScheduleItem{
		Id:                row.ID.String(),
		LoanId:            row.LoanID.String(),
		InstallmentNumber: row.InstallmentNumber,
		DueDate:           dateToString(row.DueDate),
		EmiAmount:         numericToString(row.EmiAmount),
		Status:            toProtoEmiStatus(row.Status),
	}
}

func mapPayment(row generated.Payment) *loanv1.Payment {
	return &loanv1.Payment{
		Id:                    row.ID.String(),
		LoanId:                row.LoanID.String(),
		EmiScheduleId:         row.EmiScheduleID.String(),
		Amount:                numericToString(row.Amount),
		ExternalTransactionId: row.ExternalTransactionID,
		Status:                toProtoPaymentStatus(row.Status),
		CreatedAt:             timeToString(row.CreatedAt),
	}
}

func parseUUID(v, field string) (uuid.UUID, error) {
	value := strings.TrimSpace(v)
	if value == "" {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "%s is required", field)
	}
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "%s must be a valid uuid", field)
	}
	return id, nil
}

func parseNumeric(v, field string) (pgtype.Numeric, error) {
	value := strings.TrimSpace(v)
	if value == "" {
		return pgtype.Numeric{}, status.Errorf(codes.InvalidArgument, "%s is required", field)
	}
	var out pgtype.Numeric
	if err := out.Scan(value); err != nil {
		return pgtype.Numeric{}, status.Errorf(codes.InvalidArgument, "%s must be a decimal string", field)
	}
	return out, nil
}

func parseRFC3339(v, field string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, strings.TrimSpace(v))
	if err != nil {
		return time.Time{}, status.Errorf(codes.InvalidArgument, "%s must be RFC3339", field)
	}
	return t.UTC(), nil
}

func parseDate(v, field string) (pgtype.Date, error) {
	t, err := time.Parse("2006-01-02", strings.TrimSpace(v))
	if err != nil {
		return pgtype.Date{}, status.Errorf(codes.InvalidArgument, "%s must be YYYY-MM-DD", field)
	}
	return pgtype.Date{Time: t, Valid: true}, nil
}

func requireUserAndRole(ctx context.Context) (uuid.UUID, string, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user context")
	}
	role, ok := ctx.Value(interceptors.ContextRoleKey).(string)
	if !ok || strings.TrimSpace(role) == "" {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user role")
	}
	return userID, role, nil
}

func deriveCreatedByChannel(role string) generated.ApplicationCreatedByChannel {
	switch role {
	case "borrower":
		return generated.ApplicationCreatedByChannelSELF
	case "dst":
		return generated.ApplicationCreatedByChannelDST
	case "officer":
		return generated.ApplicationCreatedByChannelOFFICER
	default:
		return generated.ApplicationCreatedByChannel("")
	}
}

func generateReferenceNumber() string {
	return "LMS-" + strings.ToUpper(strings.ReplaceAll(uuid.NewString()[:8], "-", ""))
}

func normalizePagination(limit, offset int32) (int32, int32) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}

func ageFromDate(dob time.Time) int {
	if dob.IsZero() {
		return 0
	}
	now := time.Now().UTC()
	years := now.Year() - dob.Year()
	if now.Month() < dob.Month() || (now.Month() == dob.Month() && now.Day() < dob.Day()) {
		years--
	}
	return years
}

func containsFold(values []string, target string) bool {
	for _, v := range values {
		if strings.EqualFold(strings.TrimSpace(v), strings.TrimSpace(target)) {
			return true
		}
	}
	return false
}

func numericPair(a, b pgtype.Numeric) (float64, float64, error) {
	af, err := a.Float64Value()
	if err != nil || !af.Valid {
		return 0, 0, errors.New("invalid first numeric")
	}
	bf, err := b.Float64Value()
	if err != nil || !bf.Valid {
		return 0, 0, errors.New("invalid second numeric")
	}
	return af.Float64, bf.Float64, nil
}

func numericTriplet(a, b, c pgtype.Numeric) (float64, float64, float64, error) {
	af, err := a.Float64Value()
	if err != nil || !af.Valid {
		return 0, 0, 0, errors.New("invalid first numeric")
	}
	bf, err := b.Float64Value()
	if err != nil || !bf.Valid {
		return 0, 0, 0, errors.New("invalid second numeric")
	}
	cf, err := c.Float64Value()
	if err != nil || !cf.Valid {
		return 0, 0, 0, errors.New("invalid third numeric")
	}
	return af.Float64, bf.Float64, cf.Float64, nil
}

func uuidToPg(v uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: v, Valid: true}
}

func pgText(v string) pgtype.Text {
	value := strings.TrimSpace(v)
	if value == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: value, Valid: true}
}

func nullableUUIDToString(v pgtype.UUID) string {
	if !v.Valid {
		return ""
	}
	return uuid.UUID(v.Bytes).String()
}

func pgTimestamptz(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t.UTC(), Valid: true}
}

func pgNow() pgtype.Timestamptz {
	return pgTimestamptz(time.Now().UTC())
}

func timeToString(v pgtype.Timestamptz) string {
	if !v.Valid {
		return ""
	}
	return v.Time.UTC().Format(time.RFC3339)
}

func dateToString(v pgtype.Date) string {
	if !v.Valid {
		return ""
	}
	return v.Time.UTC().Format("2006-01-02")
}

func numericToString(v pgtype.Numeric) string {
	if !v.Valid {
		return ""
	}
	raw, err := v.Value()
	if err == nil {
		switch t := raw.(type) {
		case string:
			return t
		case []byte:
			return string(t)
		}
	}
	f, err := v.Float64Value()
	if err != nil || !f.Valid {
		return ""
	}
	return strconv.FormatFloat(f.Float64, 'f', -1, 64)
}

func numericToFloat64(v pgtype.Numeric) (float64, error) {
	f, err := v.Float64Value()
	if err != nil || !f.Valid {
		return 0, errors.New("invalid numeric")
	}
	return f.Float64, nil
}

func float64ToNumeric(v float64) (pgtype.Numeric, error) {
	s := strconv.FormatFloat(v, 'f', 2, 64)
	var out pgtype.Numeric
	if err := out.Scan(s); err != nil {
		return pgtype.Numeric{}, err
	}
	return out, nil
}

func calculateReducingEMI(principal, annualRate float64, tenureMonths int) float64 {
	if tenureMonths <= 0 {
		return 0
	}
	if annualRate <= 0 {
		return round2(principal / float64(tenureMonths))
	}
	monthlyRate := (annualRate / 12.0) / 100.0
	pow := math.Pow(1+monthlyRate, float64(tenureMonths))
	emi := principal * monthlyRate * pow / (pow - 1)
	return round2(emi)
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

func calculateRemainingTenure(principal, annualRate, emi float64) int {
	if principal <= 0 || emi <= 0 {
		return 0
	}
	if annualRate <= 0 {
		return int(math.Ceil(principal / emi))
	}
	monthlyRate := (annualRate / 12.0) / 100.0
	// n = -log(1 - (P*r)/E) / log(1+r)
	val := 1 - (principal*monthlyRate)/emi
	if val <= 0 {
		return 1 // Should not happen with sane inputs, but ensures we don't log(<=0)
	}
	n := -math.Log(val) / math.Log(1+monthlyRate)
	return int(math.Ceil(n))
}

func (s *service) generateInitialEmiSchedule(ctx context.Context, loanID pgtype.UUID, startDate time.Time, tenureMonths int, emiAmount pgtype.Numeric) error {
	if tenureMonths <= 0 {
		return status.Error(codes.FailedPrecondition, "tenure_months must be > 0")
	}
	for i := 1; i <= tenureMonths; i++ {
		dueDate := time.Date(startDate.Year(), startDate.Month(), startDate.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, i, 0)
		if _, err := s.queries.CreateEmiScheduleItem(ctx, generated.CreateEmiScheduleItemParams{
			LoanID:            loanID,
			InstallmentNumber: int32(i),
			DueDate:           pgtype.Date{Time: dueDate, Valid: true},
			EmiAmount:         emiAmount,
			Status:            generated.EmiStatusUPCOMING,
		}); err != nil {
			return status.Error(codes.Internal, "failed to generate emi schedule")
		}
	}
	return nil
}

func textToString(v pgtype.Text) string {
	if !v.Valid {
		return ""
	}
	return v.String
}

func toDBProductCategory(v loanv1.LoanProductCategory) generated.LoanProductCategory {
	switch v {
	case loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_PERSONAL:
		return generated.LoanProductCategoryPERSONAL
	case loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_HOME:
		return generated.LoanProductCategoryHOME
	case loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_VEHICLE:
		return generated.LoanProductCategoryVEHICLE
	case loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_EDUCATION:
		return generated.LoanProductCategoryEDUCATION
	default:
		return generated.LoanProductCategoryPERSONAL
	}
}

func toProtoProductCategory(v generated.LoanProductCategory) loanv1.LoanProductCategory {
	switch v {
	case generated.LoanProductCategoryPERSONAL:
		return loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_PERSONAL
	case generated.LoanProductCategoryHOME:
		return loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_HOME
	case generated.LoanProductCategoryVEHICLE:
		return loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_VEHICLE
	case generated.LoanProductCategoryEDUCATION:
		return loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_EDUCATION
	default:
		return loanv1.LoanProductCategory_LOAN_PRODUCT_CATEGORY_UNSPECIFIED
	}
}

func toDBInterestType(v loanv1.InterestType) generated.LoanInterestType {
	if v == loanv1.InterestType_INTEREST_TYPE_FLOATING {
		return generated.LoanInterestTypeFLOATING
	}
	return generated.LoanInterestTypeFIXED
}

func toProtoInterestType(v generated.LoanInterestType) loanv1.InterestType {
	if v == generated.LoanInterestTypeFLOATING {
		return loanv1.InterestType_INTEREST_TYPE_FLOATING
	}
	return loanv1.InterestType_INTEREST_TYPE_FIXED
}

func toDBFeeType(v loanv1.ProductFeeType) generated.ProductFeeType {
	switch v {
	case loanv1.ProductFeeType_PRODUCT_FEE_TYPE_PREPAYMENT:
		return generated.ProductFeeTypePREPAYMENT
	case loanv1.ProductFeeType_PRODUCT_FEE_TYPE_LATE_PAYMENT:
		return generated.ProductFeeTypeLATEPAYMENT
	default:
		return generated.ProductFeeTypePROCESSING
	}
}

func toProtoFeeType(v generated.ProductFeeType) loanv1.ProductFeeType {
	switch v {
	case generated.ProductFeeTypePREPAYMENT:
		return loanv1.ProductFeeType_PRODUCT_FEE_TYPE_PREPAYMENT
	case generated.ProductFeeTypeLATEPAYMENT:
		return loanv1.ProductFeeType_PRODUCT_FEE_TYPE_LATE_PAYMENT
	default:
		return loanv1.ProductFeeType_PRODUCT_FEE_TYPE_PROCESSING
	}
}

func toDBFeeCalcMethod(v loanv1.FeeCalcMethod) generated.FeeCalcMethod {
	if v == loanv1.FeeCalcMethod_FEE_CALC_METHOD_PERCENTAGE {
		return generated.FeeCalcMethodPERCENTAGE
	}
	return generated.FeeCalcMethodFLAT
}

func toProtoFeeCalcMethod(v generated.FeeCalcMethod) loanv1.FeeCalcMethod {
	if v == generated.FeeCalcMethodPERCENTAGE {
		return loanv1.FeeCalcMethod_FEE_CALC_METHOD_PERCENTAGE
	}
	return loanv1.FeeCalcMethod_FEE_CALC_METHOD_FLAT
}

func toDBRequirementType(v loanv1.DocumentRequirementType) generated.DocumentRequirementType {
	switch v {
	case loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_ADDRESS:
		return generated.DocumentRequirementTypeADDRESS
	case loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_INCOME:
		return generated.DocumentRequirementTypeINCOME
	case loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_COLLATERAL:
		return generated.DocumentRequirementTypeCOLLATERAL
	default:
		return generated.DocumentRequirementTypeIDENTITY
	}
}

func toProtoRequirementType(v generated.DocumentRequirementType) loanv1.DocumentRequirementType {
	switch v {
	case generated.DocumentRequirementTypeADDRESS:
		return loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_ADDRESS
	case generated.DocumentRequirementTypeINCOME:
		return loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_INCOME
	case generated.DocumentRequirementTypeCOLLATERAL:
		return loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_COLLATERAL
	default:
		return loanv1.DocumentRequirementType_DOCUMENT_REQUIREMENT_TYPE_IDENTITY
	}
}

func toDBApplicationStatus(v loanv1.LoanApplicationStatus) generated.LoanApplicationStatus {
	switch v {
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_DRAFT:
		return generated.LoanApplicationStatusDRAFT
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_SUBMITTED:
		return generated.LoanApplicationStatusSUBMITTED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_UNDER_REVIEW:
		return generated.LoanApplicationStatusUNDERREVIEW
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_APPROVED:
		return generated.LoanApplicationStatusAPPROVED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_REJECTED:
		return generated.LoanApplicationStatusREJECTED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_DISBURSED:
		return generated.LoanApplicationStatusDISBURSED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_CANCELLED:
		return generated.LoanApplicationStatusCANCELLED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_REVIEW:
		return generated.LoanApplicationStatusOFFICERREVIEW
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_APPROVED:
		return generated.LoanApplicationStatusOFFICERAPPROVED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_REJECTED:
		return generated.LoanApplicationStatusOFFICERREJECTED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_REVIEW:
		return generated.LoanApplicationStatusMANAGERREVIEW
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_APPROVED:
		return generated.LoanApplicationStatusMANAGERAPPROVED
	case loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_REJECTED:
		return generated.LoanApplicationStatusMANAGERREJECTED
	default:
		return generated.LoanApplicationStatus("")
	}
}

func toProtoApplicationStatus(v generated.LoanApplicationStatus) loanv1.LoanApplicationStatus {
	switch v {
	case generated.LoanApplicationStatusDRAFT:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_DRAFT
	case generated.LoanApplicationStatusSUBMITTED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_SUBMITTED
	case generated.LoanApplicationStatusUNDERREVIEW:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_UNDER_REVIEW
	case generated.LoanApplicationStatusAPPROVED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_APPROVED
	case generated.LoanApplicationStatusREJECTED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_REJECTED
	case generated.LoanApplicationStatusDISBURSED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_DISBURSED
	case generated.LoanApplicationStatusCANCELLED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_CANCELLED
	case generated.LoanApplicationStatusOFFICERREVIEW:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_REVIEW
	case generated.LoanApplicationStatusOFFICERAPPROVED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_APPROVED
	case generated.LoanApplicationStatusOFFICERREJECTED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_OFFICER_REJECTED
	case generated.LoanApplicationStatusMANAGERREVIEW:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_REVIEW
	case generated.LoanApplicationStatusMANAGERAPPROVED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_APPROVED
	case generated.LoanApplicationStatusMANAGERREJECTED:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_MANAGER_REJECTED
	default:
		return loanv1.LoanApplicationStatus_LOAN_APPLICATION_STATUS_UNSPECIFIED
	}
}

func toDBCoapplicantRelationship(v loanv1.CoapplicantRelationship) generated.CoapplicantRelationship {
	switch v {
	case loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_PARENT:
		return generated.CoapplicantRelationshipPARENT
	case loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_SIBLING:
		return generated.CoapplicantRelationshipSIBLING
	case loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_BUSINESS_PARTNER:
		return generated.CoapplicantRelationshipBUSINESSPARTNER
	default:
		return generated.CoapplicantRelationshipSPOUSE
	}
}

func toProtoCoapplicantRelationship(v generated.CoapplicantRelationship) loanv1.CoapplicantRelationship {
	switch v {
	case generated.CoapplicantRelationshipPARENT:
		return loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_PARENT
	case generated.CoapplicantRelationshipSIBLING:
		return loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_SIBLING
	case generated.CoapplicantRelationshipBUSINESSPARTNER:
		return loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_BUSINESS_PARTNER
	default:
		return loanv1.CoapplicantRelationship_COAPPLICANT_RELATIONSHIP_SPOUSE
	}
}

func toDBCollateralAssetType(v loanv1.CollateralAssetType) generated.CollateralAssetType {
	if v == loanv1.CollateralAssetType_COLLATERAL_ASSET_TYPE_REAL_ESTATE {
		return generated.CollateralAssetTypeREALESTATE
	}
	return generated.CollateralAssetTypeVEHICLE
}

func toProtoCollateralAssetType(v generated.CollateralAssetType) loanv1.CollateralAssetType {
	if v == generated.CollateralAssetTypeREALESTATE {
		return loanv1.CollateralAssetType_COLLATERAL_ASSET_TYPE_REAL_ESTATE
	}
	return loanv1.CollateralAssetType_COLLATERAL_ASSET_TYPE_VEHICLE
}

func toDBCollateralVerificationStatus(v loanv1.CollateralVerificationStatus) generated.CollateralVerificationStatus {
	switch v {
	case loanv1.CollateralVerificationStatus_COLLATERAL_VERIFICATION_STATUS_VERIFIED:
		return generated.CollateralVerificationStatusVERIFIED
	case loanv1.CollateralVerificationStatus_COLLATERAL_VERIFICATION_STATUS_REJECTED:
		return generated.CollateralVerificationStatusREJECTED
	default:
		return generated.CollateralVerificationStatusPENDING
	}
}

func toProtoCollateralVerificationStatus(v generated.CollateralVerificationStatus) loanv1.CollateralVerificationStatus {
	switch v {
	case generated.CollateralVerificationStatusVERIFIED:
		return loanv1.CollateralVerificationStatus_COLLATERAL_VERIFICATION_STATUS_VERIFIED
	case generated.CollateralVerificationStatusREJECTED:
		return loanv1.CollateralVerificationStatus_COLLATERAL_VERIFICATION_STATUS_REJECTED
	default:
		return loanv1.CollateralVerificationStatus_COLLATERAL_VERIFICATION_STATUS_PENDING
	}
}

func toDBPropertyType(v loanv1.PropertyType) generated.PropertyType {
	switch v {
	case loanv1.PropertyType_PROPERTY_TYPE_VILLA:
		return generated.PropertyTypeVILLA
	case loanv1.PropertyType_PROPERTY_TYPE_PLOT:
		return generated.PropertyTypePLOT
	default:
		return generated.PropertyTypeAPARTMENT
	}
}

func toProtoPropertyType(v generated.PropertyType) loanv1.PropertyType {
	switch v {
	case generated.PropertyTypeVILLA:
		return loanv1.PropertyType_PROPERTY_TYPE_VILLA
	case generated.PropertyTypePLOT:
		return loanv1.PropertyType_PROPERTY_TYPE_PLOT
	default:
		return loanv1.PropertyType_PROPERTY_TYPE_APARTMENT
	}
}

func toDBPropertyStatus(v loanv1.PropertyStatus) generated.PropertyStatus {
	if v == loanv1.PropertyStatus_PROPERTY_STATUS_UNDER_CONSTRUCTION {
		return generated.PropertyStatusUNDERCONSTRUCTION
	}
	return generated.PropertyStatusREADYTOMOVE
}

func toProtoPropertyStatus(v generated.PropertyStatus) loanv1.PropertyStatus {
	if v == generated.PropertyStatusUNDERCONSTRUCTION {
		return loanv1.PropertyStatus_PROPERTY_STATUS_UNDER_CONSTRUCTION
	}
	return loanv1.PropertyStatus_PROPERTY_STATUS_READY_TO_MOVE
}

func toDBDocumentVerificationStatus(v loanv1.DocumentVerificationStatus) generated.DocumentVerificationStatus {
	switch v {
	case loanv1.DocumentVerificationStatus_DOCUMENT_VERIFICATION_STATUS_PASS:
		return generated.DocumentVerificationStatusPASS
	case loanv1.DocumentVerificationStatus_DOCUMENT_VERIFICATION_STATUS_FAIL:
		return generated.DocumentVerificationStatusFAIL
	default:
		return generated.DocumentVerificationStatusPENDING
	}
}

func toProtoDocumentVerificationStatus(v generated.DocumentVerificationStatus) loanv1.DocumentVerificationStatus {
	switch v {
	case generated.DocumentVerificationStatusPASS:
		return loanv1.DocumentVerificationStatus_DOCUMENT_VERIFICATION_STATUS_PASS
	case generated.DocumentVerificationStatusFAIL:
		return loanv1.DocumentVerificationStatus_DOCUMENT_VERIFICATION_STATUS_FAIL
	default:
		return loanv1.DocumentVerificationStatus_DOCUMENT_VERIFICATION_STATUS_PENDING
	}
}

func toDBBureauProvider(v loanv1.BureauProvider) generated.BureauProvider {
	switch v {
	case loanv1.BureauProvider_BUREAU_PROVIDER_EXPERIAN:
		return generated.BureauProviderEXPERIAN
	case loanv1.BureauProvider_BUREAU_PROVIDER_EQUIFAX:
		return generated.BureauProviderEQUIFAX
	default:
		return generated.BureauProviderCIBIL
	}
}

func toProtoBureauProvider(v generated.BureauProvider) loanv1.BureauProvider {
	switch v {
	case generated.BureauProviderEXPERIAN:
		return loanv1.BureauProvider_BUREAU_PROVIDER_EXPERIAN
	case generated.BureauProviderEQUIFAX:
		return loanv1.BureauProvider_BUREAU_PROVIDER_EQUIFAX
	default:
		return loanv1.BureauProvider_BUREAU_PROVIDER_CIBIL
	}
}

func toDBLoanStatus(v loanv1.LoanStatus) generated.LoanStatus {
	switch v {
	case loanv1.LoanStatus_LOAN_STATUS_CLOSED:
		return generated.LoanStatusCLOSED
	case loanv1.LoanStatus_LOAN_STATUS_NPA:
		return generated.LoanStatusNPA
	default:
		return generated.LoanStatusACTIVE
	}
}

func toProtoLoanStatus(v generated.LoanStatus) loanv1.LoanStatus {
	switch v {
	case generated.LoanStatusCLOSED:
		return loanv1.LoanStatus_LOAN_STATUS_CLOSED
	case generated.LoanStatusNPA:
		return loanv1.LoanStatus_LOAN_STATUS_NPA
	default:
		return loanv1.LoanStatus_LOAN_STATUS_ACTIVE
	}
}

func toDBEmiStatus(v loanv1.EmiStatus) generated.EmiStatus {
	switch v {
	case loanv1.EmiStatus_EMI_STATUS_PAID:
		return generated.EmiStatusPAID
	case loanv1.EmiStatus_EMI_STATUS_OVERDUE:
		return generated.EmiStatusOVERDUE
	default:
		return generated.EmiStatusUPCOMING
	}
}

func toProtoEmiStatus(v generated.EmiStatus) loanv1.EmiStatus {
	switch v {
	case generated.EmiStatusPAID:
		return loanv1.EmiStatus_EMI_STATUS_PAID
	case generated.EmiStatusOVERDUE:
		return loanv1.EmiStatus_EMI_STATUS_OVERDUE
	default:
		return loanv1.EmiStatus_EMI_STATUS_UPCOMING
	}
}

func toDBPaymentStatus(v loanv1.PaymentStatus) generated.PaymentStatus {
	switch v {
	case loanv1.PaymentStatus_PAYMENT_STATUS_SUCCESS:
		return generated.PaymentStatusSUCCESS
	case loanv1.PaymentStatus_PAYMENT_STATUS_FAILED:
		return generated.PaymentStatusFAILED
	default:
		return generated.PaymentStatusPENDING
	}
}

func toProtoPaymentStatus(v generated.PaymentStatus) loanv1.PaymentStatus {
	switch v {
	case generated.PaymentStatusSUCCESS:
		return loanv1.PaymentStatus_PAYMENT_STATUS_SUCCESS
	case generated.PaymentStatusFAILED:
		return loanv1.PaymentStatus_PAYMENT_STATUS_FAILED
	default:
		return loanv1.PaymentStatus_PAYMENT_STATUS_PENDING
	}
}

func toProtoCreatedByChannel(v generated.ApplicationCreatedByChannel) loanv1.ApplicationCreatedByChannel {
	switch v {
	case generated.ApplicationCreatedByChannelDST:
		return loanv1.ApplicationCreatedByChannel_APPLICATION_CREATED_BY_CHANNEL_DST
	case generated.ApplicationCreatedByChannelOFFICER:
		return loanv1.ApplicationCreatedByChannel_APPLICATION_CREATED_BY_CHANNEL_OFFICER
	default:
		return loanv1.ApplicationCreatedByChannel_APPLICATION_CREATED_BY_CHANNEL_SELF
	}
}

var _ Service = (*service)(nil)

func (s *service) RescheduleLoan(ctx context.Context, req *loanv1.RescheduleLoanRequest) (*loanv1.RescheduleLoanResponse, error) {
	_, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	if role != "manager" && role != "admin" {
		return nil, status.Error(codes.PermissionDenied, "only manager or admin can reschedule loans")
	}

	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}

	loanRow, err := s.queries.GetLoanByID(ctx, uuidToPg(loanID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan")
	}

	if loanRow.Status != generated.LoanStatusACTIVE {
		return nil, status.Error(codes.FailedPrecondition, "only active loans can be rescheduled")
	}

	newTenure := int(req.GetNewTenureMonths())
	if newTenure <= 0 {
		return nil, status.Error(codes.InvalidArgument, "new_tenure_months must be > 0")
	}

	outstandingF, err := numericToFloat64(loanRow.OutstandingBalance)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to parse outstanding balance")
	}

	rateF, err := numericToFloat64(loanRow.InterestRate)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to parse interest rate")
	}

	// Recalculate EMI
	newEmiF := calculateReducingEMI(outstandingF, rateF, newTenure)
	newEmi, err := float64ToNumeric(newEmiF)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to compute new emi")
	}

	// Transactionally update loan and schedule
	if err := s.queries.DeleteUpcomingEmiSchedulesByLoanID(ctx, uuidToPg(loanID)); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear future schedule")
	}

	updatedLoan, err := s.queries.UpdateLoanEmiAndOutstanding(ctx, generated.UpdateLoanEmiAndOutstandingParams{
		ID:                 uuidToPg(loanID),
		EmiAmount:          newEmi,
		OutstandingBalance: loanRow.OutstandingBalance,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update loan terms")
	}

	// Find the last non-upcoming installment number
	rows, err := s.queries.ListEmiScheduleByLoanID(ctx, uuidToPg(loanID))
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch current schedule")
	}

	lastInstallmentNum := int32(0)
	lastDueDate := time.Now().UTC()
	for _, row := range rows {
		if row.InstallmentNumber > lastInstallmentNum {
			lastInstallmentNum = row.InstallmentNumber
			lastDueDate = row.DueDate.Time
		}
	}

	// Generate new entries
	for i := 1; i <= newTenure; i++ {
		dueDate := lastDueDate.AddDate(0, i, 0)
		if _, err := s.queries.CreateEmiScheduleItem(ctx, generated.CreateEmiScheduleItemParams{
			LoanID:            uuidToPg(loanID),
			InstallmentNumber: lastInstallmentNum + int32(i),
			DueDate:           pgtype.Date{Time: dueDate, Valid: true},
			EmiAmount:         newEmi,
			Status:            generated.EmiStatusUPCOMING,
		}); err != nil {
			return nil, status.Error(codes.Internal, "failed to generate new schedule")
		}
	}

	// Fetch final schedule for response
	finalRows, _ := s.queries.ListEmiScheduleByLoanID(ctx, uuidToPg(loanID))
	newSchedule := make([]*loanv1.EmiScheduleItem, 0, len(finalRows))
	for _, r := range finalRows {
		newSchedule = append(newSchedule, mapEmi(r))
	}

	return &loanv1.RescheduleLoanResponse{
		Loan:        mapLoan(updatedLoan),
		NewSchedule: newSchedule,
	}, nil
}

func (s *service) InitiatePayment(ctx context.Context, req *loanv1.InitiatePaymentRequest) (*loanv1.InitiatePaymentResponse, error) {
	loanID, err := parseUUID(req.GetLoanId(), "loan_id")
	if err != nil {
		return nil, err
	}
	loanRow, err := s.queries.GetLoanByID(ctx, uuidToPg(loanID))
	if err != nil {
		return nil, status.Error(codes.NotFound, "loan not found")
	}
	if loanRow.Status != generated.LoanStatusACTIVE {
		return nil, status.Error(codes.FailedPrecondition, "loan is not active")
	}

	amount, err := parseNumeric(req.GetAmount(), "amount")
	if err != nil {
		return nil, err
	}
	amountF, _ := numericToFloat64(amount)

	emiScheduleID := pgtype.UUID{}
	if strings.TrimSpace(req.GetEmiScheduleId()) != "" {
		id, err := parseUUID(req.GetEmiScheduleId(), "emi_schedule_id")
		if err != nil {
			return nil, err
		}
		emiRow, err := s.queries.GetEmiScheduleByID(ctx, uuidToPg(id))
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "emi_schedule_id not found")
		}
		if emiRow.LoanID != uuidToPg(loanID) {
			return nil, status.Error(codes.InvalidArgument, "emi_schedule_id does not belong to loan_id")
		}
		emiScheduleID = uuidToPg(id)
	}

	// Create Razorpay Order
	amountPaise := int64(amountF * 100)
	receipt := fmt.Sprintf("rcpt_%s", uuid.New().String()[:8])
	razorpayOrderID, err := s.razorpay.CreateOrder(amountPaise, receipt)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Save to database
	_, err = s.queries.CreatePaymentOrder(ctx, generated.CreatePaymentOrderParams{
		RazorpayOrderID: razorpayOrderID,
		LoanID:          uuidToPg(loanID),
		EmiScheduleID:   emiScheduleID,
		Amount:          amount,
		Status:          generated.PaymentStatusPENDING,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save payment order")
	}

	return &loanv1.InitiatePaymentResponse{
		RazorpayOrderId: razorpayOrderID,
		Amount:          req.GetAmount(),
		Currency:        "INR",
	}, nil
}

func (s *service) VerifyPayment(ctx context.Context, req *loanv1.VerifyPaymentRequest) (*loanv1.VerifyPaymentResponse, error) {
	orderID := req.GetRazorpayOrderId()
	paymentID := req.GetRazorpayPaymentId()
	signature := req.GetRazorpaySignature()

	// Verify signature
	if err := s.razorpay.VerifySignature(orderID, paymentID, signature); err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid signature")
	}

	// Update order status
	orderRow, err := s.queries.GetPaymentOrderByRazorpayOrderID(ctx, orderID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "payment order not found")
	}

	if orderRow.Status == generated.PaymentStatusSUCCESS {
		// Already processed
		return &loanv1.VerifyPaymentResponse{Success: true}, nil
	}

	// Process the payment
	payment, err := s.processSuccessfulPayment(ctx, orderRow.LoanID, orderRow.EmiScheduleID, orderRow.Amount, paymentID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to process successful payment")
	}

	// Mark order as success
	err = s.queries.UpdatePaymentOrderVerification(ctx, generated.UpdatePaymentOrderVerificationParams{
		ID:                orderRow.ID,
		RazorpayPaymentID: pgText(paymentID),
		RazorpaySignature: pgText(signature),
		Status:            generated.PaymentStatusSUCCESS,
	})

	return &loanv1.VerifyPaymentResponse{
		Success: true,
		Payment: mapPayment(payment),
	}, nil
}

func (s *service) processSuccessfulPayment(ctx context.Context, loanID pgtype.UUID, emiID pgtype.UUID, amount pgtype.Numeric, externalID string) (generated.Payment, error) {
	// 1. Create Payment Record
	paymentRow, err := s.queries.CreatePayment(ctx, generated.CreatePaymentParams{
		LoanID:                loanID,
		EmiScheduleID:         emiID,
		Amount:                amount,
		ExternalTransactionID: externalID,
		Status:                generated.PaymentStatusSUCCESS,
	})
	if err != nil {
		return generated.Payment{}, err
	}

	// 2. Update EMI Status if applicable
	if emiID.Valid {
		s.queries.UpdateEmiScheduleStatus(ctx, generated.UpdateEmiScheduleStatusParams{
			ID:     emiID,
			Status: generated.EmiStatusPAID,
		})
	}

	// 3. Update Loan Balance
	loanRow, _ := s.queries.GetLoanByID(ctx, loanID)
	amountF, _ := numericToFloat64(amount)
	outstandingF, _ := numericToFloat64(loanRow.OutstandingBalance)
	newOutstandingF := math.Max(0, outstandingF-amountF)
	newOutstanding, _ := float64ToNumeric(newOutstandingF)

	s.queries.UpdateLoanStatusAndOutstanding(ctx, generated.UpdateLoanStatusAndOutstandingParams{
		ID:                 loanID,
		Status:             loanRow.Status,
		OutstandingBalance: newOutstanding,
	})

	// 4. Handle Tenure Reduction for Unscheduled Payments
	if !emiID.Valid {
		rateF, _ := numericToFloat64(loanRow.InterestRate)
		emiAmountF, _ := numericToFloat64(loanRow.EmiAmount)
		newTenure := calculateRemainingTenure(newOutstandingF, rateF, emiAmountF)

		s.queries.DeleteUpcomingEmiSchedulesByLoanID(ctx, loanID)

		rows, _ := s.queries.ListEmiScheduleByLoanID(ctx, loanID)
		lastNum := int32(0)
		lastDate := time.Now().UTC()
		for _, r := range rows {
			if r.InstallmentNumber > lastNum {
				lastNum = r.InstallmentNumber
				lastDate = r.DueDate.Time
			}
		}

		for i := 1; i <= newTenure; i++ {
			dueDate := lastDate.AddDate(0, i, 0)
			s.queries.CreateEmiScheduleItem(ctx, generated.CreateEmiScheduleItemParams{
				LoanID:            loanID,
				InstallmentNumber: lastNum + int32(i),
				DueDate:           pgtype.Date{Time: dueDate, Valid: true},
				EmiAmount:         loanRow.EmiAmount,
				Status:            generated.EmiStatusUPCOMING,
			})
		}
	}

	return paymentRow, nil
}

func (s *service) ProcessPaymentFromWebhook(ctx context.Context, orderID, paymentID string) error {
	orderRow, err := s.queries.GetPaymentOrderByRazorpayOrderID(ctx, orderID)
	if err != nil {
		return err
	}

	if orderRow.Status == generated.PaymentStatusSUCCESS {
		return nil
	}

	_, err = s.processSuccessfulPayment(ctx, orderRow.LoanID, orderRow.EmiScheduleID, orderRow.Amount, paymentID)
	if err != nil {
		return err
	}

	return s.queries.UpdatePaymentOrderVerification(ctx, generated.UpdatePaymentOrderVerificationParams{
		ID:                orderRow.ID,
		RazorpayPaymentID: pgText(paymentID),
		Status:            generated.PaymentStatusSUCCESS,
	})
}
