package query

import (
	"context"
	"errors"
	"math/rand"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	queryv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/queryv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	CreateLoanQuery(ctx context.Context, req *queryv1.CreateLoanQueryRequest) (*queryv1.CreateLoanQueryResponse, error)
	GetLoanQuery(ctx context.Context, req *queryv1.GetLoanQueryRequest) (*queryv1.GetLoanQueryResponse, error)
	ListLoanQueries(ctx context.Context, req *queryv1.ListLoanQueriesRequest) (*queryv1.ListLoanQueriesResponse, error)
	UpdateLoanQueryStatus(ctx context.Context, req *queryv1.UpdateLoanQueryStatusRequest) (*queryv1.UpdateLoanQueryStatusResponse, error)
}

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

func (s *service) CreateLoanQuery(ctx context.Context, req *queryv1.CreateLoanQueryRequest) (*queryv1.CreateLoanQueryResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	if role != "borrower" {
		return nil, status.Error(codes.PermissionDenied, "only borrower can create loan queries")
	}

	productID, err := parseUUID(req.GetLoanProductId(), "loan_product_id")
	if err != nil {
		return nil, err
	}
	branchID, err := parseUUID(req.GetBranchId(), "branch_id")
	if err != nil {
		return nil, err
	}
	amount, err := parseNumeric(req.GetRequestedAmount(), "requested_amount")
	if err != nil {
		return nil, err
	}
	if req.GetTenureMonths() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "tenure_months must be > 0")
	}

	profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "borrower profile not found")
	}
	if _, err := s.queries.GetBankBranchByID(ctx, uuidToPg(branchID)); err != nil {
		return nil, status.Error(codes.InvalidArgument, "branch_id not found")
	}
	product, err := s.queries.GetLoanProductByID(ctx, uuidToPg(productID))
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "loan_product_id not found")
	}
	if product.IsDeleted || !product.IsActive {
		return nil, status.Error(codes.FailedPrecondition, "loan product is not active")
	}
	if product.Category == generated.LoanProductCategoryPERSONAL {
		return nil, status.Error(codes.FailedPrecondition, "personal loan should be created directly via loan application")
	}

	row, err := s.queries.CreateLoanQuery(ctx, generated.CreateLoanQueryParams{
		BorrowerProfileID:     profile.ID,
		LoanProductID:         uuidToPg(productID),
		BranchID:              uuidToPg(branchID),
		RequestedAmount:       amount,
		TenureMonths:          req.GetTenureMonths(),
		AssignedOfficerUserID: pgtype.UUID{},
		Status:                generated.LoanQueryStatusPENDING,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create loan query")
	}

	officerUserIDs, err := s.queries.ListOfficerUserIDsByBranchID(ctx, uuidToPg(branchID))
	if err == nil && len(officerUserIDs) > 0 {
		picked := officerUserIDs[rand.Intn(len(officerUserIDs))]
		_ = s.queries.AssignLoanQueryOfficer(ctx, generated.AssignLoanQueryOfficerParams{ID: row.ID, AssignedOfficerUserID: picked})
		row.AssignedOfficerUserID = picked
	}

	return &queryv1.CreateLoanQueryResponse{Query: mapLoanQuery(row)}, nil
}

