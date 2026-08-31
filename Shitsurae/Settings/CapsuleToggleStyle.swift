import SwiftUI

struct CapsuleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .frame(width: 36, height: 21)
                .overlay(
                    Capsule().strokeBorder(
                        configuration.isOn ? AnyShapeStyle(.clear) : AnyShapeStyle(.separator),
                        lineWidth: 0.5
                    )
                )
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 17, height: 17)
                        .shadow(color: .black.opacity(0.28), radius: 1, y: 1)
                        .padding(.horizontal, 2)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .contentShape(.capsule)
        .pointerStyle(.link)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

extension ToggleStyle where Self == CapsuleToggleStyle {
    static var capsuleSwitch: CapsuleToggleStyle {
        CapsuleToggleStyle()
    }
}
