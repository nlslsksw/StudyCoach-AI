import SwiftUI

struct PINEntryView: View {
    let title: String
    let subtitle: String
    var onComplete: (String) -> Void

    @State private var pin = ""
    @State private var shake = false
    @State private var failCount = 0
    @State private var isLocked = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.blue : Color(.tertiarySystemFill))
                        .frame(width: 20, height: 20)
                }
            }
            .offset(x: shake ? -10 : 0)

            if isLocked {
                Text("Zu viele Versuche. Bitte warte 30 Sekunden.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Number pad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(1...9, id: \.self) { digit in
                    pinButton(String(digit))
                }
                Color.clear.frame(height: 60)
                pinButton("0")
                Button {
                    if !pin.isEmpty { pin.removeLast() }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                }
                .disabled(isLocked)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func pinButton(_ digit: String) -> some View {
        Button {
            guard !isLocked, pin.count < 4 else { return }
            pin += digit
            if pin.count == 4 {
                onComplete(pin)
            }
        } label: {
            Text(digit)
                .font(.title)
                .frame(width: 60, height: 60)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .disabled(isLocked)
    }

    func showError() {
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
            pin = ""
            failCount += 1
            if failCount >= 3 {
                isLocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    isLocked = false
                    failCount = 0
                }
            }
        }
    }

    func reset() {
        pin = ""
    }
}

struct PINSetupView: View {
    var onPINSet: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var step: PINStep = .enter
    @State private var firstPIN = ""

    enum PINStep {
        case enter, confirm
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enter:
                    PINEntryView(
                        title: "PIN festlegen",
                        subtitle: "Wähle einen 4-stelligen PIN für die Elternkontrolle."
                    ) { pin in
                        firstPIN = pin
                        step = .confirm
                    }
                case .confirm:
                    PINEntryView(
                        title: "PIN bestätigen",
                        subtitle: "Gib den PIN erneut ein."
                    ) { pin in
                        if pin == firstPIN {
                            onPINSet(pin)
                            dismiss()
                        } else {
                            firstPIN = ""
                            step = .enter
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

struct PINGateView<Content: View>: View {
    var store: DataStore
    @ViewBuilder var content: () -> Content

    @State private var isUnlocked = false

    var body: some View {
        if store.parentalPIN == nil || isUnlocked {
            content()
        } else {
            PINEntryView(
                title: "PIN eingeben",
                subtitle: "Gib den Eltern-PIN ein, um fortzufahren."
            ) { pin in
                if pin == store.parentalPIN {
                    isUnlocked = true
                }
            }
        }
    }
}
