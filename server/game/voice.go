package game

import (
	"time"
)

const (
	MaxTalkTime = 5 * time.Second
)

type VoiceState struct {
	CurrentSpeakerID string    `json:"currentSpeakerId"`
	Queue            []string  `json:"queue"`
	SpeakerStart     time.Time `json:"-"`
	TimeRemainingS   int       `json:"timeRemainingS"`
	IsPremium        bool      `json:"isPremium"` // For later use (Phase 3)
}

func NewVoiceState() *VoiceState {
	return &VoiceState{
		Queue: make([]string, 0),
	}
}

// RequestMic adds a user to the queue if not already there
func (v *VoiceState) RequestMic(clientID string) {
	for _, id := range v.Queue {
		if id == clientID {
			return // Already in queue
		}
	}
	if v.CurrentSpeakerID == clientID {
		return // Already speaking
	}

	v.Queue = append(v.Queue, clientID)
}

// ReleaseMic removes a user from queue or stops them if speaking
func (v *VoiceState) ReleaseMic(clientID string) {
	if v.CurrentSpeakerID == clientID {
		v.nextSpeaker()
		return
	}

	// Remove from queue
	newQueue := make([]string, 0)
	for _, id := range v.Queue {
		if id != clientID {
			newQueue = append(newQueue, id)
		}
	}
	v.Queue = newQueue
}

// Tick updates the timer and manages speaker rotation
// Returns true if state changed (needing broadcast)
func (v *VoiceState) Tick() bool {
	changed := false

	// If nobody speaking but queue has people, grant mic
	if v.CurrentSpeakerID == "" && len(v.Queue) > 0 {
		v.nextSpeaker()
		return true
	}

	// If speaking, check timer
	if v.CurrentSpeakerID != "" {
		elapsed := time.Since(v.SpeakerStart)
		remaining := MaxTalkTime - elapsed

		if remaining <= 0 {
			v.nextSpeaker() // Time's up!
			return true
		}

		// Update integer seconds for clients
		remainingInt := int(remaining.Seconds()) + 1
		if remainingInt != v.TimeRemainingS {
			v.TimeRemainingS = remainingInt
			// Ideally we don't broadcast every second to save bandwidth,
			// but for 1 speaker it's fine. The client can also interpolate.
			// Let's broadcast on second change for accuracy.
			changed = true
		}
	}

	return changed
}

func (v *VoiceState) nextSpeaker() {
	v.CurrentSpeakerID = ""
	v.TimeRemainingS = 0

	if len(v.Queue) > 0 {
		// Pop first
		next := v.Queue[0]
		v.Queue = v.Queue[1:]

		v.CurrentSpeakerID = next
		v.SpeakerStart = time.Now()
		v.TimeRemainingS = int(MaxTalkTime.Seconds())
	}
}
