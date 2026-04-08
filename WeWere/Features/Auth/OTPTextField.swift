import SwiftUI
import UIKit

/// UITextField wrapper that properly supports iOS OTP autofill
struct OTPTextField: UIViewRepresentable {
    @Binding var code: String
    var onComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.textAlignment = .center
        textField.font = UIFont(name: WeWereFontFamily.spaceGroteskMedium, size: 32)
        textField.textColor = UIColor(Color(hex: "e2e2e2"))
        textField.tintColor = .white
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        // Placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: "000000",
            attributes: [
                .foregroundColor: UIColor(Color(hex: "474747")),
                .font: UIFont(name: WeWereFontFamily.spaceGroteskMedium, size: 32) ?? .systemFont(ofSize: 32)
            ]
        )

        // Auto-focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != code {
            uiView.text = code
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OTPTextField

        init(_ parent: OTPTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            let text = textField.text ?? ""
            let filtered = String(text.filter { $0.isNumber }.prefix(6))
            if filtered != text {
                textField.text = filtered
            }
            parent.code = filtered

            if filtered.count == 6 {
                textField.resignFirstResponder()
                parent.onComplete()
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let range = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: range, with: string)
            let filtered = updated.filter { $0.isNumber }
            return filtered.count <= 6
        }
    }
}
