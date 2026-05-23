// FaroWidget.swift — Widget de tela inicial do Faro (iOS WidgetKit).
//
// Lê dados gravados pelo app Flutter via App Group
// "group.com.faro.faro" (UserDefaults). Mostra contagem de relatos
// nas últimas 6h no bairro principal do usuário.
//
// Setup manual (uma vez, no Xcode):
//   1. Runner → File → New → Target → Widget Extension
//      Nome: FaroWidget   |   Bundle ID: br.com.projetoseg.projetoSeg.FaroWidget
//      Include Configuration Intent: NO
//   2. Apagar os arquivos gerados; substituir por estes 3
//      (FaroWidget.swift, FaroWidgetEntryView.swift, Info.plist) — já
//      estão prontos no diretório ios/FaroWidget/.
//   3. Em "Signing & Capabilities" do target FaroWidget:
//      Add Capability → App Groups → group.com.faro.faro
//      (Marcar a mesma capability no target Runner também — é o que
//       permite Flutter e widget compartilharem UserDefaults.)
//   4. Build & Run o esquema "Runner" — o widget aparece na lista do
//      "Edit Home Screen → +" depois da primeira execução.
//
// Princípio editorial mantido: nunca alarmista. Sem PERIGO, CUIDADO etc.

import WidgetKit
import SwiftUI

struct FaroEntry: TimelineEntry {
    let date: Date
    let count: Int    // -1 = não configurado
    let label: String
    let updatedAt: Date?
}

struct FaroProvider: TimelineProvider {
    typealias Entry = FaroEntry

    let appGroupId = "group.com.faro.faro"

    func placeholder(in context: Context) -> FaroEntry {
        FaroEntry(date: Date(), count: 0, label: "Seu bairro", updatedAt: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (FaroEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FaroEntry>) -> Void) {
        let entry = readEntry()
        // Sistema chama de novo daqui a 30 min — o app também pode
        // forçar reload via HomeWidget.updateWidget quando ocorrências
        // novas chegam.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> FaroEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let count = defaults?.integer(forKey: "count") ?? -1
        let label = defaults?.string(forKey: "label") ?? ""
        let updatedAtStr = defaults?.string(forKey: "updatedAt")
        let updatedAt = updatedAtStr.flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
        return FaroEntry(
            date: Date(),
            count: count,
            label: label,
            updatedAt: updatedAt
        )
    }
}

@main
struct FaroWidget: Widget {
    let kind: String = "FaroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FaroProvider()) { entry in
            FaroWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Faro")
        .description("Resumo do seu bairro nas últimas 6h.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
