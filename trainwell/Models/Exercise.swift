import Foundation

struct Exercise: Codable {
    let id: String
    let name: String
    let category: String
    let videoFile: String
    let duration: Int
}

struct ExerciseLibrary {
    static var all: [Exercise] = {
        let url = Bundle.main.url(forResource: "exercises", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode([Exercise].self, from: data)
    }()
}
