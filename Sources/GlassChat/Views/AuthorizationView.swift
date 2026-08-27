import SwiftUI

struct AuthorizationView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var account = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isVerifying = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
            Text("设备验证")
                .font(.title2.weight(.semibold))
            VStack(spacing: 10) {
                TextField("账号", text: $account)
                    .textFieldStyle(.roundedBorder)
                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { verify() }
            }
            Button { verify() } label: {
                if isVerifying { ProgressView().controlSize(.small) } else { Text("验证并进入") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isVerifying || account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(32)
        .frame(width: 360, height: 310)
        .background(Theme.Palette.chatBackground)
    }

    private func verify() {
        isVerifying = true
        errorMessage = ""
        Task {
            let result = await AccessAuthorization.verify(account: account, password: password)
            await MainActor.run {
                isVerifying = false
                switch result {
                case .success:
                    password = ""
                    app.isAuthorized = true
                    openWindow(id: "main")
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
