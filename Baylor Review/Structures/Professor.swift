import Foundation
import FirebaseFirestore

struct Professor: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let course: String
    let rating: Double
    let review: String
    let reviewerName: String
    let dateCreated: Date
    
    init(name: String, course: String, rating: Double, review: String, reviewerName: String) {
        self.name = name
        self.course = course
        self.rating = rating
        self.review = review
        self.reviewerName = reviewerName
        self.dateCreated = Date()
    }
}

struct ProfessorItem: Identifiable {
    let id: String
    let professor: Professor


    var createdAt: Date { professor.dateCreated }
}

struct ProfessorSummary: Identifiable {
    var id: String { name }
    let name: String
    let averageRating: Double
    let totalReviews: Int
    let courses: [String]
    let items: [ProfessorItem]      
}
