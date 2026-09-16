import AppKit
import Foundation

struct ProjectSymbol {
    let name: String
    let systemName: String
    let category: String
    let keywords: String
    init(name: String, systemName: String, category: String = "Essentials", keywords: String = "") {
        self.name = name; self.systemName = systemName; self.category = category; self.keywords = keywords
    }
    static let categories = ["Essentials", "Work", "Technology", "Learning", "Travel", "Home", "Nature", "Leisure", "Shapes"]
    // Saved projects refer to these indices. Keep the original 24 first and
    // append new choices; filter unavailable symbols without renumbering them.
    static let palette: [ProjectSymbol] = {
        var values: [ProjectSymbol] = [
        .init(name: "Layers", systemName: "square.stack.3d.up.fill"),
        .init(name: "Pencil", systemName: "pencil", keywords: "writing drawing edit"),
        .init(name: "Folder", systemName: "folder.fill"),
        .init(name: "Sparkles", systemName: "sparkles"),
        .init(name: "Book", systemName: "book.closed.fill", keywords: "reading writing library"),
        .init(name: "Flame", systemName: "flame.fill"),
        .init(name: "Sailboat", systemName: "sailboat.fill", keywords: "boat yacht sailing ocean sea"),
        .init(name: "Leaf", systemName: "leaf.fill"),
        .init(name: "Bolt", systemName: "bolt.fill"),
        .init(name: "Globe", systemName: "globe.americas.fill"),
        .init(name: "Mountain", systemName: "mountain.2.fill"),
        .init(name: "Flag", systemName: "flag.fill"),
        .init(name: "Hammer", systemName: "hammer.fill"),
        .init(name: "Lightbulb", systemName: "lightbulb.fill"),
        .init(name: "House", systemName: "house.fill"),
        .init(name: "Chart", systemName: "chart.bar.fill"),
        .init(name: "Graduation cap", systemName: "graduationcap.fill"),
        .init(name: "Puzzle", systemName: "puzzlepiece.fill"),
        .init(name: "Star", systemName: "star.fill"),
        .init(name: "Camera", systemName: "camera.fill"),
        .init(name: "Paper plane", systemName: "paperplane.fill"),
        .init(name: "Heart", systemName: "heart.fill"),
        .init(name: "Headphones", systemName: "headphones"),
        .init(name: "Cup", systemName: "cup.and.saucer.fill")
        ]
        values += group("Work", """
    Briefcase|briefcase.fill|job business office
    Calendar|calendar|date schedule appointment
    Checklist|checklist|tasks todo
    Clipboard|list.clipboard.fill|tasks notes
    Document|doc.text.fill|report writing paper
    Documents|doc.on.doc.fill|copy files
    Signature|signature|contract writing
    Envelope|envelope.fill|email mail letter
    Inbox|tray.fill|mail messages
    Archive|archivebox.fill|storage files
    Bubble|bubble.left.fill|chat discussion
    Conversation|bubble.left.and.bubble.right.fill|chat messages
    People|person.2.fill|team collaboration
    Person|person.fill|profile contact
    Presentation|rectangle.on.rectangle.angled|slides deck meeting
    Building|building.2.fill|office company city
    Store|storefront.fill|shop retail business
    Credit card|creditcard.fill|money payment
    Banknote|banknote.fill|cash finance money
    Pie chart|chart.pie.fill|analysis data finance
    Trend|chart.line.uptrend.xyaxis|growth finance data
    Tag|tag.fill|label category
    Megaphone|megaphone.fill|marketing announcement
    Stamp|seal.fill|approval badge
    """)
        values += group("Technology", """
    Desktop|desktopcomputer|computer mac monitor
    Laptop|laptopcomputer|computer mac
    Phone|iphone|mobile ios app
    Tablet|ipad|mobile drawing
    Watch|applewatch|wearable time
    Keyboard|keyboard.fill|typing computer
    Mouse|computermouse.fill|computer pointer
    Terminal|terminal.fill|code programming shell
    Code|chevron.left.forwardslash.chevron.right|programming development software
    Curly braces|curlybraces|code json programming
    CPU|cpu.fill|chip hardware ai
    Memory|memorychip.fill|hardware data
    Circuit|cpu|processor hardware
    Server|server.rack|backend database hosting
    Drive|externaldrive.fill|storage disk
    Network|network|internet connection
    Wi-Fi|wifi|wireless internet
    Antenna|antenna.radiowaves.left.and.right|signal radio
    Cloud|cloud.fill|hosting sync
    Gear|gearshape.fill|settings configuration
    Tools|wrench.and.screwdriver.fill|engineering maintenance
    Bug|ladybug.fill|testing debug code
    Shield|shield.fill|security protection
    Lock|lock.fill|security password
    """)
        values += group("Learning", """
    Open book|book.fill|reading library study
    Books|books.vertical.fill|library research
    Textbook|text.book.closed.fill|school study
    Bookmark|bookmark.fill|reading saved
    Scroll|scroll.fill|history writing
    Ruler|ruler.fill|math measure length
    Drawing tools|pencil.and.ruler.fill|design geometry math
    Paintbrush|paintbrush.fill|art design
    Palette|paintpalette.fill|art color design
    Atom|atom|science physics
    Flask|flask.fill|science chemistry experiment
    Test tube|testtube.2|science chemistry lab
    Brain|brain.head.profile|thinking learning psychology ai
    Sum|sum|math mathematics addition
    Function|function|math mathematics algebra
    Percent|percent|math mathematics finance
    Divide|divide|math mathematics fractions
    Multiply|multiply|math mathematics arithmetic
    Equals|equal|math mathematics equation
    Plus and minus|plusminus|math mathematics arithmetic
    Number|number|math mathematics count
    Infinity|infinity|math mathematics
    Geometry|triangle.righthalf.filled|math mathematics shapes
    Search|magnifyingglass|research find
    """)
        values += group("Travel", """
    Airplane|airplane|flight airport holiday
    Takeoff|airplane.departure|flight airport holiday
    Landing|airplane.arrival|flight airport
    Car|car.fill|drive road automobile
    Bus|bus.fill|transport school
    Tram|tram.fill|train rail transport
    Ferry|ferry.fill|boat yacht ship sea
    Fuel pump|fuelpump.fill|marina petrol gas boat car
    Bicycle|bicycle|bike cycling transport
    Scooter|scooter|transport
    Walking|figure.walk|hiking travel
    Map|map.fill|navigation location
    Map pin|mappin.and.ellipse|location destination
    Compass|location.north.circle.fill|navigation direction
    Navigation|location.fill|route direction
    Route|point.topleft.down.curvedto.point.bottomright.up|journey path
    Suitcase|suitcase.fill|luggage trip holiday
    Backpack|backpack.fill|hiking school trip
    Tent|tent.fill|camping outdoors
    Beach|beach.umbrella.fill|holiday sea summer
    Landmark|building.columns.fill|museum architecture tourism
    Globe grid|globe|world international
    Ticket|ticket.fill|booking event travel
    Identity card|person.text.rectangle.fill|passport travel
    """)
        values += group("Home", """
    Bed|bed.double.fill|bedroom sleep hotel
    Sofa|sofa.fill|living room furniture
    Chair|chair.fill|furniture office
    Table|table.furniture.fill|desk furniture
    Lamp|lamp.desk.fill|lighting desk
    Ceiling light|lightbulb.led.fill|lighting electricity
    Door|door.left.hand.open|entrance building
    Window|window.vertical.open|building ventilation
    Key|key.fill|home security
    Fan|fan.fill|cooling ventilation
    Air conditioner|air.conditioner.horizontal.fill|cooling heating hvac
    Thermometer|thermometer.medium|temperature heating weather
    Radiator|heater.vertical.fill|heating home energy
    Faucet|spigot.fill|water plumbing
    Shower|shower.fill|bathroom water
    Bathtub|bathtub.fill|bathroom
    Washer|washer.fill|laundry clothes
    Dryer|dryer.fill|laundry clothes
    Refrigerator|refrigerator.fill|kitchen food
    Oven|oven.fill|kitchen cooking
    Dishwasher|dishwasher.fill|kitchen cleaning
    Stove|cooktop.fill|kitchen cooking
    Bin|trash.fill|recycling cleaning
    Shipping box|shippingbox.fill|delivery packing storage
    """)
        values += group("Nature", """
    Sun|sun.max.fill|day weather summer
    Moon|moon.fill|night astronomy space
    Stars|moon.stars.fill|night astronomy space
    Sunrise|sunrise.fill|morning dawn
    Sunset|sunset.fill|evening dusk
    Rain|cloud.rain.fill|weather water
    Snow|snowflake|winter weather ice
    Storm|cloud.bolt.rain.fill|weather lightning
    Wind|wind|weather air energy
    Rainbow|rainbow|weather color
    Drop|drop.fill|water rain
    Waves|water.waves|ocean sea boat
    Tree|tree.fill|forest woods plants
    Branch|laurel.leading|plants garden leaf
    Flower|camera.macro|garden plants
    Carrot|carrot.fill|garden food vegetable
    Paw|pawprint.fill|animals pets tracks
    Dog|dog.fill|animals pets
    Cat|cat.fill|animals pets
    Bird|bird.fill|animals flight
    Fish|fish.fill|animals ocean fishing
    Tortoise|tortoise.fill|animals turtle
    Hare|hare.fill|animals rabbit
    Ant|ant.fill|animals insect
    """)
        values += group("Leisure", """
    Music|music.note|song audio
    Guitar|guitars.fill|music instrument
    Piano|pianokeys|music instrument
    Microphone|mic.fill|voice audio podcast
    Speaker|speaker.wave.2.fill|sound audio
    Film|film.fill|movie cinema video
    Video camera|video.fill|movie recording
    Television|tv.fill|screen video entertainment
    Game controller|gamecontroller.fill|gaming play
    Dice|dice.fill|game random probability
    Playing cards|suit.spade.fill|game poker
    Trophy|trophy.fill|win award sport
    Medal|medal.fill|award sport
    Football|soccerball|sports ball
    Basketball|basketball.fill|sports ball
    Tennis|tennisball.fill|sports ball
    Baseball|baseball.fill|sports ball
    Dumbbell|dumbbell.fill|fitness gym exercise
    Running|figure.run|fitness sport exercise
    Swimming|figure.pool.swim|water sport exercise
    Gift|gift.fill|birthday celebration
    Party|party.popper.fill|celebration birthday
    Food|fork.knife|restaurant meal cooking
    Wine|wineglass.fill|drink tasting restaurant
    """)
        values += group("Shapes", """
    Circle|circle.fill|shape round
    Square|square.fill|shape
    Triangle|triangle.fill|shape geometry
    Diamond|diamond.fill|shape geometry
    Hexagon|hexagon.fill|shape geometry
    Pentagon|pentagon.fill|shape geometry
    Octagon|octagon.fill|shape geometry
    Capsule|capsule.fill|shape
    Cube|cube.fill|shape 3d model
    Dotted circle|circle.dotted|shape round
    Target|scope|aim focus goal
    Burst|burst.fill|shape badge
    Asterisk|asterisk|shape star
    Checkmark|checkmark.circle.fill|done complete
    Question|questionmark.circle.fill|help research
    Exclamation|exclamationmark.triangle.fill|attention alert
    Arrow up|arrow.up.circle.fill|direction
    Arrow right|arrow.right.circle.fill|direction
    Arrow down|arrow.down.circle.fill|direction
    Arrow left|arrow.left.circle.fill|direction
    Cycle|arrow.triangle.2.circlepath|repeat refresh
    Link|link|connection relationship
    Grid|square.grid.2x2.fill|layout dashboard
    Pin|pin.fill|important saved
    """)
        return values
    }()
    private static func group(_ category: String, _ rows: String) -> [ProjectSymbol] {
        rows.split(separator: "\n").map { row in
            let parts = row.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            return ProjectSymbol(name: parts[0], systemName: parts[1], category: category, keywords: parts[2])
        }
    }
    static let availableIndices = palette.indices.filter { NSImage(systemSymbolName: palette[$0].systemName, accessibilityDescription: nil) != nil }
    static func matchingIndices(query: String, category: String?) -> [Int] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace)
        return availableIndices.filter { index in
            let symbol = palette[index]
            let text = "\(symbol.name) \(symbol.systemName) \(symbol.category) \(symbol.keywords)".lowercased()
            return (category == nil || symbol.category == category) && terms.allSatisfy {
                text.contains($0) || ($0.count > 3 && $0.hasSuffix("s") && text.contains($0.dropLast()))
            }
        }
    }
    static func nextIndex(in projects: [Project]) -> Int {
        let used = Set(projects.compactMap(\.symbolIndex))
        return availableIndices.first { !used.contains($0) } ?? availableIndices[projects.count % availableIndices.count]
    }
}
