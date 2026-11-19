cask "floating-camera" do
  version "1.3.0"
  sha256 "5a66e655bb099f89a8b83b87c669b86edabce813abbff0c40ab2348f39b6824f"

  url "https://github.com/neo22s/floating-cam/releases/download/v#{version}/FloatingCamera.zip"
  name "Floating Camera"
  desc "Menu bar app that keeps your camera floating above everything else"
  homepage "https://github.com/neo22s/floating-cam"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "FloatingCamera.app"

  postflight_steps do
    # The release is ad-hoc signed, so Gatekeeper refuses the first launch while
    # the quarantine flag is set. The app does the same on its own updates.
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/FloatingCamera.app"]
  end

  zap trash: "~/Library/Preferences/com.floatingcamera.app.plist"
end
