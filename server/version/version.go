package version

// Version is set at build time via -ldflags
var Version = "1.0.6"

// GetVersion returns the current server version
func GetVersion() string {
	if Version == "" {
		return "unknown"
	}
	return Version
}
