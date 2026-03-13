# AEye Source Code Overview

This document describes how the three Swift source files work together to create the animated eye.

## Program Flow

When the app launches, `AEyeApp` creates an `EyeView`, which creates an `EyeMotionModel`. The model immediately starts three background loops that continuously update the eye's gaze position, blink state, and pupil size. `EyeView` observes those changing values and passes them into `EyeShape`, which redraws the eye every time any value changes. The user can interact with the eye through tap and long-press gestures.

---

## File 1: AEyeApp.swift

The app entry point. This is the simplest file — it just launches the main screen.

- Checks if the `-showAbout` flag was passed at launch (used for testing the About screen)
- Creates an `EyeView` as the root view
- Forces dark mode on the entire app

---

## File 2: EyeMotionModel.swift

The "brain" of the eye. This class holds all the eye's state and runs three independent animation loops. The view watches these values and redraws whenever they change.

### Published state (what the view reads)

| Property | Type | Range | Purpose |
|---|---|---|---|
| `currentGaze` | CGPoint | -1 to 1 on each axis | Where the eye is looking |
| `blinkAmount` | CGFloat | 0 (open) to 1 (closed) | How closed the eyelids are |
| `irisHue` | Double | 0.0 to 1.0 | Color of the iris (on the color wheel) |
| `irisSaturation` | Double | 0.0 to 1.0 | How vivid the iris color is |
| `irisBrightness` | Double | 0.0 to 1.0 | How light/dark the iris is |
| `pupilScale` | CGFloat | 0.22 to 0.40 | Base size of the pupil |
| `pupilPulse` | CGFloat | small +/- offset | Subtle dilation fluctuation |

### Functions

**`start()`** — Launches three concurrent async loops that run forever until cancelled:

1. **Gaze loop** — Picks a random point to look at, animates the eye there, then waits. Adds realism through:
   - *Center bias*: multiplies targets by 0.78 so the eye doesn't stare at edges too much
   - *Focus holds*: 1 in 6 chance of looking near center for longer (like staring at something)
   - *Micro-saccades*: 50% chance of a tiny involuntary jitter after each movement (the way real eyes work)
   - *Side-glances*: 1 in 11 chance of a quick sideways look and snap back
   - *Recentering*: if the eye looked too far to a side, it may drift back toward center

2. **Blink loop** — Waits 1.6-5.2 seconds, then blinks. After some blinks:
   - 1 in 3 chance of a brief pupil constriction (reflex after blinking)
   - 1 in 9 chance of a second quick blink right after (double-blink)

3. **Pupil loop** — Every 1.8-4.2 seconds, slightly changes the pupil size to simulate natural dilation

**`blink(speed:)`** — Animates `blinkAmount` from 0 to 1 (close) then back to 0 (open). Speed defaults to 0.09 seconds for a natural blink.

**`randomizeAppearance()`** — Called when the user taps the eye. Picks random values for iris color (hue, saturation, brightness) and pupil size, all animated over 0.28 seconds.

**`restoreDefaultAppearance()`** — Called on long press. Resets iris to the default blue (hue 0.56) and pupil to default size (0.30).

**`triggerBlink()`** — Fires a single blink. Called on single tap.

**`triggerDoubleBlink()`** — Fires two quick blinks with a 110ms gap. Called on triple tap.

**`stop()`** — Cancels all three loops. Called when the view disappears or when the user double-taps to pause.

**`clamp(_:min:max:)`** — Utility that keeps a value within a range. Used everywhere to prevent the gaze from going out of bounds.

---

## File 3: EyeView.swift

Contains all the visual code — three views that work together.

### EyeView (main screen)

The full-screen view the user sees. Black background with the eye centered.

**Setup:**
- Creates and owns the `EyeMotionModel` (as a `@StateObject`)
- Calculates the eye frame size using a fixed 362:320 aspect ratio that fits within the screen, so the eye looks the same on every device
- When the view appears, calls `model.start()` to begin the animation loops
- When the view disappears, calls `model.stop()` to clean up

**Gesture handling:**
- *Single tap*: triggers a blink and randomizes the iris color/pupil size, with a light haptic tap
- *Double tap*: pauses or resumes all motion (calls `stop()` or `start()`), shows a "Paused" badge
- *Triple tap*: triggers a double-blink with a rigid haptic
- *Long press (0.6s)*: restores the default blue iris and pupil size, with a medium haptic

**Other elements:**
- Info button (top right) opens the About screen as a sheet
- `toggleMotionPause()` handles the pause/resume logic and haptic feedback

### AboutView (info sheet)

A modal screen shown when tapping the info button. Contains:
- App title "AEye"
- Avatar image of Motu (loaded from the bundle — tries PNG, then JPG, then asset catalog)
- Attribution text crediting the builders
- Release notes
- Copyright notice
- "Done" button to dismiss

The `loadAvatarImage()` function tries three different ways to find the avatar image in the app bundle, since the image exists in multiple locations (loose files and asset catalog).

### EyeShape (the eye itself)

A self-contained view that draws the eye based on the values passed in. It does not know about the model — it just receives numbers and draws.

**Parameters it receives:** gaze position, blink amount, iris hue/saturation/brightness, pupil scale, pupil pulse.

**What it draws (back to front):**

1. **Sclera** (eye white) — A white ellipse with a subtle radial gradient (slightly gray at edges) and a thin gray border

2. **Iris + Pupil group** (moves together as one unit):
   - **Iris** — A circle filled with a 3-stop radial gradient using the hue/saturation/brightness values. Lighter in the center, darker at the edge.
   - **Iris ring** — A subtle white circle stroke around the iris edge
   - **Pupil** — A black circle in the center. Its size is `pupilScale + pupilPulse`, clamped between 0.18 and 0.46 of the iris diameter.
   - **Specular highlight** — A small white dot offset up and to the left, simulating light reflection

   This entire group uses `.drawingGroup()` which composites it into a single image before animating. This prevents the pupil from visually drifting ahead of the iris during fast movements. The group is then offset by `irisX`/`irisY` (computed from gaze position and max travel distances).

3. **Blink lids** — Two black rectangles (top and bottom) whose height is controlled by `blinkAmount`. At 0 they're invisible; at 1 they each cover half the eye, meeting in the middle.

4. **Clipping and border** — Everything is clipped to an ellipse shape, with a dark border stroke and a drop shadow underneath.

**How gaze offset works:** The gaze values (-1 to 1) are multiplied by maximum offsets (18% of width, 14% of height) to determine how far the iris moves from center. This keeps the iris within the sclera.
