# trainwell TODO

## Done
- [x] Exercise data model (`Exercise.swift`, `ExerciseLibrary`)
- [x] `exercises.json` with 17 exercises + categories
- [x] Animated GIF playback (frame-by-frame, fast + 1s pause loop)
- [x] Basic workout timer (start / pause / reset / next)

---

## Left to Build

### 1. Home Screen
- [x] Text input: "what do you want to focus on?"
- [x] "Generate Plan" button
- [x] New `HomeViewController` + storyboard scene

### 2. OpenAI Integration
- [x] `POST` to OpenAI API with user's goal text
- [x] Structured JSON response → weekly plan (7 days, rest days included)
- [x] `WorkoutPlan.swift` + `DayPlan.swift` models

### 3. Weekly Plan Screen
- [x] 7-day strip (Mon–Sun)
- [x] Rest days shown differently (greyed out)
- [x] Tap a day → that day's workout
- [x] New `WeekViewController`

### 4. Day / Workout Screen
- [x] List of exercises for the day
- [x] Tap one → existing timer screen
- [x] New `DayViewController`

### 5. Navigation
- [x] Wire up: Home → Weekly Plan → Day → Workout timer
- [x] Pass selected exercises to `ViewController`

### 6. Liquid Glass UI
- [x] Apply `UIGlassEffect` to buttons + cards (iOS 26) -> (Used UIBlurEffect for actual iOS support)
- [x] Polish typography, spacing, colors
- [x] Do this last as a full visual pass