func (s *service) GetLoanQuery(ctx context.Context, req *queryv1.GetLoanQueryRequest) (*queryv1.GetLoanQueryResponse, error) {
	queryID, err := parseUUID(req.GetQueryId(), "query_id")
	if err != nil {
		return nil, err
	}
	row, err := s.queries.GetLoanQueryByID(ctx, uuidToPg(queryID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan query not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan query")
	}
	if err := s.ensureCanAccessQuery(ctx, row); err != nil {
		return nil, err
	}
	return &queryv1.GetLoanQueryResponse{Query: mapLoanQuery(row)}, nil
}

func (s *service) ListLoanQueries(ctx context.Context, req *queryv1.ListLoanQueriesRequest) (*queryv1.ListLoanQueriesResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	statusFilter := toDBLoanQueryStatus(req.GetStatus())
	if req.GetStatus() == queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_UNSPECIFIED {
		statusFilter = generated.LoanQueryStatus("")
	}
	limit := req.GetLimit()
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	offset := req.GetOffset()
	if offset < 0 {
		offset = 0
	}

	var rows []generated.LoanQuery
	switch role {
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil {
			return nil, status.Error(codes.FailedPrecondition, "borrower profile not found")
		}
		rows, err = s.queries.ListLoanQueriesForBorrower(ctx, generated.ListLoanQueriesForBorrowerParams{
			BorrowerProfileID: profile.ID,
			Limit:             limit,
			Offset:            offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan queries")
		}
	case "officer":
		rows, err = s.queries.ListLoanQueriesForAssignedOfficer(ctx, generated.ListLoanQueriesForAssignedOfficerParams{
			AssignedOfficerUserID: uuidToPg(callerUserID),
			Column2:               statusFilter,
			Limit:                 limit,
			Offset:                offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan queries")
		}
	case "manager", "admin":
		branchID, err := s.resolveBranchForList(ctx, callerUserID, role, strings.TrimSpace(req.GetBranchId()))
		if err != nil {
			return nil, err
		}
		rows, err = s.queries.ListLoanQueriesByBranchID(ctx, generated.ListLoanQueriesByBranchIDParams{
			BranchID: uuidToPg(branchID),
			Column2: statusFilter,
			Limit:   limit,
			Offset:  offset,
		})
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to list loan queries")
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "role cannot list loan queries")
	}

	items := make([]*queryv1.LoanQuery, 0, len(rows))
	for _, row := range rows {
		items = append(items, mapLoanQuery(row))
	}
	return &queryv1.ListLoanQueriesResponse{Items: items}, nil
}

func (s *service) UpdateLoanQueryStatus(ctx context.Context, req *queryv1.UpdateLoanQueryStatusRequest) (*queryv1.UpdateLoanQueryStatusResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}
	if role != "manager" && role != "admin" {
		return nil, status.Error(codes.PermissionDenied, "only manager or admin can update query status")
	}
	queryID, err := parseUUID(req.GetQueryId(), "query_id")
	if err != nil {
		return nil, err
	}
	to := toDBLoanQueryStatus(req.GetStatus())
	if to != generated.LoanQueryStatusCOMPLETED {
		return nil, status.Error(codes.InvalidArgument, "status can only be set to COMPLETED")
	}
	row, err := s.queries.GetLoanQueryByID(ctx, uuidToPg(queryID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "loan query not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch loan query")
	}
	if role == "manager" {
		managerBranchID, err := s.branchForManager(ctx, callerUserID)
		if err != nil {
			return nil, err
		}
		if managerBranchID != uuid.UUID(row.BranchID.Bytes) {
			return nil, status.Error(codes.PermissionDenied, "manager can only update queries from own branch")
		}
	}
	if row.Status == generated.LoanQueryStatusCOMPLETED {
		return &queryv1.UpdateLoanQueryStatusResponse{Query: mapLoanQuery(row)}, nil
	}
	if err := s.queries.UpdateLoanQueryStatus(ctx, generated.UpdateLoanQueryStatusParams{ID: row.ID, Status: generated.LoanQueryStatusCOMPLETED}); err != nil {
		return nil, status.Error(codes.Internal, "failed to update query status")
	}
	updated, err := s.queries.GetLoanQueryByID(ctx, row.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch updated query")
	}
	return &queryv1.UpdateLoanQueryStatusResponse{Query: mapLoanQuery(updated)}, nil
}

func (s *service) ensureCanAccessQuery(ctx context.Context, row generated.LoanQuery) error {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return err
	}
	switch role {
	case "admin":
		return nil
	case "borrower":
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(callerUserID))
		if err != nil || profile.ID != row.BorrowerProfileID {
			return status.Error(codes.PermissionDenied, "borrower can only access own queries")
		}
		return nil
	case "officer":
		if !row.AssignedOfficerUserID.Valid || row.AssignedOfficerUserID.Bytes != callerUserID {
			return status.Error(codes.PermissionDenied, "officer can only access assigned queries")
		}
		return nil
	case "manager":
		branchID, err := s.branchForManager(ctx, callerUserID)
		if err != nil {
			return err
		}
		if branchID != uuid.UUID(row.BranchID.Bytes) {
			return status.Error(codes.PermissionDenied, "manager can only access own branch queries")
		}
		return nil
	default:
		return status.Error(codes.PermissionDenied, "access denied")
	}
}

