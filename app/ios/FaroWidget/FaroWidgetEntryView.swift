// View do widget. SwiftUI puro — espelha o visual do app Flutter
// (mesma paleta sand + fontes próximas, sem alarmismo).

import SwiftUI
import WidgetKit

struct FaroWidgetEntryView: View {
    var entry: FaroEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.count < 0 {
                Text("—")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                Text("Defina seu bairro principal no app")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                    .lineLimit(2)
            } else {
                Text("\(entry.count)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                Text(entry.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .lineLimit(1)
                Text(subtitle(for: entry.count))
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subtitle(for count: Int) -> String {
        switch count {
        case 0: return "sem relatos nas últimas 6h"
        case 1: return "1 relato nas últimas 6h"
        default: return "\(count) relatos nas últimas 6h"
        }
    }
}
