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

struct ProfessorSummary {
    let name: String
    let averageRating: Double
    let totalReviews: Int
    let courses: [String]
    let reviews: [Professor]
}

