# I Got Tired of My Face Being Stuck in a Box, So I Built Floating Camera

Okay, real talk: how many hours a day is your face trapped in a tiny rectangle in the corner of a Zoom call? For me it was… a lot. And every "floating webcam" tool I tried was either a bloated Electron monster eating half my RAM, a sketchy subscription app, or just plain ugly.

So I built the thing I actually wanted. It's called **Floating Camera**, it's native macOS, it's free, it's open source, and your face can now be a heart. You're welcome.

![Floating Camera floating over a desktop](../assets/hero.png)

## What even is this?

It's stupid simple, and that's the whole point. Floating Camera puts a little live preview of your camera **on top of everything else** on your Mac. No Dock icon. No window lost behind seventeen Chrome tabs. Just your beautiful face, floating there, judging your code.

It lives in the menu bar. You click the little aperture icon, pick your options, and get on with your life. That's the entire user manual. Well, almost — keep reading.

## The shapes are the whole personality

Look, a floating rectangle is fine. But a floating *star*? That's a statement.

![All eleven Floating Camera shapes](../assets/shapes.png)

There are **11 shapes**: Rectangle, Vertical Rectangle, Rounded Square, Square, Circle, Heart, Star, Hexagon, Pentagon, Diamond, and Capsule. Each one keeps its own aspect ratio when you resize, and you can slap a border on it, tweak the opacity, round the corners, and zoom the image inside from 100% to 300%.

Personal tier list, no one asked:

- **Circle** — the classic. Safe, clean, makes you look like a YouTube tutorial person.
- **Capsule** — weirdly great for screen recordings. Just saying.
- **Heart** — for when you want HR to remember you.
- **Star** — maximum chaos. Use sparingly. Or don't. I'm not your boss.

And the newest addition: **Vertical Rectangle (9:16)**. It crops the sides of your camera feed so you get that tall phone-video look — perfect if you're recording vertical content, or if you just want your floating head to take up a comically tall slice of your screen. It supports rounded corners too, obviously.

## But wait, there's actual engineering in here

Under the hood it's 100% native Swift and AppKit — **zero dependencies**, zero Electron, zero nonsense. The camera runs on a background thread, the preview is hardware-accelerated through AVFoundation, and it sips CPU (like 5–9% on a MacBook Air). And here's my favorite part: when you hit **Hide Camera** (`⌃⌥H` from anywhere), it doesn't just hide the window — it **kills the camera session completely**. Camera light off, CPU to zero. Your laptop fans can finally shut up.

Other stuff it does:

- **Camera picker** with 480p / 720p / 1080p and 15–60 fps, with graceful fallback if your camera doesn't support your pick
- **Mirror toggle**, **Always on Top**, works across Spaces and in full-screen apps
- **Right-click the overlay** for quick Hide / Reset Position / Quit — it even steals focus politely to make the menu work
- **Auto-updates** from GitHub Releases (checks once every 30 days, no nagging, no telemetry, no account, no phone-home anything)
- **English or Spanish UI**, follows your system language by default

The whole settings model is a tiny JSON blob in UserDefaults. Old settings files still load fine when new versions add stuff. Boring, reliable, the way I like it.

## Get it

It's free and MIT-licensed. Grab the latest `FloatingCamera.zip` from the [releases page](https://github.com/neo22s/floating-cam/releases), unzip, drag to `/Applications`, allow camera access when macOS asks, and you're floating.

```bash
git clone https://github.com/neo22s/floating-cam.git
cd floating-cam
./build.sh --universal
./test.sh
```

That's it. No package manager drama, no 2GB `node_modules`. Just `swiftc` and vibes.

## What's next?

Honestly? Whatever annoys me first. The vertical rectangle shape came from wanting better vertical-video framing, so the roadmap is basically "things that bug me during real calls." Got an idea — a shape, a hotkey, a feature? Open an issue or send a PR. The codebase is small on purpose; you can read the whole thing on a lunch break.

Now if you'll excuse me, I have a meeting to attend as a floating hexagon.
