import Testing
@testable import SudokuKit

/// The guide's example boards must actually show what they claim: each
/// example that names a technique is run through that technique's finder,
/// and the finder must recognise it and eliminate (or place) exactly what
/// the caption says.
struct TechniqueGuideTests {
    @Test func everyTopicHasAnExampleOrIsAProcessPage() {
        for topic in TechniqueGuide.allTopics {
            let isProcess = topic.techniques.isEmpty && topic.name == "Working a Hard Puzzle"
            #expect(isProcess || !topic.examples.isEmpty, "\(topic.name) has no example board")
        }
    }

    @Test func everyEngineTechniqueHasAPage() {
        for technique in Technique.allCases {
            #expect(TechniqueGuide.topic(for: technique) != nil, "\(technique.displayName) has no guide page")
        }
    }

    @Test func exampleBoardsAreRecognisedByTheirFinders() {
        for topic in TechniqueGuide.allTopics {
            for example in topic.examples {
                guard let technique = example.technique else { continue }
                guard let d = example.deduction else {
                    Issue.record("\(topic.name): the \(technique.displayName) finder found nothing on the example board")
                    continue
                }
                #expect(topic.techniques.contains(d.technique),
                        "\(topic.name): finder reported \(d.technique.displayName), not one of the page's techniques")
                switch d.kind {
                case .place(let cell, _):
                    // (`eliminated` may still tint cells the digit can't go
                    // in — the covered cells of a hidden single.)
                    #expect(example.marks[cell] != nil, "\(topic.name): placed cell \(cell) isn't marked on the board")
                case .eliminate(let elims):
                    let cells = Set(elims.map(\.cell))
                    if !example.eliminated.isEmpty {
                        #expect(cells == example.eliminated,
                                "\(topic.name): finder eliminated in \(cells.sorted()), example expected \(example.eliminated.sorted())")
                    }
                    #expect(!cells.isEmpty)
                }
            }
        }
    }
}
