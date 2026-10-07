import Foundation

struct HabitHeatmapWeek: Identifiable {
    let days: [HabitGridDay]
    var id: String { days[0].id }
}
