package config

import (
	"os"
)

// FeatureFlags defines the state of various high-level features
type FeatureFlags struct {
	EnableDailyChallenges bool `json:"enableDailyChallenges"`
	EnableTournaments     bool `json:"enableTournaments"`
	EnableAdminDashboard  bool `json:"enableAdminDashboard"`
	EnableVoiceChat       bool `json:"enableVoiceChat"`
	EnableGameChat        bool `json:"enableGameChat"`
}

// GetFeatureFlags returns the current feature state, potentially from env vars
func GetFeatureFlags() FeatureFlags {
	return FeatureFlags{
		EnableDailyChallenges: getEnvBool("ENABLE_DAILY_CHALLENGES", true),
		EnableTournaments:     getEnvBool("ENABLE_TOURNAMENTS", false),
		EnableAdminDashboard:  getEnvBool("ENABLE_ADMIN_DASHBOARD", true),
		EnableVoiceChat:       getEnvBool("ENABLE_VOICE_CHAT", false),
		EnableGameChat:        getEnvBool("ENABLE_GAME_CHAT", false),
	}
}

func getEnvBool(key string, defaultVal bool) bool {
	val, exists := os.LookupEnv(key)
	if !exists {
		return defaultVal
	}
	return val == "true" || val == "1"
}
