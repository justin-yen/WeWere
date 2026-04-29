import Foundation

enum TestEventData {
    static let names: [String] = [
        "Saturday Night Vibes", "Rooftop Sessions", "Summer Solstice Party",
        "Midnight in Manhattan", "Neon Dreams", "Friday After Work",
        "Birthday Bash", "Housewarming", "Vinyl Night", "Backyard BBQ",
        "Disco Fever", "Late Night Diner Crew", "Sunset Soirée",
        "New Year's Eve '26", "Graduation Night", "Farewell Friends",
        "Dinner Party", "Wine & Cheese", "Game Night", "Karaoke Chaos",
        "Pool Party", "Beach Bonfire", "Cabin Weekend", "Camping Trip",
        "Ski Trip", "Mountain Retreat", "City Lights Tour", "Art Gallery Opening",
        "Book Club Reunion", "Poker Night", "Jazz Lounge", "Speakeasy Pop-Up",
        "Secret Garden Party", "Masquerade Ball", "Costume Party", "Halloween Bash",
        "Holiday Get-Together", "Christmas Eve Gathering", "Friendsgiving",
        "Super Bowl Sunday", "March Madness Watch", "World Cup Finals",
        "Engagement Party", "Bachelor's Last Ride", "Bachelorette Bash",
        "Baby Shower", "Gender Reveal", "Welcome Home Party", "Going Away Party",
        "Promotion Celebration", "Launch Party", "Opening Night", "Album Release",
        "Art Opening", "Gallery Show", "Studio Visit", "Film Screening",
        "Trivia Night", "Comedy Club", "Open Mic", "Drag Show",
        "Drag Brunch", "Sunday Funday", "Brunch Squad", "Dim Sum Sunday",
        "Taco Tuesday", "Wine Wednesday", "Thirsty Thursday", "Tipsy Tuesday",
        "Supper Club", "Potluck Gathering", "Pizza Party", "Taco Fiesta",
        "Sushi Night", "Cocktail Hour", "Tiki Night", "Mezcal Monday",
        "Rave Cave", "Warehouse Party", "Basement Show", "DIY Venue Jam",
        "Block Party", "Street Festival", "Farmers Market Meetup", "Bike Ride Social",
        "Running Club Meet", "Yoga in the Park", "Pilates Pop-Up", "Dance Class",
        "Salsa Night", "Swing Dance", "Two-Step Tuesday", "Line Dance Party",
        "Lake Day", "River Float", "Picnic in the Park", "Botanical Gardens Tour",
        "Museum Night", "First Thursday", "Gallery Hop", "Street Food Crawl",
        "Arcade Night", "Bowling Lanes", "Mini Golf Madness",
    ]

    static let descriptions: [String] = [
        "Pull up with good vibes and better stories. We're keeping it loose.",
        "Come hungry, leave happy. BYOB, we'll handle the rest.",
        "Low-key hang. No pressure, just good people and great music.",
        "Let's make some memories. Full bar, live DJ, plus-ones welcome.",
        "All night, everybody sing. The playlist is already questionable.",
        "We're keeping this one tight. First 30 in, no creeps, all love.",
        "Casual attire, wild energy. Ends when it ends.",
        "Bring your camera — or don't. We're developing these ourselves.",
        "Something we'll talk about for years. Don't miss it.",
        "Just a bunch of us and a bunch of snacks.",
        "If you know, you know. See you there.",
        "Dress code: whatever makes you feel like a main character.",
        "The kind of night that turns into a story.",
        "No agenda. Just pretending adulthood isn't exhausting.",
        "Let's ruin our circadian rhythms together.",
    ]

    // Hand-picked Unsplash URLs — party / event / gathering vibes
    static let coverPhotos: [String] = [
        "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200",
        "https://images.unsplash.com/photo-1530103862676-de8c9debad1d?w=1200",
        "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200",
        "https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6a3?w=1200",
        "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=1200",
        "https://images.unsplash.com/photo-1496337589254-7e19d01cec44?w=1200",
        "https://images.unsplash.com/photo-1527529482837-4698179dc6ce?w=1200",
        "https://images.unsplash.com/photo-1485872299712-c274ec96a166?w=1200",
        "https://images.unsplash.com/photo-1566737236500-c8ac43014a67?w=1200",
        "https://images.unsplash.com/photo-1504680177321-2e6a879aac86?w=1200",
        "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=1200",
        "https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?w=1200",
        "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1200",
        "https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=1200",
        "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=1200",
    ]

    /// Returns a NYC-based randomized test event payload.
    static func random() -> TestEventPayload {
        let now = Date()
        // Previous hour, on the hour
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        comps.hour = (comps.hour ?? 0) - 1
        let startTime = cal.date(from: comps) ?? now.addingTimeInterval(-3600)

        return TestEventPayload(
            name: names.randomElement() ?? "Test Event",
            description: descriptions.randomElement() ?? "A great night.",
            locationName: "New York City, NY",
            locationAddress: "New York, NY, USA",
            locationLat: 40.7128,
            locationLng: -74.0060,
            startTime: startTime,
            coverPhotoUrl: coverPhotos.randomElement() ?? ""
        )
    }
}

struct TestEventPayload {
    let name: String
    let description: String
    let locationName: String
    let locationAddress: String
    let locationLat: Double
    let locationLng: Double
    let startTime: Date
    let coverPhotoUrl: String
}
