# trainwell TODO

## Done
- [x] Exercise data model (`Exercise.swift`, `ExerciseLibrary`)
- [x] `exercises.json` with 17 exercises + categories
- [x] Animated GIF playback (frame-by-frame, fast + 1s pause loop)
- [x] Basic workout timer (start / pause / reset / next)

---

## Left to Build

### 1. Home Screen
- Text input: "what do you want to focus on?"
- "Generate Plan" button
- New `HomeViewController` + storyboard scene

### 2. OpenAI Integration
- `POST` to OpenAI API with user's goal text
- Structured JSON response → weekly plan (7 days, rest days included)
- `WorkoutPlan.swift` + `DayPlan.swift` models

### 3. Weekly Plan Screen
- 7-day strip (Mon–Sun)
- Rest days shown differently (greyed out)
- Tap a day → that day's workout
- New `WeekViewController`

### 4. Day / Workout Screen
- List of exercises for the day
- Tap one → existing timer screen
- New `DayViewController`

### 5. Navigation
- Wire up: Home → Weekly Plan → Day → Workout timer
- Pass selected exercises to `ViewController`

### 6. Liquid Glass UI
- Apply `UIGlassEffect` to buttons + cards (iOS 26)
- Polish typography, spacing, colors
- Do this last as a full visual pass
