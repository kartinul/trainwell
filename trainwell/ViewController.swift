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
        exerciseimage.contentMode = .scaleAspectFit
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


class OpenAIService {
    static let shared = OpenAIService()
    private let apiKey = "YOUR_OPENAI_API_KEY_HERE"

    func generatePlan(focus: String, completion: @escaping (WorkoutPlan?) -> Void) {
        if apiKey == "YOUR_OPENAI_API_KEY_HERE" {
            let mock = WorkoutPlan(week: [
                DayPlan(day: "Monday", rest: false, focus: "Upper Body", exercises: ["3-4_sit-up", "bench_dip_knees_bent", "body-up"]),
                DayPlan(day: "Tuesday", rest: false, focus: "Lower Body", exercises: ["bench_hip_extension", "jump_squat"]),
                DayPlan(day: "Wednesday", rest: true, focus: nil, exercises: nil),
                DayPlan(day: "Thursday", rest: false, focus: "Core", exercises: ["air_bike", "alternate_heel_touchers", "bottoms-up"]),
                DayPlan(day: "Friday", rest: false, focus: "Full Body", exercises: ["balance_board", "runners_stretch", "suspended_push-up"]),
                DayPlan(day: "Saturday", rest: true, focus: nil, exercises: nil),
                DayPlan(day: "Sunday", rest: false, focus: "Flexibility", exercises: ["butterfly_yoga_pose", "chest_and_front_of_shoulder_stretch"])
            ])
            DispatchQueue.main.async {
                completion(mock)
            }
            return
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Generate a 7-day workout plan based on this focus: "\(focus)".
        Use only these exercise IDs:
        3-4_sit-up, air_bike, alternate_heel_touchers, balance_board, bench_dip_knees_bent, bench_hip_extension, biceps_narrow_pull-ups, body-up, bottoms-up, butterfly_yoga_pose, chest_and_front_of_shoulder_stretch, isometric_chest_squeeze, jump_squat, reverse_hyper_on_flat_bench, runners_stretch, superman_push-up, suspended_push-up.
        Return ONLY a JSON object matching this structure:
        {"week": [{"day": "Monday", "rest": false, "focus": "Upper Body", "exercises": ["id1", "id2"]}, ...]}
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a fitness assistant returning JSON."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonDict["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let contentData = content.data(using: .utf8) {
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

    let backgroundImageView = UIImageView()
    let focusTextField = UITextField()
    let generateButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        view.backgroundColor = .black
        
        // Background (you can set an image if you have one, or just dark color)
        backgroundImageView.frame = view.bounds
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        view.addSubview(backgroundImageView)
        
        let titleLabel = UILabel()
        titleLabel.text = "TRAINWELL"
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "What do you want to focus on?"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        focusTextField.placeholder = "e.g. Upper body strength, cardio..."
        focusTextField.textColor = .white
        focusTextField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        focusTextField.layer.cornerRadius = 12
        focusTextField.layer.borderWidth = 1
        focusTextField.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 50))
        focusTextField.leftView = paddingView
        focusTextField.leftViewMode = .always
        focusTextField.translatesAutoresizingMaskIntoConstraints = false
        if let placeholder = focusTextField.placeholder {
            focusTextField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.lightGray])
        }
        view.addSubview(focusTextField)

        // Liquid Glass Button
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 16
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)

        generateButton.setTitle("Generate Plan", for: .normal)
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        blurView.contentView.addSubview(generateButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            focusTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            focusTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            focusTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            focusTextField.heightAnchor.constraint(equalToConstant: 50),

            blurView.topAnchor.constraint(equalTo: focusTextField.bottomAnchor, constant: 30),
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.widthAnchor.constraint(equalToConstant: 200),
            blurView.heightAnchor.constraint(equalToConstant: 56),

            generateButton.topAnchor.constraint(equalTo: blurView.topAnchor),
            generateButton.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
            generateButton.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            generateButton.trailingAnchor.constraint(equalTo: blurView.trailingAnchor)
        ])
    }

    @objc func generateTapped() {
        let focus = focusTextField.text?.isEmpty == false ? focusTextField.text! : "General fitness"
        generateButton.setTitle("Generating...", for: .normal)
        generateButton.isEnabled = false
        
        OpenAIService.shared.generatePlan(focus: focus) { [weak self] plan in
            self?.generateButton.setTitle("Generate Plan", for: .normal)
            self?.generateButton.isEnabled = true
            
            if let plan = plan {
                let weekVC = WeekViewController(plan: plan)
                self?.navigationController?.pushViewController(weekVC, animated: true)
            }
        }
    }
}
import UIKit

class WeekViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let plan: WorkoutPlan
    let tableView = UITableView()
    
    init(plan: WorkoutPlan) {
        self.plan = plan
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your Weekly Plan"
        view.backgroundColor = .black
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.register(DayCell.self, forCellReuseIdentifier: "DayCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plan.week.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DayCell", for: indexPath) as! DayCell
        cell.configure(with: plan.week[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let dayPlan = plan.week[indexPath.row]
        if dayPlan.rest == true { return }
        let dayVC = DayViewController(dayPlan: dayPlan)
        navigationController?.pushViewController(dayVC, animated: true)
    }
}

class DayCell: UITableViewCell {
    
    let containerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    let dayLabel = UILabel()
    let focusLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        dayLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        dayLabel.textColor = .white
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView.addSubview(dayLabel)
        
        focusLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        focusLabel.textColor = .lightGray
        focusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView.addSubview(focusLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            dayLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dayLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            
            focusLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 4),
            focusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            focusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(with dayPlan: DayPlan) {
        dayLabel.text = dayPlan.day
        if dayPlan.rest == true {
            focusLabel.text = "Rest Day"
            containerView.alpha = 0.5
        } else {
            focusLabel.text = dayPlan.focus ?? "Workout"
            containerView.alpha = 1.0
        }
    }
}
import UIKit

class DayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let dayPlan: DayPlan
    var exercises: [Exercise] = []
    let tableView = UITableView()
    let startButton = UIButton(type: .system)
    
    init(dayPlan: DayPlan) {
        self.dayPlan = dayPlan
        super.init(nibName: nil, bundle: nil)
        
        let allEx = ExerciseLibrary.all
        if let exIds = dayPlan.exercises {
            self.exercises = exIds.compactMap { id in allEx.first(where: { $0.id == id }) }
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = dayPlan.day
        view.backgroundColor = .black
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.register(ExerciseCell.self, forCellReuseIdentifier: "ExerciseCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 16
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        
        startButton.setTitle("Start Workout", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startWorkout), for: .touchUpInside)
        blurView.contentView.addSubview(startButton)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: blurView.topAnchor, constant: -20),
            
            blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.widthAnchor.constraint(equalToConstant: 200),
            blurView.heightAnchor.constraint(equalToConstant: 56),
            
            startButton.topAnchor.constraint(equalTo: blurView.topAnchor),
            startButton.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
            startButton.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: blurView.trailingAnchor)
        ])
    }
    
    @objc func startWorkout() {
        if exercises.isEmpty { return }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateInitialViewController() as? ViewController {
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
    
    let containerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    let titleLabel = UILabel()
    let durationLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView.addSubview(titleLabel)
        
        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        durationLabel.textColor = .lightGray
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView.addSubview(durationLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            durationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            durationLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(with exercise: Exercise) {
        titleLabel.text = exercise.name
        durationLabel.text = "\(exercise.duration)s"
    }
}