func (s *service) resolveBranchForList(ctx context.Context, callerUserID uuid.UUID, role, branchIDStr string) (uuid.UUID, error) {
	if role == "manager" {
		managerBranchID, err := s.branchForManager(ctx, callerUserID)
		if err != nil {
			return uuid.UUID{}, err
		}
		if branchIDStr != "" {
			branchID, err := uuid.Parse(branchIDStr)
			if err != nil {
				return uuid.UUID{}, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
			}
			if branchID != managerBranchID {
				return uuid.UUID{}, status.Error(codes.PermissionDenied, "manager can only list queries from own branch")
			}
		}
		return managerBranchID, nil
	}
	if branchIDStr == "" {
		return uuid.UUID{}, status.Error(codes.InvalidArgument, "branch_id is required")
	}
	branchID, err := uuid.Parse(branchIDStr)
	if err != nil {
		return uuid.UUID{}, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
	}
	return branchID, nil
}

func (s *service) branchForManager(ctx context.Context, userID uuid.UUID) (uuid.UUID, error) {
	p, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(userID))
	if err != nil {
		return uuid.UUID{}, status.Error(codes.NotFound, "manager profile not found")
	}
	if !p.BranchID.Valid {
		return uuid.UUID{}, status.Error(codes.FailedPrecondition, "manager is not assigned to a branch")
	}
	return uuid.UUID(p.BranchID.Bytes), nil
}

func requireUserAndRole(ctx context.Context) (uuid.UUID, string, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if strings.TrimSpace(role) == "" {
		return uuid.UUID{}, "", status.Error(codes.PermissionDenied, "missing role context")
	}
	return userID, role, nil
}

func parseUUID(value, field string) (uuid.UUID, error) {
	v := strings.TrimSpace(value)
	if v == "" {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "%s is required", field)
	}
	id, err := uuid.Parse(v)
	if err != nil {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "%s must be a valid uuid", field)
	}
	return id, nil
}

func parseNumeric(value, field string) (pgtype.Numeric, error) {
	v := strings.TrimSpace(value)
	if v == "" {
		return pgtype.Numeric{}, status.Errorf(codes.InvalidArgument, "%s is required", field)
	}
	var n pgtype.Numeric
	if err := n.Scan(v); err != nil {
		return pgtype.Numeric{}, status.Errorf(codes.InvalidArgument, "%s must be a valid decimal", field)
	}
	fv, err := n.Float64Value()
	if err != nil || !fv.Valid || fv.Float64 <= 0 {
		return pgtype.Numeric{}, status.Errorf(codes.InvalidArgument, "%s must be > 0", field)
	}
	return n, nil
}

func uuidToPg(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: id, Valid: true}
}

func timeToString(v pgtype.Timestamptz) string {
	if !v.Valid {
		return ""
	}
	return v.Time.UTC().Format(time.RFC3339)
}

func numericToString(v pgtype.Numeric) string {
	if !v.Valid {
		return ""
	}
	b, err := v.MarshalJSON()
	if err != nil {
		return ""
	}
	return strings.Trim(string(b), "\"")
}

func toDBLoanQueryStatus(v queryv1.LoanQueryStatus) generated.LoanQueryStatus {
	switch v {
	case queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_PENDING:
		return generated.LoanQueryStatusPENDING
	case queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_COMPLETED:
		return generated.LoanQueryStatusCOMPLETED
	default:
		return generated.LoanQueryStatus("")
	}
}

func toProtoLoanQueryStatus(v generated.LoanQueryStatus) queryv1.LoanQueryStatus {
	switch v {
	case generated.LoanQueryStatusPENDING:
		return queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_PENDING
	case generated.LoanQueryStatusCOMPLETED:
		return queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_COMPLETED
	default:
		return queryv1.LoanQueryStatus_LOAN_QUERY_STATUS_UNSPECIFIED
	}
}

func mapLoanQuery(row generated.LoanQuery) *queryv1.LoanQuery {
	return &queryv1.LoanQuery{
		Id:                    row.ID.String(),
		BorrowerProfileId:     row.BorrowerProfileID.String(),
		LoanProductId:         row.LoanProductID.String(),
		BranchId:              row.BranchID.String(),
		RequestedAmount:       numericToString(row.RequestedAmount),
		TenureMonths:          row.TenureMonths,
		AssignedOfficerUserId: row.AssignedOfficerUserID.String(),
		Status:                toProtoLoanQueryStatus(row.Status),
		CreatedAt:             timeToString(row.CreatedAt),
		UpdatedAt:             timeToString(row.UpdatedAt),
	}
}
