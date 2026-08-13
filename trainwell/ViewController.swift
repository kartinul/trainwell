import UIKit
import ImageIO

class ViewController: UIViewController {

    @IBOutlet var exerciseimage: UIImageView!
    @IBOutlet var exercisename: UILabel!
    @IBOutlet var timer: UILabel!

    var exercises: [Exercise] = []
    var currentexercise = 0
    var countdown = 60
    var timerobject: Timer?

    var gifFrames: [UIImage] = []
    var gifFrameDelays: [Double] = []
    var gifFrame = 0
    var gifTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        exercises = ExerciseLibrary.all
        exerciseimage.contentMode = .scaleAspectFit
        showExercise(at: 0)
    }

    @IBAction func startbuttontapped(_ sender: UIButton) {
        timerobject?.invalidate()
        timerobject = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.countdown > 0 {
                self.countdown -= 1
                self.timer.text = self.formatTime(self.countdown)
            } else {
                self.timerobject?.invalidate()
                self.currentexercise = (self.currentexercise + 1) % self.exercises.count
                self.showExercise(at: self.currentexercise)
            }
        }
    }

    @IBAction func pausebuttontapped(_ sender: UIButton) {
        timerobject?.invalidate()
    }

    @IBAction func resetbuttontapped(_ sender: UIButton) {
        timerobject?.invalidate()
        countdown = exercises[currentexercise].duration
        timer.text = formatTime(countdown)
    }

    @IBAction func nextbuttontapped(_ sender: UIButton) {
        timerobject?.invalidate()
        currentexercise = (currentexercise + 1) % exercises.count
        showExercise(at: currentexercise)
    }

    func showExercise(at index: Int) {
        let ex = exercises[index]
        exercisename.text = ex.name
        countdown = ex.duration
        timer.text = formatTime(countdown)
        loadGIF(named: ex.videoFile)
    }

    func loadGIF(named filename: String) {
        gifTimer?.invalidate()
        gifFrames = []
        gifFrameDelays = []
        gifFrame = 0

        guard let path = Bundle.main.path(forResource: filename, ofType: nil),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cg = CGImageSourceCreateImageAtIndex(source, i, nil) {
                gifFrames.append(UIImage(cgImage: cg))
            }
            var delay = 0.08
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                delay = (gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                      ?? gif[kCGImagePropertyGIFDelayTime as String] as? Double
                      ?? 0.08) * 0.6
            }
            gifFrameDelays.append(max(delay, 0.02))
        }

        tickGIF()
    }

    func tickGIF() {
        guard !gifFrames.isEmpty else { return }
        let delay = gifFrameDelays[gifFrame]
        gifTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.exerciseimage.image = self.gifFrames[self.gifFrame]
            self.gifFrame += 1
            if self.gifFrame >= self.gifFrames.count {
                self.gifFrame = 0
                self.gifTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    self.tickGIF()
                }
            } else {
                self.tickGIF()
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
