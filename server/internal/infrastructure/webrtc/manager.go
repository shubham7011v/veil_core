package webrtc

import (
	"io"
	"log"
	"sync"

	"github.com/pion/webrtc/v3"
)

// Manager handles all SFU logic: PeerConnections, Tracks, and Relaying.
// Moved from game package to infrastructure as it's an external adapter.
type Manager struct {
	// API is the Pion WebRTC API instance
	api *webrtc.API

	// Lock for thread-safety
	mu sync.RWMutex

	// currentSpeaker ID (managed by Room/Session)
	currentSpeaker string

	// Clients map: UserID -> PeerConnection
	pcs map[string]*webrtc.PeerConnection

	// Audio Tracks
	// incomingTracks: UserID -> RemoteTrack (Audio they are sending us)
	incomingTracks map[string]*webrtc.TrackRemote

	// outgoingTracks: UserID -> LocalTrack (Audio we are sending them)
	outgoingTracks map[string]*webrtc.TrackLocalStaticRTP
}

// NewManager creates a new SFU manager
func NewManager() *Manager {
	// Create a MediaEngine to configure supported codecs
	m := &webrtc.MediaEngine{}

	// Setup the codecs you want to use.
	if err := m.RegisterCodec(webrtc.RTPCodecParameters{
		RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: webrtc.MimeTypeOpus, ClockRate: 48000, Channels: 2, SDPFmtpLine: "minptime=10;useinbandfec=1"},
		PayloadType:        111,
	}, webrtc.RTPCodecTypeAudio); err != nil {
		log.Printf("WebRTC: Failed to register codec: %v", err)
	}

	// Create the API object with the MediaEngine
	api := webrtc.NewAPI(webrtc.WithMediaEngine(m))

	return &Manager{
		api:            api,
		pcs:            make(map[string]*webrtc.PeerConnection),
		incomingTracks: make(map[string]*webrtc.TrackRemote),
		outgoingTracks: make(map[string]*webrtc.TrackLocalStaticRTP),
	}
}

// AddParticipant initializes a PeerConnection for a user
func (m *Manager) AddParticipant(userID string) (*webrtc.PeerConnection, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 1. Create PC
	pc, err := m.api.NewPeerConnection(webrtc.Configuration{
		ICEServers: []webrtc.ICEServer{
			{URLs: []string{"stun:stun.l.google.com:19302"}},
		},
	})
	if err != nil {
		return nil, err
	}

	// 2. Add Transceivers (Audio only)
	outputTrack, err := webrtc.NewTrackLocalStaticRTP(webrtc.RTPCodecCapability{MimeType: webrtc.MimeTypeOpus}, "audio", "pion")
	if err != nil {
		pc.Close()
		return nil, err
	}

	if _, err = pc.AddTrack(outputTrack); err != nil {
		pc.Close()
		return nil, err
	}

	m.outgoingTracks[userID] = outputTrack

	// 3. Handle ICE Candidates
	pc.OnICECandidate(func(i *webrtc.ICECandidate) {
		if i == nil {
			return
		}
	})

	// 4. Handle Incoming Tracks
	pc.OnTrack(func(track *webrtc.TrackRemote, receiver *webrtc.RTPReceiver) {
		if track.Kind() != webrtc.RTPCodecTypeAudio {
			return
		}

		log.Printf("Voice: Track received from %s", userID)
		m.mu.Lock()
		m.incomingTracks[userID] = track
		m.mu.Unlock()

		go func() {
			b := make([]byte, 1500)
			for {
				n, _, err := track.Read(b)
				if err != nil {
					return
				}

				m.mu.RLock()
				isSpeaker := (userID == m.currentSpeaker)
				if isSpeaker {
					for pid, outTrack := range m.outgoingTracks {
						if pid != userID {
							if _, err := outTrack.Write(b[:n]); err != nil && err != io.ErrClosedPipe {
							}
						}
					}
				}
				m.mu.RUnlock()
			}
		}()
	})

	// 5. Cleanup
	pc.OnConnectionStateChange(func(s webrtc.PeerConnectionState) {
		if s == webrtc.PeerConnectionStateFailed || s == webrtc.PeerConnectionStateClosed {
			m.mu.Lock()
			delete(m.pcs, userID)
			delete(m.incomingTracks, userID)
			delete(m.outgoingTracks, userID)
			m.mu.Unlock()
		}
	})

	m.pcs[userID] = pc
	return pc, nil
}

// HandleOffer handles an SDP offer from a client
func (m *Manager) HandleOffer(userID string, offer webrtc.SessionDescription) (*webrtc.SessionDescription, error) {
	pc, err := m.AddParticipant(userID)
	if err != nil {
		return nil, err
	}

	if err := pc.SetRemoteDescription(offer); err != nil {
		return nil, err
	}

	answer, err := pc.CreateAnswer(nil)
	if err != nil {
		return nil, err
	}

	if err := pc.SetLocalDescription(answer); err != nil {
		return nil, err
	}

	<-webrtc.GatheringCompletePromise(pc)
	return pc.LocalDescription(), nil
}

// HandleICE handles a trickle ICE candidate from a client
func (m *Manager) HandleICE(userID string, candidate webrtc.ICECandidateInit) error {
	m.mu.RLock()
	pc, ok := m.pcs[userID]
	m.mu.RUnlock()

	if !ok {
		return nil
	}

	return pc.AddICECandidate(candidate)
}

// SetSpeaker updates the active speaker ID
func (m *Manager) SetSpeaker(speakerID string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.currentSpeaker = speakerID
}
