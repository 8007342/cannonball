package main

import (
	"os"
	"path/filepath"
	"time"
)

// lock serialises verbs that write job files or ledgers (two watchers or an
// agent and a user running ingest together would otherwise lose entries).
func lock() func() {
	p := filepath.Join(cacheRoot(), "assets.lock")
	os.MkdirAll(cacheRoot(), 0o755)
	for i := 0; i < 600; i++ {
		f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
		if err == nil {
			f.Close()
			lockHeld = true
			return func() { os.Remove(p) }
		}
		if st, err := os.Stat(p); err == nil && time.Since(st.ModTime()) > 10*time.Minute {
			os.Remove(p) // stale lock from a killed run
			continue
		}
		time.Sleep(200 * time.Millisecond)
	}
	fatalf("lock busy: %s", p)
	return nil
}

var lockHeld bool
