import UIKit
import Foundation
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
        
        if exercises.isEmpty {
            exercises = ExerciseLibrary.all
        }
        
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


struct DayPlan: Codable {
    let day: String
    let rest: Bool?
    let focus: String?
    let exercises: [String]?
}

struct WorkoutPlan: Codable {
    let week: [DayPlan]
}


class GeminiService {
    static let shared = GeminiService()

    func generatePlan(focus: String, completion: @escaping (WorkoutPlan?) -> Void) {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=\(Secrets.geminiAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are a fitness assistant returning ONLY JSON.
        Generate a 7-day workout plan based on this focus: "\(focus)".
        Use only these exercise IDs:
        3-4_sit-up, air_bike, alternate_heel_touchers, balance_board, bench_dip_knees_bent, bench_hip_extension, biceps_narrow_pull-ups, body-up, bottoms-up, butterfly_yoga_pose, chest_and_front_of_shoulder_stretch, isometric_chest_squeeze, jump_squat, reverse_hyper_on_flat_bench, runners_stretch, superman_push-up, suspended_push-up.
        Return a JSON object matching this structure:
        {"week": [{"day": "Monday", "rest": false, "focus": "Upper Body", "exercises": ["id1", "id2"]}, ...]}
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = jsonDict["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String,
                   let contentData = text.data(using: .utf8) {
                    let plan = try JSONDecoder().decode(WorkoutPlan.self, from: contentData)
                    DispatchQueue.main.async { completion(plan) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}


class HomeViewController: UIViewController {

    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var focusTextField: UITextField!
    @IBOutlet weak var generateButton: UIButton!
    @IBOutlet weak var blurView: UIVisualEffectView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "TRAINWELL"
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "What do you want to focus on?"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        if let bg = backgroundImageView {
            bg.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bg.topAnchor.constraint(equalTo: view.topAnchor),
                bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bg.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }

        if let blurView = blurView {
            blurView.layer.cornerRadius = 16
            blurView.clipsToBounds = true
            blurView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                blurView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
                blurView.widthAnchor.constraint(equalToConstant: 200),
                blurView.heightAnchor.constraint(equalToConstant: 56)
            ])
            
            if let btn = generateButton {
                btn.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    btn.topAnchor.constraint(equalTo: blurView.topAnchor),
                    btn.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
                    btn.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
                    btn.trailingAnchor.constraint(equalTo: blurView.trailingAnchor)
                ])
            }
        }
        
        if let tf = focusTextField {
            tf.borderStyle = .none
            tf.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            tf.layer.cornerRadius = 25
            tf.layer.borderWidth = 1
            tf.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            tf.textColor = .white
            tf.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            tf.tintColor = .white
            
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 50))
            tf.leftView = paddingView
            tf.leftViewMode = .always
            
            let rightPadding = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 50))
            tf.rightView = rightPadding
            tf.rightViewMode = .always
            
            if let placeholder = tf.placeholder {
                tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.6)])
            }
            tf.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tf.bottomAnchor.constraint(equalTo: blurView.topAnchor, constant: -30),
                tf.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
                tf.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
                tf.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            NSLayoutConstraint.activate([
                subtitleLabel.bottomAnchor.constraint(equalTo: tf.topAnchor, constant: -20),
                subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -40),
                titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }
    }

    @IBAction func generateTapped(_ sender: UIButton) {
        let focus = focusTextField.text?.isEmpty == false ? focusTextField.text! : "General fitness"
        
        generateButton.configuration?.showsActivityIndicator = true
        generateButton.setTitle("", for: .normal)
        generateButton.isEnabled = false
        
        GeminiService.shared.generatePlan(focus: focus) { [weak self] plan in
            self?.generateButton.configuration?.showsActivityIndicator = false
            self?.generateButton.setTitle("Generate Plan", for: .normal)
            self?.generateButton.isEnabled = true
            
            if let plan = plan {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let weekVC = storyboard.instantiateViewController(withIdentifier: "WeekViewController") as? WeekViewController {
                    weekVC.plan = plan
                    self?.navigationController?.pushViewController(weekVC, animated: true)
                }
            }
        }
    }
}
import UIKit

class WeekViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var plan: WorkoutPlan!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your Weekly Plan"
        
        if tableView != nil {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plan?.week.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DayCell", for: indexPath) as! DayCell
        if let dayPlan = plan?.week[indexPath.row] {
            cell.configure(with: dayPlan)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let dayPlan = plan?.week[indexPath.row] else { return }
        if dayPlan.rest == true { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let dayVC = storyboard.instantiateViewController(withIdentifier: "DayViewController") as? DayViewController {
            dayVC.dayPlan = dayPlan
            navigationController?.pushViewController(dayVC, animated: true)
        }
    }
}

class DayCell: UITableViewCell {
    
    @IBOutlet weak var containerView: UIVisualEffectView!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var focusLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        
        if let containerView = containerView {
            containerView.layer.cornerRadius = 16
            containerView.clipsToBounds = true
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
                containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
            
            if let dl = dayLabel {
                dl.translatesAutoresizingMaskIntoConstraints = false
                dl.font = .systemFont(ofSize: 22, weight: .bold)
                dl.textColor = .white
                NSLayoutConstraint.activate([
                    dl.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
                    dl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20)
                ])
            }
            if let fl = focusLabel {
                fl.translatesAutoresizingMaskIntoConstraints = false
                fl.font = .systemFont(ofSize: 16, weight: .medium)
                fl.textColor = UIColor.white.withAlphaComponent(0.7)
                NSLayoutConstraint.activate([
                    fl.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 4),
                    fl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                    fl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
                ])
            }
        }
    }
    
    func configure(with dayPlan: DayPlan) {
        dayLabel?.text = dayPlan.day
        if dayPlan.rest == true {
            focusLabel?.text = "Rest Day"
            containerView?.alpha = 0.5
        } else {
            focusLabel?.text = dayPlan.focus ?? "Workout"
            containerView?.alpha = 1.0
        }
    }
}
import UIKit

class DayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var dayPlan: DayPlan!
    var exercises: [Exercise] = []
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = dayPlan?.day
        
        let allEx = ExerciseLibrary.all
        if let exIds = dayPlan?.exercises {
            self.exercises = exIds.compactMap { id in allEx.first(where: { $0.id == id }) }
        }
        
        if tableView != nil {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        if let blurView = blurView {
            blurView.layer.cornerRadius = 16
            blurView.clipsToBounds = true
            blurView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        if let btn = startButton {
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.tintColor = .white
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
            if let blurView = blurView {
                NSLayoutConstraint.activate([
                    btn.topAnchor.constraint(equalTo: blurView.topAnchor),
                    btn.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
                    btn.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
                    btn.trailingAnchor.constraint(equalTo: blurView.trailingAnchor)
                ])
            }
        }
        
        if let tableView = tableView, let blurView = blurView {
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: blurView.topAnchor, constant: -20),
                
                blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                blurView.widthAnchor.constraint(equalToConstant: 200),
                blurView.heightAnchor.constraint(equalToConstant: 56)
            ])
        }
    }
    
    @IBAction func startWorkout(_ sender: UIButton) {
        if exercises.isEmpty { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "TimerViewController") as? ViewController {
            vc.exercises = self.exercises
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exercises.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath) as! ExerciseCell
        cell.configure(with: exercises[indexPath.row])
        return cell
    }
}

class ExerciseCell: UITableViewCell {
    
    @IBOutlet weak var containerView: UIVisualEffectView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        if let containerView = containerView {
            containerView.layer.cornerRadius = 12
            containerView.clipsToBounds = true
            containerView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
                containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
                containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
            
            if let tl = titleLabel {
                tl.translatesAutoresizingMaskIntoConstraints = false
                tl.font = .systemFont(ofSize: 18, weight: .semibold)
                tl.textColor = .white
                NSLayoutConstraint.activate([
                    tl.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
                    tl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16)
                ])
            }
            if let dl = durationLabel, let tl = titleLabel {
                dl.translatesAutoresizingMaskIntoConstraints = false
                dl.font = .systemFont(ofSize: 14, weight: .medium)
                dl.textColor = UIColor.white.withAlphaComponent(0.6)
                NSLayoutConstraint.activate([
                    dl.topAnchor.constraint(equalTo: tl.bottomAnchor, constant: 4),
                    dl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                    dl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
                ])
            }
        }
    }
    
    func configure(with exercise: Exercise) {
        titleLabel?.text = exercise.name
        durationLabel?.text = "\(exercise.duration)s"
    }
}
