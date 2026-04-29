package loan

import (
	"context"
	"log"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
)

type Worker struct {
	queries generated.Querier
}

func NewWorker(queries generated.Querier) *Worker {
	return &Worker{queries: queries}
}

func (w *Worker) Start(ctx context.Context) {
	log.Println("starting loan background worker")
	
	// Run once on startup
	w.markOverdue(ctx)

	// Calculate time until next 12 AM
	now := time.Now()
	nextRun := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, now.Location())
	timer := time.NewTimer(nextRun.Sub(now))

	for {
		select {
		case <-ctx.Done():
			log.Println("stopping loan background worker")
			return
		case <-timer.C:
			w.markOverdue(ctx)
			// Reset timer for next 24 hours
			timer.Reset(24 * time.Hour)
		}
	}
}

func (w *Worker) markOverdue(ctx context.Context) {
	log.Println("running daily overdue marking task")
	count, err := w.queries.MarkUpcomingSchedulesAsOverdue(ctx)
	if err != nil {
		log.Printf("failed to mark overdue schedules: %v", err)
		return
	}
	if count > 0 {
		log.Printf("successfully marked %d schedules as OVERDUE", count)
	}
}
