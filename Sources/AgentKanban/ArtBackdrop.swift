import KanbananaCore
import AppKit
import ImageIO
import SwiftUI

struct BackdropArtwork: Identifiable {
    let id: String
    let title: String
    let credit: String
    let medium: String
    let date: String
    let filename: String
    let license: String
    let imageCredit: String
    let source: URL
    let article: URL
    var focalPoint = CGPoint(x: 0.5, y: 0.5)
    var zoom: CGFloat = 1
    var caption: String { "\(title) — \(credit), \(date)" }
}

enum ArtBackdrop {
    // Recognizable works across art history. Crops keep a figure or defining feature in view.
    // Resources/Art/catalog.json retains image provenance and per-file reuse terms.
    static let artworks: [BackdropArtwork] = [
        .init(id: "lascaux", title: "Hall of the Bulls, Lascaux", credit: "Paleolithic artists",
              medium: "Cave painting", date: "c. 17,000–15,000 BCE", filename: "lascaux.jpg", license: "Public domain", imageCredit: "Photograph by EU (Wikimedia Commons)",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Lascaux_painting.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Lascaux")!, focalPoint: .init(x: 0.46, y: 0.47), zoom: 1.15),
        .init(id: "willendorf", title: "Venus of Willendorf", credit: "Paleolithic sculptor",
              medium: "Limestone sculpture", date: "c. 28,000–25,000 BCE", filename: "willendorf.jpg", license: "CC BY 2.5", imageCredit: "Photograph by MatthiasKabel",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Venus_von_Willendorf_01.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Venus_of_Willendorf")!, focalPoint: .init(x: 0.5, y: 0.45), zoom: 1.05),
        .init(id: "nefertiti", title: "Nefertiti Bust", credit: "Attributed to Thutmose",
              medium: "Painted limestone", date: "c. 1345 BCE", filename: "nefertiti.jpg", license: "CC BY-SA 3.0", imageCredit: "Photograph by Philip Pikart",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Nofretete_Neues_Museum.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Nefertiti_Bust")!, focalPoint: .init(x: 0.5, y: 0.32), zoom: 1.1),
        .init(id: "winged-victory", title: "Winged Victory of Samothrace", credit: "Hellenistic sculptor",
              medium: "Marble sculpture", date: "c. 190 BCE", filename: "winged-victory.jpg", license: "CC0", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Victoire_de_Samothrace_-_Musee_du_Louvre_-_20190812.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Winged_Victory_of_Samothrace")!, focalPoint: .init(x: 0.5, y: 0.4), zoom: 1.15),
        .init(id: "laocoon", title: "Laocoön and His Sons", credit: "Rhodian sculptors",
              medium: "Marble sculpture", date: "c. 1st century BCE–1st century CE", filename: "laocoon.jpg", license: "CC0", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Laoco%C3%B6n_and_his_sons_group.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Laoco%C3%B6n_and_His_Sons")!, focalPoint: .init(x: 0.5, y: 0.44), zoom: 1.15),
        .init(id: "nataraja", title: "Shiva as Lord of the Dance", credit: "Chola-period sculptor",
              medium: "Bronze sculpture", date: "c. 950–1000", filename: "nataraja.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Shiva_as_the_Lord_of_Dance_LACMA_edit.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Nataraja")!, focalPoint: .init(x: 0.5, y: 0.42), zoom: 1.15),
        .init(id: "fan-kuan", title: "Travelers Among Mountains and Streams", credit: "Fan Kuan",
              medium: "Ink and color on silk", date: "c. 1000", filename: "fan-kuan.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Fan_Kuan_-_Travelers_Among_Mountains_and_Streams_-_Google_Art_Project.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Fan_Kuan")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "lamentation", title: "Lamentation", credit: "Giotto",
              medium: "Fresco", date: "c. 1304–06", filename: "lamentation.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Compianto_sul_Cristo_morto.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Lamentation_(The_Mourning_of_Christ)")!, focalPoint: .init(x: 0.4, y: 0.63), zoom: 1.15),
        .init(id: "arnolfini", title: "The Arnolfini Portrait", credit: "Jan van Eyck",
              medium: "Oil painting", date: "1434", filename: "arnolfini.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Arnolfini_portrait_(1434).jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Arnolfini_Portrait")!, focalPoint: .init(x: 0.49, y: 0.42), zoom: 1.1),
        .init(id: "birth-venus", title: "The Birth of Venus", credit: "Sandro Botticelli",
              medium: "Tempera painting", date: "c. 1484–86", filename: "birth-venus.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Sandro_Botticelli_-_La_nascita_di_Venere_-_Google_Art_Project_-_edited.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Birth_of_Venus")!, focalPoint: .init(x: 0.53, y: 0.44), zoom: 1.1),
        .init(id: "mona-lisa", title: "Mona Lisa", credit: "Leonardo da Vinci",
              medium: "Oil painting", date: "c. 1503–19", filename: "mona-lisa.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Mona_Lisa.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Mona_Lisa")!, focalPoint: .init(x: 0.52, y: 0.4), zoom: 1.1),
        .init(id: "creation-adam", title: "The Creation of Adam", credit: "Michelangelo",
              medium: "Fresco", date: "c. 1511", filename: "creation-adam.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Michelangelo_-_Creation_of_Adam_(cropped).jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Creation_of_Adam")!, focalPoint: .init(x: 0.38, y: 0.43), zoom: 1.1),
        .init(id: "earthly-delights", title: "The Garden of Earthly Delights", credit: "Hieronymus Bosch",
              medium: "Oil painting", date: "c. 1490–1510", filename: "earthly-delights.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Garden_of_earthly_delights.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Garden_of_Earthly_Delights")!, focalPoint: .init(x: 0.51, y: 0.6), zoom: 1.15),
        .init(id: "athens", title: "The School of Athens", credit: "Raphael",
              medium: "Fresco", date: "1509–11", filename: "athens.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:%22The_School_of_Athens%22_by_Raffaello_Sanzio_da_Urbino.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_School_of_Athens")!, focalPoint: .init(x: 0.52, y: 0.52), zoom: 1.15),
        .init(id: "benin-mask", title: "Queen Mother Pendant Mask: Iyoba", credit: "Edo artist, Kingdom of Benin",
              medium: "Ivory sculpture", date: "16th century", filename: "benin-mask.jpg", license: "CC0", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Queen_Mother_Pendant_Mask-_Iyoba_MET_DP231460.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Benin_ivory_mask")!, focalPoint: .init(x: 0.5, y: 0.43), zoom: 1.1),
        .init(id: "harvesters", title: "The Harvesters", credit: "Pieter Bruegel the Elder",
              medium: "Oil painting", date: "1565", filename: "harvesters.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Pieter_Bruegel_the_Elder-_The_Harvesters_-_Google_Art_Project.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Harvesters_(painting)")!, focalPoint: .init(x: 0.53, y: 0.6), zoom: 1.1),
        .init(id: "saint-matthew", title: "The Calling of Saint Matthew", credit: "Caravaggio",
              medium: "Oil painting", date: "1599–1600", filename: "saint-matthew.jpg", license: "CC0", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Caravaggio_%E2%80%94_The_Calling_of_Saint_Matthew.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Calling_of_Saint_Matthew")!, focalPoint: .init(x: 0.64, y: 0.44), zoom: 1.1),
        .init(id: "las-meninas", title: "Las Meninas", credit: "Diego Velázquez",
              medium: "Oil painting", date: "1656", filename: "las-meninas.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Las_Meninas,_by_Diego_Vel%C3%A1zquez,_from_Prado_in_Google_Earth.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Las_Meninas")!, focalPoint: .init(x: 0.51, y: 0.54), zoom: 1.15),
        .init(id: "night-watch", title: "The Night Watch", credit: "Rembrandt",
              medium: "Oil painting", date: "1642", filename: "night-watch.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:La_ronda_de_noche,_por_Rembrandt_van_Rijn.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Night_Watch")!, focalPoint: .init(x: 0.5, y: 0.48), zoom: 1.1),
        .init(id: "pearl-earring", title: "Girl with a Pearl Earring", credit: "Johannes Vermeer",
              medium: "Oil painting", date: "c. 1665", filename: "pearl-earring.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:1665_Girl_with_a_Pearl_Earring.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Girl_with_a_Pearl_Earring")!, focalPoint: .init(x: 0.5, y: 0.4), zoom: 1.1),
        .init(id: "socrates", title: "The Death of Socrates", credit: "Jacques-Louis David",
              medium: "Oil painting", date: "1787", filename: "socrates.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:David_-_The_Death_of_Socrates.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Death_of_Socrates")!, focalPoint: .init(x: 0.59, y: 0.48), zoom: 1.1),
        .init(id: "third-may", title: "The Third of May 1808", credit: "Francisco Goya",
              medium: "Oil painting", date: "1814", filename: "third-may.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:El_Tres_de_Mayo,_by_Francisco_de_Goya,_from_Prado_thin_black_margin.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Third_of_May_1808")!, focalPoint: .init(x: 0.39, y: 0.48), zoom: 1.1),
        .init(id: "temeraire", title: "The Fighting Temeraire", credit: "J. M. W. Turner",
              medium: "Oil painting", date: "1839", filename: "temeraire.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Fighting_Temeraire,_JMW_Turner,_National_Gallery.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Fighting_Temeraire")!, focalPoint: .init(x: 0.37, y: 0.51), zoom: 1.1),
        .init(id: "liberty", title: "Liberty Leading the People", credit: "Eugène Delacroix",
              medium: "Oil painting", date: "1830", filename: "liberty.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:La_Libert%C3%A9_guidant_le_peuple_-_Eug%C3%A8ne_Delacroix_-_Mus%C3%A9e_du_Louvre_Peintures_RF_129_-_apr%C3%A8s_restauration_2024.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Liberty_Leading_the_People")!, focalPoint: .init(x: 0.54, y: 0.46), zoom: 1.15),
        .init(id: "wave", title: "The Great Wave off Kanagawa", credit: "Katsushika Hokusai",
              medium: "Woodblock print", date: "c. 1830–32", filename: "wave.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Tsunami_by_hokusai_19th_century.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Great_Wave_off_Kanagawa")!, focalPoint: .init(x: 0.35, y: 0.47), zoom: 1.15),
        .init(id: "olympia", title: "Olympia", credit: "Édouard Manet",
              medium: "Oil painting", date: "1863", filename: "olympia.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Edouard_Manet_-_Olympia_-_Google_Art_ProjectFXD.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Olympia_(Manet)")!, focalPoint: .init(x: 0.27, y: 0.45), zoom: 1.1),
        .init(id: "impression", title: "Impression, Sunrise", credit: "Claude Monet",
              medium: "Oil painting", date: "1872", filename: "impression.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Monet_-_Impression,_Sunrise.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Impression,_Sunrise")!, focalPoint: .init(x: 0.58, y: 0.47), zoom: 1.1),
        .init(id: "grande-jatte", title: "A Sunday on La Grande Jatte", credit: "Georges Seurat",
              medium: "Oil painting", date: "1884–86", filename: "grande-jatte.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:A_Sunday_on_La_Grande_Jatte,_Georges_Seurat,_1884.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/A_Sunday_Afternoon_on_the_Island_of_La_Grande_Jatte")!, focalPoint: .init(x: 0.68, y: 0.46), zoom: 1.1),
        .init(id: "starry-night", title: "The Starry Night", credit: "Vincent van Gogh",
              medium: "Oil painting", date: "1889", filename: "starry-night.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Starry_Night")!, focalPoint: .init(x: 0.48, y: 0.42), zoom: 1.1),
        .init(id: "scream", title: "The Scream", credit: "Edvard Munch",
              medium: "Oil, tempera and pastel", date: "1893", filename: "scream.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Edvard_Munch,_1893,_The_Scream,_oil,_tempera_and_pastel_on_cardboard,_91_x_73_cm,_National_Gallery_of_Norway.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Scream")!, focalPoint: .init(x: 0.46, y: 0.47), zoom: 1.1),
        .init(id: "kiss", title: "The Kiss", credit: "Gustav Klimt",
              medium: "Oil and gold leaf", date: "1907–08", filename: "kiss.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Kiss_-_Gustav_Klimt_-_Google_Cultural_Institute.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Kiss_(Klimt)")!, focalPoint: .init(x: 0.55, y: 0.38), zoom: 1.15),
        .init(id: "apples", title: "The Basket of Apples", credit: "Paul Cézanne",
              medium: "Oil painting", date: "c. 1893", filename: "apples.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Paul_C%C3%A9zanne_-_The_Basket_of_Apples_-_1926.252_-_Art_Institute_of_Chicago.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/The_Basket_of_Apples")!, focalPoint: .init(x: 0.51, y: 0.54), zoom: 1.15),
        .init(id: "rhinoceros", title: "Rhinoceros", credit: "Albrecht Dürer",
              medium: "Woodcut", date: "1515", filename: "rhinoceros.png", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Rhinoceros_(NGA_1964.8.697)_enhanced.png")!,
              article: URL(string: "https://en.wikipedia.org/wiki/D%C3%BCrer%27s_Rhinoceros")!, focalPoint: .init(x: 0.64, y: 0.53), zoom: 1.2),
        .init(id: "kandinsky", title: "Composition VIII", credit: "Wassily Kandinsky",
              medium: "Oil painting", date: "1923", filename: "kandinsky.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Kandinsky_-_Composition_8,_1923.jpg")!,
              article: URL(string: "https://www.guggenheim-bilbao.eus/en/learn/schools/teachers-guides/composition-8")!, focalPoint: .init(x: 0.4, y: 0.47), zoom: 1.15),
        .init(id: "black-square", title: "Black Square", credit: "Kazimir Malevich",
              medium: "Oil painting", date: "1915", filename: "black-square.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Kazimir_Malevich,_1915,_Black_Suprematic_Square,_oil_on_linen_canvas,_79.5_x_79.5_cm,_Tretyakov_Gallery,_Moscow.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Black_Square")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.0),
        .init(id: "mondrian", title: "Composition with Red, Blue and Yellow", credit: "Piet Mondrian",
              medium: "Oil painting", date: "1930", filename: "mondrian.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Piet_Mondriaan,_1930_-_Mondrian_Composition_II_in_Red,_Blue,_and_Yellow.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Composition_with_Red,_Blue_and_Yellow")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.0),
        .init(id: "twittering", title: "Twittering Machine", credit: "Paul Klee",
              medium: "Watercolor and oil transfer", date: "1922", filename: "twittering.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Die_Zwitscher-Maschine_(Twittering_Machine),_1922_-_Paul_Klee.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Twittering_Machine")!, focalPoint: .init(x: 0.53, y: 0.45), zoom: 1.05),
        .init(id: "fountain", title: "Fountain", credit: "Marcel Duchamp",
              medium: "Readymade; Stieglitz photograph", date: "1917", filename: "fountain.jpg", license: "Public domain", imageCredit: "Photograph by Alfred Stieglitz",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Marcel_Duchamp,_1917,_Fountain,_photograph_by_Alfred_Stieglitz.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Fountain_(Duchamp)")!, focalPoint: .init(x: 0.5, y: 0.46), zoom: 1.05),
        .init(id: "dance", title: "Dance", credit: "Henri Matisse",
              medium: "Oil painting", date: "1910", filename: "dance.jpg", license: "Public domain", imageCredit: "",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Matissedance.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Dance_(Matisse)")!, focalPoint: .init(x: 0.49, y: 0.47), zoom: 1.1),
        .init(id: "single-form", title: "Single Form (Battersea Park)", credit: "Barbara Hepworth",
              medium: "Bronze sculpture", date: "1961", filename: "single-form.jpg", license: "CC BY-SA 3.0", imageCredit: "Photograph by QuentinUK",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Barbara_Hepworth_Single_Form_Battersea.JPG")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Single_Form")!, focalPoint: .init(x: 0.5, y: 0.42), zoom: 1.1),
        .init(id: "guggenheim", title: "Guggenheim Museum Bilbao", credit: "Frank Gehry",
              medium: "Architecture", date: "1997", filename: "guggenheim.jpg", license: "CC BY 2.0", imageCredit: "Photograph by Naotake Murayama",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Museo_Guggenheim,_Bilbao_(31273245344).jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Guggenheim_Museum_Bilbao")!, focalPoint: .init(x: 0.48, y: 0.45), zoom: 1.1),
        .init(id: "angel", title: "Angel of the North", credit: "Antony Gormley",
              medium: "Steel sculpture", date: "1998", filename: "angel.jpg", license: "CC BY-SA 2.0", imageCredit: "Photograph by saw2th",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Angel_of_the_North_2010.jpg")!,
              article: URL(string: "https://en.wikipedia.org/wiki/Angel_of_the_North")!, focalPoint: .init(x: 0.32, y: 0.43), zoom: 1.05)
    ]
    static var assetNames: [String] { artworks.map(\.id) }

    static func index(at date: Date, offset: Int, context: String) -> Int {
        let text = context.lowercased()
        let topics = [["math", "interactive", "edumation", "builder"], ["boat", "cannes", "travel", "greece"], ["writing", "book", "stikky", "article"]]
        let scores = topics.map { words in words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) } }
        let topic = scores.indices.max { scores[$0] < scores[$1] } ?? 0
        let hour = Int(date.timeIntervalSince1970 / 3600)
        return normalized(hour % artworks.count + offset % artworks.count + topic)
    }
    static func offset(selecting selected: Int, at date: Date, context: String) -> Int {
        normalized(selected - index(at: date, offset: 0, context: context))
    }
    private static func normalized(_ value: Int) -> Int { (value % artworks.count + artworks.count) % artworks.count }

    // Keep the focal point near the center, clamping at the image edges so no gaps appear.
    static func cropFrame(image: CGSize, viewport: CGSize, focalPoint: CGPoint, zoom: CGFloat = 1) -> CGRect {
        guard image.width > 0, image.height > 0, viewport.width > 0, viewport.height > 0 else { return .zero }
        let scale = max(viewport.width / image.width, viewport.height / image.height) * max(1, zoom)
        let width = image.width * scale, height = image.height * scale
        let x = min(0, max(viewport.width - width, viewport.width / 2 - focalPoint.x * width))
        let y = min(0, max(viewport.height - height, viewport.height / 2 - focalPoint.y * height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// The resource location is a value dependency, so previews never mutate live globals.
private struct ArtResourceRootKey: EnvironmentKey {
    static let defaultValue: URL? = Bundle.main.resourceURL
}
extension EnvironmentValues {
    var artResourceRoot: URL? {
        get { self[ArtResourceRootKey.self] }
        set { self[ArtResourceRootKey.self] = newValue }
    }
}

@MainActor final class ArtImageLoader {
    static let shared = ArtImageLoader()
    // Decode just the current artwork, never the whole library at full resolution.
    private let fullImages = ArtImageLoader.cache(count: 3, bytes: 48 * 1024 * 1024)
    private let thumbnails = ArtImageLoader.cache(count: 24, bytes: 24 * 1024 * 1024)
    private static func cache(count: Int, bytes: Int) -> NSCache<NSString, NSImage> {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = count; cache.totalCostLimit = bytes
        return cache
    }
    func image(for artwork: BackdropArtwork, thumbnail: Bool = false, resourceRoot: URL? = Bundle.main.resourceURL) -> NSImage? {
        guard let url = resourceRoot?.appendingPathComponent("Art/\(artwork.filename)") else { return nil }
        let cache = thumbnail ? thumbnails : fullImages
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: thumbnail ? Int(ceil(400 * artwork.zoom)) : 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        // Preserve the artwork's original color; only downsample the decoded display copy.
        let result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        cache.setObject(result, forKey: key, cost: image.bytesPerRow * image.height)
        return result
    }

}

struct ArtDetail: View {
    @Environment(\.artResourceRoot) private var resourceRoot
    let artwork: BackdropArtwork
    var thumbnail = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let image = ArtImageLoader.shared.image(for: artwork, thumbnail: thumbnail, resourceRoot: resourceRoot) {
                    let frame = ArtBackdrop.cropFrame(image: image.size, viewport: proxy.size, focalPoint: artwork.focalPoint, zoom: artwork.zoom)
                    Image(nsImage: image).resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }.clipped()
        }
    }
}

struct BoardBackdrop: View {
    let appearance: BoardAppearance
    let artwork: BackdropArtwork?
    var body: some View {
        if let artwork {
            ZStack {
                ArtDetail(artwork: artwork)
                LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.08), .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
            }.accessibilityHidden(true).allowsHitTesting(false)
        } else { appearance.canvas }
    }
}

/// The caller passes the same artwork to the backdrop and this caption, including at hour rollover.
struct ArtworkCaption: View {
    let artwork: BackdropArtwork
    let compact: Bool
    var body: some View {
        Link(destination: artwork.article) {
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artwork.title + " ↗").font(.system(size: 10, weight: .medium)).lineLimit(1)
                        Text("\(artwork.credit) · \(artwork.date)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                    }
                } else {
                    Text(artwork.caption + " ↗").font(.system(size: 10)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, compact ? 12 : 18).padding(.vertical, 6)
            .foregroundStyle(.white.opacity(0.9))
            .background(.black.opacity(0.78))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("About the background: " + artwork.caption)
            .help(artwork.caption + " — open artwork page")
    }
}

struct ArtLibraryView: View {
    @Binding var artOffset: Int
    let context: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int

    init(artOffset: Binding<Int>, context: String) {
        _artOffset = artOffset
        self.context = context
        _selected = State(initialValue: ArtBackdrop.index(at: .now, offset: artOffset.wrappedValue, context: context))
    }
    private var artwork: BackdropArtwork { ArtBackdrop.artworks[selected] }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Art, up close").font(.system(size: 21, weight: .semibold, design: .serif))
                    Text("\(ArtBackdrop.artworks.count) art details · a new one each hour").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel("Close art library").keyboardShortcut(.cancelAction)
            }
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(Array(ArtBackdrop.artworks.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selected = index
                                artOffset = ArtBackdrop.offset(selecting: index, at: .now, context: context)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ArtDetail(artwork: item, thumbnail: true)
                                        .frame(height: 184)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            if selected == index {
                                                Image(systemName: "checkmark.circle.fill").font(.system(size: 17))
                                                    .foregroundStyle(.black, .white).padding(7)
                                            }
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(selected == index ? 0.9 : 0.12), lineWidth: selected == index ? 2 : 1))
                                    Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(item.title + (selected == index ? ", selected" : ""))
                                .help("Use \(item.title)").id(index)
                        }
                    }.padding(2)
                }.onAppear { scroll.scrollTo(selected, anchor: .center) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.title).font(.system(size: 12, weight: .semibold))
                Text(artwork.credit).font(.system(size: 11))
                Text(artwork.license).font(.system(size: 10)).foregroundStyle(.secondary)
                if !artwork.imageCredit.isEmpty { Text(artwork.imageCredit).font(.system(size: 10)).foregroundStyle(.secondary) }
                Text("\(artwork.date) · \(artwork.medium)").font(.system(size: 10)).foregroundStyle(.secondary)
                HStack {
                    Link("About this work ↗", destination: artwork.article)
                    Spacer()
                    Link("Image & license ↗", destination: artwork.source)
                }.font(.system(size: 11)).tint(.white)
            }.frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        }.padding(18).frame(width: 340, height: 570)
            .foregroundStyle(.white).background(Color(hex: 0x17191C))
            .environment(\.colorScheme, .dark)
    }
}
